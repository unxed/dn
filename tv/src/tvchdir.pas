{ TvChDir: the dialog that changes the current directory: TDirListBox, TChDirDialog.

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/stddlg.h (class declarations, flags)
    source/tvision/tdirlist.cpp, tchdrdlg.cpp, tvtext1.cpp, tvtext2.cpp (texts)
  Borland disclaimer and MIT notice: tv/COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/DESIGN.md):
    - paths are ShortStrings; the tree is built with both separators and works with
      or without drive letters (the root is 'C:\' or '/');
    - the directory is changed with ChDir (the drive too, where the RTL does it);
    - streams are not translated yet. }
unit TvChDir;

{$I tvdefs.inc}

interface

uses
  TvGeom, TvColors, TvCell, TvKeys, TvEvents, TvDrawBuf, TvObjs, TvUtil, TvViews, TvDialog,
  TvWindow, TvList, TvInput, TvHist, TvMsgBox, TvFiles, TvFileDlg;

const
  cdNormal     = $0000;
  cdNoLoadDir  = $0001;
  cdHelpButton = $0002;

  { the characters of the tree (code page 437/866 box drawing characters) }
  PathDirText   = #$C0#$C4#$C2;
  FirstDirText  = #$C0#$C2#$C4;
  MiddleDirText = ' '#$C3#$C4;
  LastDirText   = ' '#$C0#$C4;
  DrivesText    = 'Drives';
  Graphics      = #$C0#$C3#$C4;

  ChangeDirTitle = 'Change Directory';
  DirNameText = 'Directory ~n~ame';
  DirTreeText = 'Directory ~t~ree';
  ChDirOKText = 'O~K~';
  ChdirText = '~C~hdir';
  RevertText = '~R~evert';
  ChDirHelpText = 'Help';
  InvalidDirText = 'Invalid directory';

type
  PChDirDialog = ^TChDirDialog;

  { the items are TDirEntry (the text of the line and the path) }
  PDirListBox = ^TDirListBox;
  TDirListBox = object(TListBox)
    Dir: ShortString;
    Cur: Integer;
    constructor Init(const Bounds: TRect; AScrollBar: PScrollBar);
    function GetText(Item, MaxLen: Integer): ShortString; virtual;
    function IsSelected(Item: Integer): Boolean; virtual;
    procedure NewDirectory(const S: ShortString);
    procedure SelectItem(Item: Integer); virtual;
    procedure SetState(AState: Word; Enable: Boolean); virtual;
    function DirItem(Index: Integer): PDirEntry;
  private
    procedure ShowDrives(Dirs: PDirCollection);
    procedure ShowDirs(Dirs: PDirCollection);
  end;

  TChDirDialog = object(TDialog)
    DirList: PDirListBox;
    DirInput: PInputLine;
    OKButton: PButton;
    ChDirButton: PButton;
    constructor Init(Opts: Word; HistId: Word);
    destructor Done; virtual;
    function DataSize: Integer; virtual;
    procedure GetData(var Rec); virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure SetData(var Rec); virtual;
    procedure SizeLimits(out Min, Max: TPoint); virtual;
    procedure SetUpDialog;
    function Valid(Command: Word): Boolean; virtual;
  end;

implementation

