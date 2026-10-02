{ TvFiles: the file system access of the standard dialogs: search records (with long
  names), path helpers, and the collections of files and directories.

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/stddlg.h (TSearchRec, TDirEntry, TFileCollection, TDirCollection)
    source/tvision/tfilecol.cpp, tdircoll.cpp (driveValid, isDir, pathValid, validFileName,
    getCurDir, isWild)
  Borland disclaimer and MIT notice: tv/COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/DESIGN.md):
    - names are ShortStrings (long file names are supported when the RTL supports them:
      under DOS FPC uses the LFN API of Windows 9x and DOSLFN when it is there), the size
      is an Int64;
    - the search is done by TFileFinder (instead of findfirst/findnext of <dir.h>);
    - FExpand and FSplit replace fexpand and fnsplit; the case of the names is not changed;
    - on systems without drive letters only the current "drive" exists, and paths are
      not given a drive prefix;
    - files are sorted ignoring the case (the original compares the bytes);
    - streams are not translated yet. }
unit TvFiles;

{$I tvdefs.inc}

interface

uses
  TvObjs, TvUtil;

{$IF DEFINED(GO32V2) OR DEFINED(WINDOWS) OR DEFINED(OS2) OR DEFINED(MSDOS)}
  {$DEFINE DRIVES}
{$ENDIF}

const
  { the separator of directories and the mask of all the files }
{$IFDEF DRIVES}
  DirDelim = '\';
  AllMask = '*.*';
{$ELSE}
  DirDelim = '/';
  AllMask = '*';
{$ENDIF}
  faReadOnly  = $01;
  faHidden    = $02;
  faSysFile   = $04;
  faVolumeID  = $08;
  faDirectory = $10;
  faArchive   = $20;
  faAnyFile   = $3F;

type
  PSearchRec = ^TSearchRec;
  TSearchRec = record
    Attr: Byte;
    Time: LongInt;           { the DOS date and time }
    Size: Int64;
    Name: ShortString;
  end;

  { A search in a directory; Rec is the current entry. }
  TFileFinder = object
    Rec: TSearchRec;
    constructor Init;
    destructor Done;
    { Path may have wildcards in the last part; Attr: the kinds of entries that are
      found in addition to normal files (faDirectory...). }
    function First(const Path: ShortString; Attr: Integer): Boolean;
    function Next: Boolean;
    procedure Close;
  private
    Sys: Pointer;
    Active: Boolean;
    procedure Fill;
  end;

  { Sorted: files by name, then directories by name, then '..' }
  PFileCollection = ^TFileCollection;
  TFileCollection = object(TSortedCollection)
    function Compare(Key1, Key2: Pointer): Integer; virtual;
    procedure FreeItem(Item: Pointer); virtual;
    function At2(Index: Integer): PSearchRec;
  end;

  PDirEntry = ^TDirEntry;
  TDirEntry = record
    Text: PStr;
    Dir: PStr;
  end;

  PDirCollection = ^TDirCollection;
  TDirCollection = object(TCollection)
    procedure FreeItem(Item: Pointer); virtual;
    function At2(Index: Integer): PDirEntry;
  end;

function NewDirEntry(const Txt, ADir: ShortString): PDirEntry;
function NewSearchRec(const Rec: TSearchRec): PSearchRec;

