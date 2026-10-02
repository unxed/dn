{ VPSysLow: the system layer that DN OSP takes from the runtime library of Virtual Pascal, written anew
  for Free Pascal. It replaces vpsyslow.pas of the archive (code of vpascal.com, see dn/exclude.list).

  License of DN (see dn/README.md). The names and the way they are called
  come from the call sites in DN (spec/vp-api-vpsyslow.md, tools/vp-api.py).

  Done here: the types, the open mode constants, the file, disk and system functions that DN calls on
  the DOS target (DPMI32), and the screen functions of its videoman.pas (SysTv*, SysSetVideoMode) over
  TvScreen of tv/. The screen of DN is an array of 16-bit cells (character + BIOS attribute); here it is
  a copy that is made from the screen of tv/ when DN asks for it and goes back to it by SysTvShowBuf.
  The keyboard and the mouse are done by tv/ (TvSys): SysTvKbd*, SysTvDetectMouse do nothing. }
unit VPSysLow;

{$mode objfpc}
{$H-}

interface

type
  SmallWord = Word;
  THandle = LongInt;
  TQuad = Int64;                 { disk sizes are 64-bit }
  TFileSize = Int64;
  PLongInt = ^LongInt;
  TSysPoint = record
    X, Y: SmallWord;
  end;
  PSysPoint = ^TSysPoint;

const
  { how a file is opened: the access mode (low 3 bits) and the sharing mode, as in DOS INT 21h AH=3Dh }
  Open_Access_ReadOnly     = $00;
  Open_Access_WriteOnly    = $01;
  Open_Access_ReadWrite    = $02;
  Open_Share_DenyReadWrite = $10;
  Open_Share_DenyWrite     = $20;
  Open_Share_DenyRead      = $30;
  Open_Share_DenyNone      = $40;

{ --- the screen (a copy of the screen of tv/ in 16-bit cells) ---------------------- }

{ The size of the screen; the result is the mode of DN: 3 (80x25 and the like) or $0103 (more lines, small
  font). Size may be nil. }
function SysTvGetScrMode(Size: PSysPoint; Flag: Boolean): Word;
function SysTvSetScrMode(Mode: Word): Boolean;
function SysSetVideoMode(Cols, Rows: Word): Boolean;
{ The screen as an array of 16-bit cells; it is filled from the screen of tv/ at every call. }
function SysTvGetSrcBuf: Pointer;
{ Writes Size cells from the position Pos (the number of the cell) of that array to the screen of tv/. }
procedure SysTvShowBuf(Pos, Size: LongInt);
procedure SysTvClrScr;
procedure SysTvInitCursor;
procedure SysTvGetCurType(var Y1, Y2: Integer; var Visible: Boolean);
procedure SysTvSetCurType(Y1, Y2: Integer; Visible: Boolean);
procedure SysTvSetCurPos(X, Y: Word);
procedure SysGetCurPos(var X, Y: Word);
procedure SysTvKbdInit;
procedure SysTvKbdDone;
procedure SysTvDetectMouse;
procedure SysTvHideMouse;

{ --- files -------------------------------------------------------------------- }
{ The result is 0 when done, else the error code of the system (DOS codes: 2 no such file, 3 no such
  path, 5 access denied...). }
function SysFileOpen(FileName: PChar; Mode: LongInt; var Handle: LongInt): LongInt;
function SysFileCreate(FileName: PChar; Mode, Attr: LongInt; var Handle: LongInt): LongInt;
{ Method: 0 from the beginning, 1 from the current position, 2 from the end. }
function SysFileSeek(Handle: THandle; Distance, Method: LongInt; var Actual: LongInt): LongInt;
function SysFileRead(Handle: THandle; var Buffer; Count: LongInt; var Actual: LongInt): LongInt;
function SysFileWrite(Handle: THandle; const Buffer; Count: LongInt; var Actual: LongInt): LongInt;
function SysFileClose(Handle: THandle): LongInt;
function SysFileSetSize(Handle: THandle; Size: TFileSize): LongInt;
{ nonzero (the low byte) when the handle is a device (a terminal, a printer...), 0 for a file }
function SysFileIsDevice(Handle: THandle): LongInt;