function IsSep(C: Char): Boolean;
begin
  Result := (C = '\') or (C = '/');
end;

{ the first separator at or after From, 0 if none }
function SepPos(const S: ShortString; From: Integer): Integer;
var
  I: Integer;
begin
  for I := From to Length(S) do
    if IsSep(S[I]) then
      Exit(I);
  Result := 0;
end;

{ --- TDirListBox ------------------------------------------------------------- }

constructor TDirListBox.Init(const Bounds: TRect; AScrollBar: PScrollBar);
begin
  inherited Init(Bounds, 1, AScrollBar);
  Cur := 0;
  Dir := '';
end;

function TDirListBox.DirItem(Index: Integer): PDirEntry;
begin
  Result := PDirEntry(List^.At(Index));
end;

function TDirListBox.GetText(Item, MaxLen: Integer): ShortString;
begin
  Result := DirItem(Item)^.Text^;
  if Length(Result) > MaxLen then
    SetLength(Result, MaxLen);
end;

procedure TDirListBox.SelectItem(Item: Integer);
begin
  Message(Owner, evCommand, cmChangeDir, DirItem(Item));
end;

function TDirListBox.IsSelected(Item: Integer): Boolean;
begin
  Result := Item = Cur;
end;

procedure TDirListBox.ShowDrives(Dirs: PDirCollection);
var
  IsFirst: Boolean;
  Old, C: Char;
  S: ShortString;
begin
  IsFirst := True;
  Old := '0';
  for C := 'A' to 'Z' do
    if (C < 'C') or DriveValid(C) then
    begin
      if Old <> '0' then
      begin
        if IsFirst then
        begin
          S := FirstDirText + Old;
          IsFirst := False;
        end
        else
          S := MiddleDirText + Old;
        Dirs^.Insert(NewDirEntry(S, Old + ':\'));
      end;
      if C = GetDisk then
        Cur := Dirs^.Count;
      Old := C;
    end;
  if Old <> '0' then
  begin
    S := LastDirText + Old;
    Dirs^.Insert(NewDirEntry(S, Old + ':\'));
  end;
end;

procedure TDirListBox.ShowDirs(Dirs: PDirCollection);
const
  IndentSize = 2;
var
  Indent, P, Q, I: Integer;
  Name, Path, Marker: ShortString;
  Finder: TFileFinder;
  IsFirst: Boolean;
  Last: PDirEntry;
  T: ShortString;
  Names: PStringCollection;
begin
  Indent := IndentSize;
  { the root directory }
  P := SepPos(Dir, 1);
  if P = 0 then
    Exit;
  Name := Copy(Dir, 1, P);
  Dirs^.Insert(NewDirEntry(PathDirText + Name, Name));
  Inc(P);
  { the directories up to the current one }
  Q := SepPos(Dir, P);
  while Q <> 0 do
  begin
    Name := Copy(Dir, P, Q - P);
    Dirs^.Insert(NewDirEntry(StringOfChar(' ', Indent) + PathDirText + Name,
      Copy(Dir, 1, Q - 1)));
    P := Q + 1;
    Q := SepPos(Dir, P);
    Inc(Indent, IndentSize);
  end;
  Cur := Dirs^.Count - 1;

  { the subdirectories }
  Q := Length(Dir);
  while (Q > 0) and not IsSep(Dir[Q]) do
    Dec(Q);
  Path := Copy(Dir, 1, Q);
  IsFirst := True;
  { the names are sorted: the order of the file system (a hash on ext4) differs from machine to machine }
  New(Names, Init(8, 8));
  Finder.Init;
  if Finder.First(Path + AllMask, faDirectory) then
    repeat
      if ((Finder.Rec.Attr and faDirectory) <> 0) and (Finder.Rec.Name[1] <> '.') then
        Names^.Insert(NewStr(Finder.Rec.Name));
    until not Finder.Next;
  Finder.Done;
  for I := 0 to Names^.Count - 1 do
  begin
    if IsFirst then
    begin
      Marker := FirstDirText;
      IsFirst := False;
    end
    else
      Marker := MiddleDirText;
    Name := PStr(Names^.At(I))^;
    Dirs^.Insert(NewDirEntry(StringOfChar(' ', Indent) + Marker + Name, Path + Name));
  end;
  Dispose(Names, Done);

  { the line of the last entry ends the tree }
  Last := Dirs^.At2(Dirs^.Count - 1);
  T := Last^.Text^;
  I := Pos(Graphics[1], T);
  if I = 0 then
  begin
    I := Pos(Graphics[2], T);
    if I <> 0 then
      T[I] := Graphics[1];
  end
  else
  begin
    if I + 1 <= Length(T) then
      T[I + 1] := Graphics[3];
    if I + 2 <= Length(T) then
      T[I + 2] := Graphics[3];
  end;
  DisposeStr(Last^.Text);
  Last^.Text := NewStr(T);
end;

procedure TDirListBox.NewDirectory(const S: ShortString);
var
  Dirs: PDirCollection;
begin
  Dir := S;
  New(Dirs, Init(5, 5));
  Dirs^.Insert(NewDirEntry(DrivesText, DrivesText));
  if S = DrivesText then
    ShowDrives(Dirs)
  else
    ShowDirs(Dirs);
  NewList(Dirs);
  FocusItem(Cur);
end;

procedure TDirListBox.SetState(AState: Word; Enable: Boolean);
begin
  inherited SetState(AState, Enable);
  if ((AState and sfFocused) <> 0) and (Owner <> nil) then
    PChDirDialog(Owner)^.ChDirButton^.MakeDefault(Enable);
end;

{ --- TChDirDialog ------------------------------------------------------------ }

constructor TChDirDialog.Init(Opts: Word; HistId: Word);
var
  R: TRect;
  Lbl: PLabel;
  Hist: PHistory;
  SB: PScrollBar;
  Btn: PButton;
begin
  R.Assign(16, 2, 64, 20);
  inherited Init(R, ChangeDirTitle);
  Options := Options or ofCentered;
  Flags := Flags or wfGrow;

  R.Assign(3, 3, 42, 4);
  New(DirInput, Init(R, 255));
  DirInput^.GrowMode := gfGrowHiX;
  Insert(DirInput);
  R.Assign(2, 2, 17, 3);
  New(Lbl, Init(R, DirNameText, DirInput));
  Insert(Lbl);
  R.Assign(42, 3, 45, 4);
  New(Hist, Init(R, DirInput, HistId));
  Hist^.GrowMode := gfGrowLoX or gfGrowHiX;
  Insert(Hist);

  R.Assign(32, 6, 33, 16);
  New(SB, Init(R));
  Insert(SB);
  R.Assign(3, 6, 32, 16);
  New(DirList, Init(R, SB));
  DirList^.GrowMode := gfGrowHiX or gfGrowHiY;
  Insert(DirList);
  R.Assign(2, 5, 17, 6);
  New(Lbl, Init(R, DirTreeText, DirList));
  Insert(Lbl);

  R.Assign(35, 6, 45, 8);
  New(OKButton, Init(R, ChDirOKText, cmOK, bfDefault));
  OKButton^.GrowMode := gfGrowLoX or gfGrowHiX;
  Insert(OKButton);
  R.Assign(35, 9, 45, 11);
  New(ChDirButton, Init(R, ChdirText, cmChangeDir, bfNormal));
  ChDirButton^.GrowMode := gfGrowLoX or gfGrowHiX;
  Insert(ChDirButton);
  R.Assign(35, 12, 45, 14);
  New(Btn, Init(R, RevertText, cmRevert, bfNormal));
  Btn^.GrowMode := gfGrowLoX or gfGrowHiX;
  Insert(Btn);
  if (Opts and cdHelpButton) <> 0 then
  begin
    R.Assign(35, 15, 45, 17);
    New(Btn, Init(R, ChDirHelpText, cmHelp, bfNormal));
    Btn^.GrowMode := gfGrowLoX or gfGrowHiX;
    Insert(Btn);
  end;

  if (Opts and cdNoLoadDir) = 0 then
    SetUpDialog;
  SelectNext(False);
end;

destructor TChDirDialog.Done;
begin
  DirList := nil;
  DirInput := nil;
  OKButton := nil;
  ChDirButton := nil;
  inherited Done;
end;

function TChDirDialog.DataSize: Integer;
begin
  Result := 0;
end;

procedure TChDirDialog.GetData(var Rec);
begin
end;

procedure TChDirDialog.SetData(var Rec);
begin
end;

procedure TChDirDialog.SizeLimits(out Min, Max: TPoint);
begin
  inherited SizeLimits(Min, Max);
  Min.X := 48;
  Min.Y := 18;
end;

{ the end separator is not shown (except in the root) }
function TrimEndSeparator(const Path: ShortString): ShortString;
begin
  Result := Path;
  if (Length(Result) > 3) and IsSep(Result[Length(Result)]) then
    SetLength(Result, Length(Result) - 1)
  else if (Length(Result) = 3) and (Result[2] <> ':') and IsSep(Result[3]) then
    SetLength(Result, 2);
end;

{ the current directory without the drive, with the separator at the end }
function CurrentDir: ShortString;
begin
  Result := GetCurDir;
  if (Length(Result) > 1) and (Result[2] = ':') then
    Delete(Result, 1, 2);
end;

procedure SetInput(Input: PInputLine; const S: ShortString);
var
  T: ShortString;
begin
  T := S;
  if Length(T) > Input^.MaxLen then
    SetLength(T, Input^.MaxLen);
  Input^.Data^ := T;
  Input^.DrawView;
end;

procedure TChDirDialog.HandleEvent(var Event: TEvent);
var
  CurDir: ShortString;
  P: PDirEntry;
begin
  inherited HandleEvent(Event);
  if Event.What = evCommand then
  begin
    case Event.Command of
      cmRevert:
        CurDir := CurrentDir;
      cmChangeDir:
        begin
          P := DirList^.DirItem(DirList^.Focused);
          CurDir := P^.Dir^;
          if CurDir <> DrivesText then
          begin
            if IsSep(CurDir[1]) or DriveValid(CurDir[1]) then
            begin
              if not IsSep(CurDir[Length(CurDir)]) then
                CurDir := CurDir + DirDelim;
            end
            else
              Exit;
          end;
        end;
    else
      Exit;
    end;
    DirList^.NewDirectory(CurDir);
    SetInput(DirInput, TrimEndSeparator(CurDir));
    DirList^.Select;
    ClearEvent(Event);
  end;
end;

procedure TChDirDialog.SetUpDialog;
var
  CurDir: ShortString;
begin
  if DirList <> nil then
  begin
    CurDir := CurrentDir;
    DirList^.NewDirectory(CurDir);
    if DirInput <> nil then
      SetInput(DirInput, TrimEndSeparator(CurDir));
  end;
end;

function ChangeDir(const Path: ShortString): Boolean;
begin
{$I-}
  ChDir(Path);
{$I+}
  Result := IOResult = 0;
end;

function TChDirDialog.Valid(Command: Word): Boolean;
var
  Path: ShortString;
begin
  if Command <> cmOK then
    Exit(True);
  Path := TrimEndSeparator(FExpand(DirInput^.Data^));
  if not ChangeDir(Path) then
  begin
    MessageBoxFmt(mfError or mfOKButton, '%s: ''%s''.', [InvalidDirText, Path]);
    Result := False;
  end
  else
    Result := True;
end;

end.