{ The drive exists (without drive letters only the "drive" C exists). }
function DriveValid(Drive: Char): Boolean;
{ The letter of the current drive ('C' without drive letters). }
function GetDisk: Char;
function IsDir(const S: ShortString): Boolean;
function PathValid(const Path: ShortString): Boolean;
function ValidFileName(const FileName: ShortString): Boolean;
{ The current directory of the drive (#0: of the current one), with a separator at the end. }
function GetCurDir(Drive: Char = #0): ShortString;
function IsWild(const F: ShortString): Boolean;
function FExpand(const Path: ShortString): ShortString;
{ A relative Path is taken from RelativeTo (itself relative to the current directory). }
function FExpandFrom(const Path, RelativeTo: ShortString): ShortString;
{ Dir includes the drive and the last separator; Ext starts with a dot. }
procedure FSplit(const Path: ShortString; out Dir, Name, Ext: ShortString);

implementation

uses
  SysUtils;

type
  PSysRec = ^SysUtils.TSearchRec;

function IsSeparator(C: Char): Boolean;
begin
  Result := (C = '\') or (C = '/');
end;

{ --- TFileFinder ------------------------------------------------------------- }

constructor TFileFinder.Init;
begin
  Sys := nil;
  Active := False;
  Rec.Name := '';
end;

destructor TFileFinder.Done;
begin
  Close;
end;

procedure TFileFinder.Fill;
var
  P: PSysRec;
begin
  P := PSysRec(Sys);
  Rec.Attr := Byte(P^.Attr);
  Rec.Time := P^.Time;
  Rec.Size := P^.Size;
  Rec.Name := ShortString(P^.Name);
end;

function TFileFinder.First(const Path: ShortString; Attr: Integer): Boolean;
begin
  Close;
  New(PSysRec(Sys));
  Active := FindFirst(AnsiString(Path), Attr, PSysRec(Sys)^) = 0;
  Result := Active;
  if Active then
    Fill
  else
  begin
    { a failed search is closed too: the DOS RTL keeps the LFN search record (304 bytes)
      allocated otherwise (found with the heap marks of t_files) }
    FindClose(PSysRec(Sys)^);
    Dispose(PSysRec(Sys));
    Sys := nil;
  end;
end;

function TFileFinder.Next: Boolean;
begin
  Result := Active and (FindNext(PSysRec(Sys)^) = 0);
  if Result then
    Fill;
end;

procedure TFileFinder.Close;
begin
  if Sys <> nil then
  begin
    FindClose(PSysRec(Sys)^);
    Dispose(PSysRec(Sys));
    Sys := nil;
  end;
  Active := False;
end;

{ --- the collections --------------------------------------------------------- }

function NewSearchRec(const Rec: TSearchRec): PSearchRec;
begin
  New(Result);
  Result^ := Rec;
end;

function TFileCollection.Compare(Key1, Key2: Pointer): Integer;
var
  A, B: PSearchRec;
  DirA, DirB: Boolean;
begin
  A := PSearchRec(Key1);
  B := PSearchRec(Key2);
  if A^.Name = B^.Name then
    Exit(0);
  if A^.Name = '..' then
    Exit(1);
  if B^.Name = '..' then
    Exit(-1);
  DirA := (A^.Attr and faDirectory) <> 0;
  DirB := (B^.Attr and faDirectory) <> 0;
  if DirA and not DirB then
    Exit(1);
  if DirB and not DirA then
    Exit(-1);
  Result := CompareText(AnsiString(A^.Name), AnsiString(B^.Name));
  if Result = 0 then
    Result := CompareStr(AnsiString(A^.Name), AnsiString(B^.Name));
end;

procedure TFileCollection.FreeItem(Item: Pointer);
begin
  Dispose(PSearchRec(Item));
end;

function TFileCollection.At2(Index: Integer): PSearchRec;
begin
  Result := PSearchRec(At(Index));
end;

function NewDirEntry(const Txt, ADir: ShortString): PDirEntry;
begin
  New(Result);
  Result^.Text := NewStr(Txt);
  Result^.Dir := NewStr(ADir);
end;

procedure TDirCollection.FreeItem(Item: Pointer);
begin
  DisposeStr(PDirEntry(Item)^.Text);
  DisposeStr(PDirEntry(Item)^.Dir);
  Dispose(PDirEntry(Item));
end;

function TDirCollection.At2(Index: Integer): PDirEntry;
begin
  Result := PDirEntry(At(Index));
end;

{ --- paths ------------------------------------------------------------------- }

function DriveValid(Drive: Char): Boolean;
begin
{$IFDEF DRIVES}
  Drive := UpCase(Drive);
  Result := (Drive >= 'A') and (Drive <= 'Z') and (DiskSize(Ord(Drive) - Ord('A') + 1) <> -1);
{$ELSE}
  Result := UpCase(Drive) = 'C';
{$ENDIF}
end;

function GetDisk: Char;
var
  S: ShortString;
begin
{$IFDEF DRIVES}
  GetDir(0, S);
  if (Length(S) > 1) and (S[2] = ':') then
    Result := UpCase(S[1])
  else
    Result := 'C';
{$ELSE}
  Result := 'C';
{$ENDIF}
end;

function IsDir(const S: ShortString): Boolean;
var
  F: TFileFinder;
begin
  F.Init;
  Result := F.First(S, faDirectory) and ((F.Rec.Attr and faDirectory) <> 0);
  F.Done;
  if not Result then
    Result := DirectoryExists(AnsiString(S));
end;

function PathValid(const Path: ShortString): Boolean;
var
  P: ShortString;
begin
  P := FExpand(Path);
  if (Length(P) = 1) and IsSeparator(P[1]) then
    Exit(True);                { the root directory is always valid }
{$IFDEF DRIVES}
  if Length(P) <= 3 then
    Exit(DriveValid(P[1]));
{$ENDIF}
  if (Length(P) > 0) and IsSeparator(P[Length(P)]) then
    SetLength(P, Length(P) - 1);
  Result := IsDir(P);
end;

function ValidFileName(const FileName: ShortString): Boolean;
const
  Illegal = '<>|"\';
var
  Dir, Name, Ext: ShortString;
  I: Integer;
begin
  FSplit(FileName, Dir, Name, Ext);
  if (Dir <> '') and not PathValid(Dir) then
    Exit(False);
  for I := 1 to Length(Name) do
    if Pos(Name[I], Illegal) > 0 then
      Exit(False);
  for I := 2 to Length(Ext) do
    if (Pos(Ext[I], Illegal) > 0) or (Ext[I] = '.') then
      Exit(False);
  Result := True;
end;

function GetCurDir(Drive: Char): ShortString;
var
  S: ShortString;
  N: Byte;
begin
{$IFDEF DRIVES}
  if (Drive >= 'A') and (Drive <= 'Z') then
    N := Ord(Drive) - Ord('A') + 1
  else if (Drive >= 'a') and (Drive <= 'z') then
    N := Ord(Drive) - Ord('a') + 1
  else
    N := 0;
{$ELSE}
  N := 0;
{$ENDIF}
  GetDir(N, S);
  if (Length(S) = 0) or not IsSeparator(S[Length(S)]) then
    S := S + PathDelim;
  Result := S;
end;

function IsWild(const F: ShortString): Boolean;
begin
  Result := (Pos('*', F) > 0) or (Pos('?', F) > 0);
end;

function FExpand(const Path: ShortString): ShortString;
begin
  Result := ShortString(ExpandFileName(AnsiString(Path)));
end;

function FExpandFrom(const Path, RelativeTo: ShortString): ShortString;
var
  Absolute: Boolean;
begin
  Absolute := (Path <> '') and IsSeparator(Path[1]);
{$IFDEF DRIVES}
  Absolute := Absolute or ((Length(Path) > 2) and (Path[2] = ':') and IsSeparator(Path[3]));
{$ENDIF}
  if Absolute or (RelativeTo = '') then
    Result := FExpand(Path)
  else if IsSeparator(RelativeTo[Length(RelativeTo)]) then
    Result := FExpand(RelativeTo + Path)
  else
    Result := FExpand(RelativeTo + PathDelim + Path);
end;

procedure FSplit(const Path: ShortString; out Dir, Name, Ext: ShortString);
var
  I, DotPos, Start: Integer;
begin
  Start := 0;
  for I := Length(Path) downto 1 do
{$IFDEF DRIVES}
    if IsSeparator(Path[I]) or (Path[I] = ':') then
{$ELSE}
    if IsSeparator(Path[I]) then
{$ENDIF}
    begin
      Start := I;
      Break;
    end;
  Dir := Copy(Path, 1, Start);
  DotPos := 0;
  for I := Length(Path) downto Start + 1 do
    if Path[I] = '.' then
    begin
      DotPos := I;
      Break;
    end;
  if DotPos > 0 then
  begin
    Name := Copy(Path, Start + 1, DotPos - Start - 1);
    Ext := Copy(Path, DotPos, 255);
  end
  else
  begin
    Name := Copy(Path, Start + 1, 255);
    Ext := '';
  end;
end;

end.