{ The label of the volume of the drive ('' if there is none). }
function SysGetVolumeLabel(Drive: Char): ShortString;

{ --- searching a directory ---------------------------------------------------- }
type
  { The record of a search. The first fields are laid out as DN (vpsyslo2.pas) expects them; the state of
    the search is kept by the unit (Handle is a number of a slot). Name ends with a zero byte after its
    last character, so that it can be taken as a PChar too. }
  POSSearchRec = ^TOSSearchRec;
  TOSSearchRec = packed record
    Handle: LongInt;
    NameLStr: Pointer;
    Attr: Byte;
    Time: LongInt;               { DOS date and time }
    Size: TFileSize;
    Name: ShortString;
    Filler: array[0..3] of Char;
  end;

{ 0 when found, else the error code (18 = nothing more) }
function SysFindFirst(Path: PChar; Attr: LongInt; var F: TOSSearchRec; IsPChar: Boolean): LongInt;
function SysFindNext(var F: TOSSearchRec; IsPChar: Boolean): LongInt;
function SysFindClose(var F: TOSSearchRec): LongInt;

{ --- disks -------------------------------------------------------------------- }
{ Free and total space of the disk of the path (the drive letter and the colon of the path are taken,
  else the current disk), -1 when it cannot be found out. }
function SysDiskFreeLongX(Path: PChar): TQuad;
function SysDiskSizeLongX(Path: PChar): TQuad;
{ The same by the number of the drive: 1 = A, 2 = B..., 0 = the current one. }
function SysDiskFreeLong(Drive: Byte): TQuad;
{ A bit for every drive that exists: bit 0 = A. }
function SysGetValidDrives: LongWord;

{ --- the system --------------------------------------------------------------- }
{ -1 OS/2, 0 DOS, 1 Windows 9x, 2 Windows NT; here: 0 (DOS) on DOS, 2 elsewhere }
function SysPlatformId: LongInt;
procedure SysCtrlSleep(Milliseconds: LongInt);
procedure SysBeepEx(Frequency, Duration: LongInt);
{ Bytes of memory that can be used for buffers. }
function PhysMemAvail: LongInt;
{ Runs a program and waits for it; returns the DOS error code (0 = the program was run). Env, Async and the
  redirection handles of the Virtual Pascal version are ignored: DOS has no use for them. }
function SysExecute(Path, Args, Env: PChar; Async: Boolean; ReportPid: Pointer;
  StdIn, StdOut, StdErr: LongInt): LongInt;
{ In DOS: the critical error handler does not stop the program (INT 24h answers "fail"). }
procedure SysDisableHardErrors;
{ A place for the Ctrl-Break handler of the program; here it only remembers that it was set. }
procedure SysCtrlSetCBreakHandler;

implementation

uses
  SysUtils, Dos, TvCell, TvColors, TvScreen
{$IFDEF GO32V2}, go32{$ENDIF};

{ --- files -------------------------------------------------------------------- }

function ErrorOfFile: LongInt;
begin
{$IFDEF GO32V2}
  Result := 2;                     { the RTL of go32v2 has no GetLastOSError }
{$ELSE}
  Result := GetLastOSError;
  if Result = 0 then
    Result := 2;
{$ENDIF}
end;

function SysFileOpen(FileName: PChar; Mode: LongInt; var Handle: LongInt): LongInt;
var
  H: THandle;
  M: Word;
begin
  case Mode and 7 of
    Open_Access_WriteOnly: M := fmOpenWrite;
    Open_Access_ReadWrite: M := fmOpenReadWrite;
  else
    M := fmOpenRead;
  end;
  H := FileOpen(StrPas(FileName), M or fmShareDenyNone);
  if H = THandle(-1) then
  begin
    Handle := 0;
    Result := ErrorOfFile;
  end
  else
  begin
    Handle := H;
    Result := 0;
  end;
end;

function SysFileCreate(FileName: PChar; Mode, Attr: LongInt; var Handle: LongInt): LongInt;
var
  H: THandle;
begin
  H := FileCreate(StrPas(FileName));
  if H = THandle(-1) then
  begin
    Handle := 0;
    Result := ErrorOfFile;
  end
  else
  begin
    Handle := H;
    Result := 0;
  end;
