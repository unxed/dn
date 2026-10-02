{ TvFileDlg: the file dialog: TSortedListBox, TFileInputLine, TFileInfoPane, TFileList,
  TFileDialog.

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/stddlg.h (class declarations, commands, flags)
    source/tvision/stddlg.cpp (TFileInputLine, TSortedListBox, TFileInfoPane),
    tfillist.cpp, tfildlg.cpp, tvtext2.cpp (texts)
  Borland disclaimer and MIT notice: tv/COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/DESIGN.md):
    - names and paths are ShortStrings (up to 255 characters, long names are shown as
      they are); the data record of the dialog is a ShortString;
    - the directory is read with TFileFinder (TvFiles); hidden and system files are not
      listed, as in the original;
    - FExpand does not change the case of the names, and keeps the separators of the
      system;
    - the "too many files" message is gone (a Pascal program stops on lack of memory);
    - streams are not translated yet. }
unit TvFileDlg;

{$I tvdefs.inc}

interface

uses
  TvGeom, TvColors, TvCell, TvKeys, TvEvents, TvDrawBuf, TvObjs, TvUtil, TvViews, TvDialog,
  TvWindow, TvList, TvInput, TvHist, TvMsgBox, TvApp, TvFiles;

const
  { commands }
  cmFileOpen    = 1001;
  cmFileReplace = 1002;
  cmFileClear   = 1003;
  cmFileInit    = 1004;
  cmChangeDir   = 1005;
  cmRevert      = 1006;
  { messages }
  cmFileFocused       = 102;    { a new file was focused in the TFileList }
  cmFileDoubleClicked = 103;    { a file was selected in the TFileList }
  { the buttons of the dialog }
  fdOKButton      = $0001;
  fdOpenButton    = $0002;
  fdReplaceButton = $0004;
  fdClearButton   = $0008;
  fdHelpButton    = $0010;
  fdNoLoadDir     = $0100;

  FilesText = '~F~iles';
  OpenText = '~O~pen';
  OKText = 'O~K~';
  ReplaceText = '~R~eplace';
  ClearText = '~C~lear';
  CancelText = 'Cancel';
  HelpText = '~H~elp';
  InvalidDriveText = 'Invalid drive or directory';
  InvalidFileText = 'Invalid file name';
  AmText = 'a';
  PmText = 'p';
  MonthNames: array[0..12] of string[3] =
    ('', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
  InfoPanePalette = #$1E;

type
  PFileInputLine = ^TFileInputLine;
  PFileDialog = ^TFileDialog;

  { shows the name of the focused file of the list }
  TFileInputLine = object(TInputLine)
    constructor Init(const Bounds: TRect; AMaxLen: Integer);
    procedure HandleEvent(var Event: TEvent); virtual;
  end;

  { a list box over a sorted collection that finds an item by the typed characters }
  PSortedListBox = ^TSortedListBox;
  TSortedListBox = object(TListBox)
    ShiftState: Word;
    SearchPos: Integer;
    constructor Init(const Bounds: TRect; ANumCols: Integer; AScrollBar: PScrollBar);
    procedure HandleEvent(var Event: TEvent); virtual;
    function GetKey(const S: ShortString): Pointer; virtual;
    procedure NewList(AList: PSortedCollection);
    function List: PSortedCollection;
  private
    KeyBuf: ShortString;
  end;

  PFileList = ^TFileList;
  TFileList = object(TSortedListBox)
    constructor Init(const Bounds: TRect; AScrollBar: PScrollBar);
    function DataSize: Integer; virtual;
    procedure FocusItem(Item: Integer); virtual;
    procedure GetData(var Rec); virtual;
    function GetKey(const S: ShortString): Pointer; virtual;
    function GetText(Item, MaxLen: Integer): ShortString; virtual;
    procedure SelectItem(Item: Integer); virtual;
    procedure SetData(var Rec); virtual;
    procedure ReadDirectory(const Dir, WildCard: ShortString);
    procedure ReadDirectoryMask(const AWildCard: ShortString);
  private
    KeyRec: TSearchRec;
  end;

  { Palette: 1 = text }
  PFileInfoPane = ^TFileInfoPane;
  TFileInfoPane = object(TView)
    FileBlock: TSearchRec;
    constructor Init(const Bounds: TRect);
    procedure Draw; virtual;
    function GetPalette: TPalette; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
  end;

  TFileDialog = object(TDialog)
    FileName: PFileInputLine;
    FileList: PFileList;
    WildCard: ShortString;
    Directory: PStr;
    constructor Init(const AWildCard, ATitle, InputName: ShortString; AOptions: Word;
      HistId: Byte);
    destructor Done; virtual;
    function GetFileName: ShortString;
    procedure GetData(var Rec); virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure SetData(var Rec); virtual;
    procedure SizeLimits(out Min, Max: TPoint); virtual;
    function Valid(Command: Word): Boolean; virtual;
    procedure ReadDirectory;
  private
    function CheckDirectory(const S: ShortString): Boolean;
  end;

implementation

{ --- TFileInputLine ---------------------------------------------------------- }

constructor TFileInputLine.Init(const Bounds: TRect; AMaxLen: Integer);
begin
  inherited Init(Bounds, AMaxLen);
  EventMask := EventMask or evBroadcast;
end;

procedure TFileInputLine.HandleEvent(var Event: TEvent);
var
  Rec: PSearchRec;
  S: ShortString;
begin
  inherited HandleEvent(Event);
  if (Event.What = evBroadcast) and (Event.Command = cmFileFocused) and
    ((State and sfSelected) = 0) then
  begin
    Rec := PSearchRec(Event.InfoPtr);
    S := Rec^.Name;
    if (Rec^.Attr and faDirectory) <> 0 then
      S := S + DirDelim + PFileDialog(Owner)^.WildCard;
    if Length(S) > MaxLen then
      SetLength(S, MaxLen);
    Data^ := S;
    SelectAll(False);
    DrawView;
  end;
end;

{ --- TSortedListBox ---------------------------------------------------------- }

constructor TSortedListBox.Init(const Bounds: TRect; ANumCols: Integer; AScrollBar: PScrollBar);
begin
  inherited Init(Bounds, ANumCols, AScrollBar);
  ShiftState := 0;
  SearchPos := -1;
  ShowCursor;
  SetCursor(1, 0);
end;

function TSortedListBox.List: PSortedCollection;
begin
  Result := PSortedCollection(Items);
end;

function TSortedListBox.GetKey(const S: ShortString): Pointer;
begin
  KeyBuf := S;
  Result := @KeyBuf;
end;

procedure TSortedListBox.NewList(AList: PSortedCollection);
begin
  inherited NewList(AList);
  SearchPos := -1;
end;

function EqualPrefix(const S1, S2: ShortString; Count: Integer): Boolean;
var
  I: Integer;
begin
  Result := (Length(S1) >= Count) and (Length(S2) >= Count);
  if Result then
    for I := 1 to Count do
      if UpCase(S1[I]) <> UpCase(S2[I]) then
        Exit(False);
end;

procedure TSortedListBox.HandleEvent(var Event: TEvent);
var
  CurString, NewString: ShortString;
  Value, OldPos, OldValue: Integer;
  K: Pointer;
  Ch: Char;
begin
  OldValue := Focused;
  inherited HandleEvent(Event);
  if (OldValue <> Focused) or ((Event.What = evBroadcast) and (Event.Command = cmReleasedFocus)) then
    SearchPos := -1;
  if (Event.What = evKeyDown) and (Event.CharCode <> 0) then
  begin
    Value := Focused;
    if Value < Range then
      CurString := GetText(Value, 255)
    else
      CurString := '';
    OldPos := SearchPos;
    Ch := Chr(Event.CharCode);
    if Event.KeyCode = kbBack then
    begin
      if SearchPos = -1 then
        Exit;
      Dec(SearchPos);
      if SearchPos = -1 then
        ShiftState := Event.ControlKeyState;
      SetLength(CurString, SearchPos + 1);
    end
    else if Ch = '.' then
    begin
      if Pos('.', CurString) = 0 then
        SearchPos := -1
      else
        SearchPos := Pos('.', CurString) - 1;
    end
    else
    begin
      Inc(SearchPos);
      if SearchPos = 0 then
        ShiftState := Event.ControlKeyState;
      SetLength(CurString, SearchPos + 1);
      CurString[SearchPos + 1] := Ch;
    end;
    K := GetKey(CurString);
    List^.Search(K, Value);
    if Value < Range then
    begin
      NewString := GetText(Value, 255);
      if EqualPrefix(CurString, NewString, SearchPos + 1) then
      begin
        if Value <> OldValue then
        begin
          FocusItem(Value);
          SetCursor(Cursor.X + SearchPos + 1, Cursor.Y);
        end
        else
          SetCursor(Cursor.X + (SearchPos - OldPos), Cursor.Y);
      end
      else
        SearchPos := OldPos;
    end
    else
      SearchPos := OldPos;
    if (SearchPos <> OldPos) or (Ch in ['A'..'Z', 'a'..'z']) then
      ClearEvent(Event);
  end;
end;

{ --- TFileList --------------------------------------------------------------- }

constructor TFileList.Init(const Bounds: TRect; AScrollBar: PScrollBar);
begin
  inherited Init(Bounds, 2, AScrollBar);
end;

function TFileList.DataSize: Integer;
begin
  Result := 0;
end;

procedure TFileList.GetData(var Rec);
begin
end;

procedure TFileList.SetData(var Rec);
begin
end;

procedure TFileList.FocusItem(Item: Integer);
begin
  inherited FocusItem(Item);
  Message(Owner, evBroadcast, cmFileFocused, List^.At(Item));
end;

procedure TFileList.SelectItem(Item: Integer);
begin
  Message(Owner, evBroadcast, cmFileDoubleClicked, List^.At(Item));
end;

function TFileList.GetKey(const S: ShortString): Pointer;
begin
  if ((ShiftState and kbShift) <> 0) or ((S <> '') and (S[1] = '.')) then
    KeyRec.Attr := faDirectory
  else
    KeyRec.Attr := 0;
  KeyRec.Name := S;
  Result := @KeyRec;
end;

function TFileList.GetText(Item, MaxLen: Integer): ShortString;
var
  F: PSearchRec;
begin
  F := PSearchRec(List^.At(Item));
  Result := F^.Name;
  if Length(Result) > MaxLen then
    SetLength(Result, MaxLen);
  if (F^.Attr and faDirectory) <> 0 then
    Result := Result + DirDelim;
end;

procedure TFileList.ReadDirectory(const Dir, WildCard: ShortString);
begin
  ReadDirectoryMask(Dir + WildCard);
end;

procedure TFileList.ReadDirectoryMask(const AWildCard: ShortString);
var
  Finder: TFileFinder;
  FileList: PFileCollection;
  Path, Drv, Dir, Name, Ext, Rest: ShortString;
  Parent: TSearchRec;
  NoFile: TSearchRec;
begin
  New(FileList, Init(5, 5));
  Finder.Init;
  if Finder.First(AWildCard, faReadOnly or faArchive) then
    repeat
      if (Finder.Rec.Attr and faDirectory) = 0 then
        FileList^.Insert(NewSearchRec(Finder.Rec));
    until not Finder.Next;
  Finder.Close;

  Path := FExpand(AWildCard);
  FSplit(Path, Dir, Name, Ext);
  if Finder.First(Dir + AllMask, faDirectory) then
    repeat
      if ((Finder.Rec.Attr and faDirectory) <> 0) and (Finder.Rec.Name[1] <> '.') then
        FileList^.Insert(NewSearchRec(Finder.Rec));
    until not Finder.Next;
  Finder.Close;

  Rest := Dir;
  Drv := '';
  if (Length(Rest) > 1) and (Rest[2] = ':') then
  begin
    Drv := Copy(Rest, 1, 2);
    Delete(Rest, 1, 2);
  end;
  if Length(Rest) > 1 then            { not the root: there is a parent directory }
  begin
    if Finder.First(Dir + '..', faDirectory) then
    begin
      Parent := Finder.Rec;
      Parent.Name := '..';
    end
    else
    begin
      Parent.Name := '..';
      Parent.Size := 0;
      Parent.Time := $210000;
      Parent.Attr := faDirectory;
    end;
    Finder.Close;
    FileList^.Insert(NewSearchRec(Parent));
  end;
  Finder.Done;

  NewList(FileList);
  if List^.Count > 0 then
    Message(Owner, evBroadcast, cmFileFocused, List^.At(0))
  else
  begin
    FillChar(NoFile, SizeOf(NoFile), 0);
    Message(Owner, evBroadcast, cmFileFocused, @NoFile);
  end;
end;

{ --- TFileInfoPane ----------------------------------------------------------- }

constructor TFileInfoPane.Init(const Bounds: TRect);
begin
  inherited Init(Bounds);
  EventMask := EventMask or evBroadcast;
  FileBlock.Name := '';
  FileBlock.Attr := 0;
  FileBlock.Time := 0;
  FileBlock.Size := 0;
end;

procedure TFileInfoPane.Draw;
var
  B: TDrawBuffer;
  Color: TColorAttr;
  Path, Buf: ShortString;
  Mon, Day, Year, Hour, Min: Integer;
  PM: Boolean;

  function Two(N: Integer): ShortString;
  begin
    Str(N, Result);
    if N < 10 then
      Result := '0' + Result;
  end;

begin
  Path := FExpand(PFileDialog(Owner)^.Directory^ + PFileDialog(Owner)^.WildCard);
  Color := GetColor($01).Lo;
  B.Init(Size.X);
  B.MoveChar(0, Ord(' '), Color, Size.X);
  B.MoveStrS(1, Path, Color);
  WriteLineD(0, 0, Size.X, 1, B);

  B.MoveChar(0, Ord(' '), Color, Size.X);
  B.MoveStrS(1, FileBlock.Name, Color);
  if FileBlock.Name <> '' then
  begin
    Str(FileBlock.Size, Buf);
    B.MoveStrS(Size.X - 38, Buf, Color);
    Min := (FileBlock.Time shr 5) and $3F;
    Hour := (FileBlock.Time shr 11) and $1F;
    Day := (FileBlock.Time shr 16) and $1F;
    Mon := (FileBlock.Time shr 21) and $0F;
    Year := ((FileBlock.Time shr 25) and $7F) + 1980;
    B.MoveStrS(Size.X - 22, MonthNames[Mon], Color);
    B.MoveStrS(Size.X - 18, Two(Day), Color);
    B.PutChar(Size.X - 16, Ord(','));
    Str(Year, Buf);
    B.MoveStrS(Size.X - 15, Buf, Color);
    PM := Hour >= 12;
    Hour := Hour mod 12;
    if Hour = 0 then
      Hour := 12;
    B.MoveStrS(Size.X - 9, Two(Hour), Color);
    B.PutChar(Size.X - 7, Ord(':'));
    B.MoveStrS(Size.X - 6, Two(Min), Color);
    if PM then
      B.MoveStrS(Size.X - 4, PmText, Color)
    else
      B.MoveStrS(Size.X - 4, AmText, Color);
  end;
  WriteLineD(0, 1, Size.X, 1, B);
  B.MoveChar(0, Ord(' '), Color, Size.X);
  WriteLineD(0, 2, Size.X, Size.Y - 2, B);
  B.Done;
end;

function TFileInfoPane.GetPalette: TPalette;
begin
  Result := MakePalette(InfoPanePalette);
end;

procedure TFileInfoPane.HandleEvent(var Event: TEvent);
begin
  inherited HandleEvent(Event);
  if (Event.What = evBroadcast) and (Event.Command = cmFileFocused) then
  begin
    FileBlock := PSearchRec(Event.InfoPtr)^;
    DrawView;
  end;
end;

{ --- TFileDialog ------------------------------------------------------------- }

constructor TFileDialog.Init(const AWildCard, ATitle, InputName: ShortString; AOptions: Word;
  HistId: Byte);
var
  R, Bounds, ScreenBounds: TRect;
  SB: PScrollBar;
  Opt: Word;
  Lbl: PLabel;
  Hist: PHistory;
  Btn: PButton;
  V: PView;
  ScreenSize: TPoint;

  procedure AddButton(const Title: ShortString; Command: Word);
  begin
    New(Btn, Init(R, Title, Command, Opt));
    Insert(Btn);
    Btn^.GrowMode := gfGrowLoX or gfGrowHiX;
    Opt := bfNormal;
    Inc(R.A.Y, 3);
    Inc(R.B.Y, 3);
  end;

begin
  R.Assign(15, 1, 64, 20);
  inherited Init(R, ATitle);
  Options := Options or ofCentered;
  Flags := Flags or wfGrow;
  Directory := NewStr('');
  WildCard := AWildCard;

  R.Assign(3, 3, 31, 4);
  New(FileName, Init(R, 255));
  FileName^.Data^ := WildCard;
  Insert(FileName);
  FileName^.GrowMode := gfGrowHiX;

  R.Assign(2, 2, 3 + CStrLen(InputName), 3);
  New(Lbl, Init(R, InputName, FileName));
  Insert(Lbl);
  Lbl^.GrowMode := 0;

  R.Assign(31, 3, 34, 4);
  New(Hist, Init(R, FileName, HistId));
  Insert(Hist);
  Hist^.GrowMode := gfGrowLoX or gfGrowHiX;

  R.Assign(3, 14, 34, 15);
  New(SB, Init(R));
  Insert(SB);
  R.Assign(3, 6, 34, 14);
  New(FileList, Init(R, SB));
  Insert(FileList);
  FileList^.GrowMode := gfGrowHiX or gfGrowHiY;
  R.Assign(2, 5, 8, 6);
  New(Lbl, Init(R, FilesText, FileList));
  Insert(Lbl);
  Lbl^.GrowMode := 0;

  Opt := bfDefault;
  R.Assign(35, 3, 46, 5);
  if (AOptions and fdOpenButton) <> 0 then
    AddButton(OpenText, cmFileOpen);
  if (AOptions and fdOKButton) <> 0 then
    AddButton(OKText, cmFileOpen);
  if (AOptions and fdReplaceButton) <> 0 then
    AddButton(ReplaceText, cmFileReplace);
  if (AOptions and fdClearButton) <> 0 then
    AddButton(ClearText, cmFileClear);
  AddButton(CancelText, cmCancel);
  if (AOptions and fdHelpButton) <> 0 then
    AddButton(HelpText, cmHelp);

  R.Assign(1, 16, 48, 18);
  New(PFileInfoPane(V), Init(R));
  Insert(V);
  V^.GrowMode := gfGrowAll and not gfGrowLoX;
  SelectNext(False);

  { the default size is set by resizing the dialog, to the size of the screen }
  if Application <> nil then
  begin
    Bounds := GetBounds;
    ScreenSize := Application^.Size;
    ScreenBounds := Application^.GetBounds;
    if ScreenSize.X > 90 then
      Bounds.Grow(15, 0)
    else if ScreenSize.X > 63 then
    begin
      ScreenBounds.Grow(-7, 0);
      Bounds.A.X := ScreenBounds.A.X;
      Bounds.B.X := ScreenBounds.B.X;
    end;
    if ScreenSize.Y > 34 then
      Bounds.Grow(0, 5)
    else if ScreenSize.Y > 25 then
    begin
      ScreenBounds.Grow(0, -3);
      Bounds.A.Y := ScreenBounds.A.Y;
      Bounds.B.Y := ScreenBounds.B.Y;
    end;
    Locate(Bounds);
  end;

  if (AOptions and fdNoLoadDir) = 0 then
    ReadDirectory;
end;

destructor TFileDialog.Done;
begin
  DisposeStr(Directory);
  Directory := nil;
  FileName := nil;
  FileList := nil;
  inherited Done;
end;

procedure TFileDialog.SizeLimits(out Min, Max: TPoint);
begin
  inherited SizeLimits(Min, Max);
  Min.X := 49;
  Min.Y := 19;
end;

{ the first word of S: leading blanks are skipped, the rest after the word is cut }
function Trim1(const S: ShortString): ShortString;
var
  I, J: Integer;
begin
  I := 1;
  while (I <= Length(S)) and (S[I] in [#9..#13, ' ']) do
    Inc(I);
  J := I;
  while (J <= Length(S)) and not (S[J] in [#9..#13, ' ']) do
    Inc(J);
  Result := Copy(S, I, J - I);
end;

function TFileDialog.GetFileName: ShortString;
var
  Buf, Dir, Name, Ext, TName, TExt: ShortString;
begin
  Buf := FExpandFrom(Trim1(FileName^.Data^), Directory^);
  FSplit(Buf, Dir, Name, Ext);
  if (Name = '') and (Ext = '') then
  begin
    { a directory: the mask of the dialog is taken }
    FSplit(WildCard, Name, TName, TExt);
    Buf := Dir + TName + TExt;
  end;
  Result := Buf;
end;

procedure TFileDialog.GetData(var Rec);
begin
  ShortString(Rec) := GetFileName;
end;

procedure TFileDialog.HandleEvent(var Event: TEvent);
begin
  inherited HandleEvent(Event);
  if Event.What = evCommand then
  begin
    case Event.Command of
      cmFileOpen, cmFileReplace, cmFileClear:
        begin
          EndModal(Event.Command);
          ClearEvent(Event);
        end;
    end;
  end
  else if (Event.What = evBroadcast) and (Event.Command = cmFileDoubleClicked) then
  begin
    Event.What := evCommand;
    Event.Command := cmOK;
    PutEvent(Event);
    ClearEvent(Event);
  end;
end;

procedure TFileDialog.ReadDirectory;
begin
  DisposeStr(Directory);
  Directory := NewStr(GetCurDir);
  FileList^.ReadDirectoryMask(WildCard);
end;

procedure TFileDialog.SetData(var Rec);
begin
  inherited SetData(Rec);
  if (ShortString(Rec) <> '') and IsWild(ShortString(Rec)) then
  begin
    Valid(cmFileInit);
    FileName^.Select;
  end;
end;

function TFileDialog.CheckDirectory(const S: ShortString): Boolean;
begin
  if PathValid(S) then
    Result := True
  else
  begin
    MessageBoxFmt(mfError or mfOKButton, '%s: ''%s''', [InvalidDriveText, S]);
    FileName^.Select;
    Result := False;
  end;
end;

function TFileDialog.Valid(Command: Word): Boolean;
var
  FName, Dir, Name, Ext: ShortString;
begin
  if Command = 0 then
    Exit(True);
  Result := False;
  if inherited Valid(Command) then
  begin
    if (Command <> cmCancel) and (Command <> cmFileClear) then
    begin
      FName := GetFileName;
      if IsWild(FName) then
      begin
        FSplit(FName, Dir, Name, Ext);
        if CheckDirectory(Dir) then
        begin
          DisposeStr(Directory);
          Directory := NewStr(Dir);
          WildCard := Name + Ext;
          if Command <> cmFileInit then
            FileList^.Select;
          FileList^.ReadDirectory(Directory^, WildCard);
        end;
      end
      else if IsDir(FName) then
      begin
        if CheckDirectory(FName) then
        begin
          DisposeStr(Directory);
          Directory := NewStr(FName + DirDelim);
          if Command <> cmFileInit then
            FileList^.Select;
          FileList^.ReadDirectory(Directory^, WildCard);
        end;
      end
      else if ValidFileName(FName) then
        Result := True
      else
        MessageBoxFmt(mfError or mfOKButton, '%s: ''%s''', [InvalidFileText, FName]);
    end
    else
      Result := True;
  end;
end;

end.