end;

function SysFileSeek(Handle: THandle; Distance, Method: LongInt; var Actual: LongInt): LongInt;
var
  R: Int64;
begin
  R := FileSeek(Handle, Int64(Distance), Method);
  if R < 0 then
  begin
    Actual := 0;
    Result := ErrorOfFile;
  end
  else
  begin
    Actual := R;
    Result := 0;
  end;
end;

function SysFileRead(Handle: THandle; var Buffer; Count: LongInt; var Actual: LongInt): LongInt;
begin
  Actual := FileRead(Handle, Buffer, Count);
  if Actual < 0 then
  begin
    Actual := 0;
    Result := ErrorOfFile;
  end
  else
    Result := 0;
end;

function SysFileWrite(Handle: THandle; const Buffer; Count: LongInt; var Actual: LongInt): LongInt;
begin
  Actual := FileWrite(Handle, Buffer, Count);
  if Actual < 0 then
  begin
    Actual := 0;
    Result := ErrorOfFile;
  end
  else
    Result := 0;
end;

function SysFileClose(Handle: THandle): LongInt;
begin
  FileClose(Handle);
  Result := 0;
end;

function SysFileSetSize(Handle: THandle; Size: TFileSize): LongInt;
begin
  if FileTruncate(Handle, Size) then
    Result := 0
  else
    Result := 1;
end;

function SysFileIsDevice(Handle: THandle): LongInt;
{$IFDEF GO32V2}
var
  R: TRealRegs;
begin
  { INT 21h AX=4400h: the device information word of the handle, bit 7 = a device }
  FillChar(R, SizeOf(R), 0);
  R.ax := $4400;
  R.bx := Handle;
  RealIntr($21, R);
  if ((R.flags and 1) = 0) and ((R.dx and $80) <> 0) then
    Result := R.dx and $FF
  else
    Result := 0;
end;
{$ELSE}
begin
  Result := 0;                 { no devices to tell from files on the systems of the tests }
end;
{$ENDIF}

{ --- the screen ---------------------------------------------------------------- }

const
  FontHeight = 16;                 { the lines of a character cell; the caret size of tv/ is in percent }

var
  CellCopy: array of Word;

function SysTvGetScrMode(Size: PSysPoint; Flag: Boolean): Word;
begin
  if Size <> nil then
  begin
    Size^.X := ScreenWidth;
    Size^.Y := ScreenHeight;
  end;
  if ScreenHeight > 25 then
    Result := $0103
  else
    Result := 3;
end;

function SysTvSetScrMode(Mode: Word): Boolean;
begin
  Result := True;                  { TODO: the size of the screen is the business of tv/ }
end;

function SysSetVideoMode(Cols, Rows: Word): Boolean;
begin
  Result := (ScreenWidth = Cols) and (ScreenHeight = Rows);
end;

function SysTvGetSrcBuf: Pointer;
var
  I, N: Integer;
  C: PScreenCell;
begin
  N := ScreenWidth * ScreenHeight;
  if Length(CellCopy) <> N then
    SetLength(CellCopy, N);
  C := ScreenBuffer;
  for I := 0 to N - 1 do
  begin
    if (C <> nil) and (ScLength(C^.Character) = 1) then
      CellCopy[I] := C^.Character.Text[0] or (Word(AttrAsBIOSByte(C^.Attribute)) shl 8)
    else if C <> nil then
      CellCopy[I] := Ord('?') or (Word(AttrAsBIOSByte(C^.Attribute)) shl 8)
    else
      CellCopy[I] := $0720;
    if C <> nil then
      Inc(C);
  end;
  if N = 0 then
    Exit(nil);
  Result := @CellCopy[0];
end;

procedure SysTvShowBuf(Pos, Size: LongInt);
var
  Row: array of TScreenCell;
  X, Y, N, I: Integer;
begin
  if (ScreenWidth <= 0) or (Length(CellCopy) = 0) then
    Exit;
  SetLength(Row, ScreenWidth);
  while (Size > 0) and (Pos < Length(CellCopy)) do
  begin
    Y := Pos div ScreenWidth;
    X := Pos mod ScreenWidth;
    N := ScreenWidth - X;
    if N > Size then
      N := Size;
    for I := 0 to N - 1 do
      Row[I] := CellFromBIOS(CellCopy[Pos + I]);
    if ScreenBuffer <> nil then
      Move(Row[0], (ScreenBuffer + Y * ScreenWidth + X)^, N * SizeOf(TScreenCell));
    ScreenWrite(X, Y, @Row[0], N);
    Inc(Pos, N);
    Dec(Size, N);
  end;
end;

procedure SysTvClrScr;
var
  I: Integer;
begin
  SetLength(CellCopy, ScreenWidth * ScreenHeight);
  for I := 0 to High(CellCopy) do
    CellCopy[I] := $0720;
  SysTvShowBuf(0, Length(CellCopy));
end;

procedure SysTvInitCursor;
begin
end;

procedure SysTvGetCurType(var Y1, Y2: Integer; var Visible: Boolean);
var
  H: Integer;
begin
  Visible := CaretSize > 0;
  H := (CaretSize * FontHeight + 99) div 100;
  if H < 1 then
    H := 1;
  Y2 := FontHeight - 1;
  Y1 := FontHeight - H;
end;

procedure SysTvSetCurType(Y1, Y2: Integer; Visible: Boolean);
begin
  if not Visible then
    SetCaretSize(0)
  else if Y2 >= Y1 then
    SetCaretSize((Y2 - Y1 + 1) * 100 div FontHeight)
  else
    SetCaretSize(CursorLines);
end;

procedure SysTvSetCurPos(X, Y: Word);
begin
  SetCaretPosition(X, Y);
end;

procedure SysGetCurPos(var X, Y: Word);
begin
  X := CaretX;
  Y := CaretY;
end;

procedure SysTvKbdInit;
begin
end;

procedure SysTvKbdDone;
begin
end;

procedure SysTvDetectMouse;
begin
end;

procedure SysTvHideMouse;
begin
end;

function SysGetVolumeLabel(Drive: Char): ShortString;
{$IFDEF GO32V2}
var
  SR: Dos.SearchRec;
begin
  Result := '';
  Dos.FindFirst(UpCase(Drive) + ':\*.*', Dos.VolumeID, SR);
  if Dos.DosError = 0 then
  begin
    Result := SR.Name;
    Dos.FindClose(SR);
  end;
end;
{$ELSE}
begin
  Result := '';
end;
{$ENDIF}

{ --- searching a directory ---------------------------------------------------- }

const
  MaxSearches = 64;
type
  PSysSearch = ^SysUtils.TSearchRec;
var
  Searches: array[1..MaxSearches] of PSysSearch;

procedure Fill(var F: TOSSearchRec; const R: SysUtils.TSearchRec; IsPChar: Boolean);
var
  N: ShortString;
begin
  N := ShortString(R.Name);
  F.Attr := Byte(R.Attr);
  F.Time := R.Time;
  F.Size := R.Size;
  F.Name := N;
  F.Name[Length(N) + 1] := #0;
end;

function SysFindFirst(Path: PChar; Attr: LongInt; var F: TOSSearchRec; IsPChar: Boolean): LongInt;
var
  I: Integer;
begin
  I := 1;
  while (I <= MaxSearches) and (Searches[I] <> nil) do
    Inc(I);
  if I > MaxSearches then
    Exit(4);                       { too many open files }
  New(Searches[I]);
  if SysUtils.FindFirst(StrPas(Path), Attr, Searches[I]^) <> 0 then
  begin
    SysUtils.FindClose(Searches[I]^);
    Dispose(Searches[I]);
    Searches[I] := nil;
    F.Handle := 0;
    Exit(18);
  end;
  F.Handle := I;
  Fill(F, Searches[I]^, IsPChar);
  Result := 0;
end;

function SysFindNext(var F: TOSSearchRec; IsPChar: Boolean): LongInt;
begin
  if (F.Handle < 1) or (F.Handle > MaxSearches) or (Searches[F.Handle] = nil) then
    Exit(6);                       { invalid handle }
  if SysUtils.FindNext(Searches[F.Handle]^) <> 0 then
    Exit(18);
  Fill(F, Searches[F.Handle]^, IsPChar);
  Result := 0;
end;

function SysFindClose(var F: TOSSearchRec): LongInt;
begin
  if (F.Handle >= 1) and (F.Handle <= MaxSearches) and (Searches[F.Handle] <> nil) then
  begin
    SysUtils.FindClose(Searches[F.Handle]^);
    Dispose(Searches[F.Handle]);
    Searches[F.Handle] := nil;
  end;
  F.Handle := 0;
  Result := 0;
end;

{ --- disks -------------------------------------------------------------------- }

{ the number of the drive of a path (1 = A), 0 when the path has no drive }
function DriveOfPath(Path: PChar): Byte;
begin
  Result := 0;
  if (Path <> nil) and (Path[0] <> #0) and (Path[1] = ':') then
    if UpCase(Path[0]) in ['A'..'Z'] then
      Result := Ord(UpCase(Path[0])) - Ord('A') + 1;
end;

function SysDiskFreeLongX(Path: PChar): TQuad;
begin
  Result := DiskFree(DriveOfPath(Path));
end;

function SysDiskSizeLongX(Path: PChar): TQuad;
begin
  Result := DiskSize(DriveOfPath(Path));
end;

function SysDiskFreeLong(Drive: Byte): TQuad;
begin
  Result := DiskFree(Drive);
end;

function SysGetValidDrives: LongWord;
{$IFDEF GO32V2}
var
  I: Integer;
begin
  Result := 0;
  for I := 1 to 26 do
    if DiskSize(I) <> -1 then
      Result := Result or (LongWord(1) shl (I - 1));
end;
{$ELSE}
begin
  Result := 1 shl 2;           { one disk, C: (as in tv/: systems without drive letters) }
end;
{$ENDIF}

{ --- the system --------------------------------------------------------------- }

function SysPlatformId: LongInt;
begin
{$IFDEF GO32V2}
  Result := 0;
{$ELSE}
  Result := 2;
{$ENDIF}
end;

procedure SysCtrlSleep(Milliseconds: LongInt);
begin
  if Milliseconds > 0 then
    Sleep(Milliseconds);
end;

procedure SysBeepEx(Frequency, Duration: LongInt);
{$IFDEF GO32V2}
var
  Divisor: LongInt;
  Port61: Byte;
begin
  if (Frequency < 20) or (Frequency > 20000) then
    Exit;
  { the PC speaker: the timer 2 gives the tone, the bits 0 and 1 of port 61h switch it on }
  Divisor := 1193180 div Frequency;
  outportb($43, $B6);
  outportb($42, Divisor and $FF);
  outportb($42, (Divisor shr 8) and $FF);
  Port61 := inportb($61);
  outportb($61, Port61 or 3);
  Sleep(Duration);
  outportb($61, inportb($61) and not 3);
end;
{$ELSE}
begin
  { nothing to play on the systems of the tests }
end;
{$ENDIF}

function PhysMemAvail: LongInt;
{$IFDEF GO32V2}
var
  MI: tmeminfo;
begin
  { DPMI: the largest block that can be allocated; -1 means that the host does not tell }
  Result := 16 * 1024 * 1024;
  if get_meminfo(MI) then
  begin
    if MI.available_memory <> -1 then
      Result := MI.available_memory
    else if MI.available_physical_pages <> -1 then
      Result := MI.available_physical_pages * 4096;
  end;
end;
{$ELSE}
begin
  Result := 256 * 1024 * 1024;
end;
{$ENDIF}

function SysExecute(Path, Args, Env: PChar; Async: Boolean; ReportPid: Pointer;
  StdIn, StdOut, StdErr: LongInt): LongInt;
begin
  Dos.DosError := 0;
  Dos.Exec(StrPas(Path), StrPas(Args));
  Result := Dos.DosError;          { 0 = the program was run; its exit code is Dos.DosExitCode }
end;

procedure SysDisableHardErrors;
begin
end;

var
  CBreakHandlerSet: Boolean = False;

procedure SysCtrlSetCBreakHandler;
begin
  CBreakHandlerSet := True;
end;

end.
