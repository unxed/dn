{ VPSysLow: the system layer that DN OSP takes from the runtime library of Virtual Pascal, written anew
  for Free Pascal. It replaces vpsyslow.pas of the archive (code of vpascal.com, see dn/exclude.list).

  This unit is our own code (MIT, see LICENSE). The names and the way they are called
  come from the call sites in DN (spec/vp-api-vpsyslow.md, tools/vp-api.py); nothing is copied from the
  Virtual Pascal sources.

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
  { the attribute of a found entry that is a symbolic link (Unix): the bit of a device in DOS, which is never found by a search }
  SysLinkAttr              = $40;

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

{ --- names of files ----------------------------------------------------------- }
{ The names of DN are those of DOS: "C:\DIR\FILE.EXT", in any case. On Unix (the Linux build) they are turned into the
  names of the system: the drive letter is dropped (the only disk, C:, is the root), "\" becomes "/", and the case of the
  names that exist is found (a name that does not exist is left as it is, so that it can be created). Elsewhere the name is
  returned as it is. }
function SysOsPath(const S: string): string;
{ The bytes of a text of DN (its code page) as the system wants them: UTF-8 on Unix (see NameToOs), else the text as it is. }
function SysNameToOs(const S: string): string;
{ Unix: runs a command of the shell with the terminal (the screen of the application is left, the command writes to the terminal, Enter
  returns to DN and the screen is drawn again); returns the exit code of the shell. Elsewhere: -1 (nothing is run). }
function SysRunShell(const CmdLine: string): LongInt;
{ GetDir for DN: the current directory as "C:\DIR" (on Unix: C: is the root). }
procedure SysGetDirDos(D: Byte; var S: string);

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
{ The disk buffers go to the disks (DOS INT 21h AH=0Dh); elsewhere: nothing. }
procedure SysDiskReset;
{ A line of the trace of the start (a test aid, see DNErrLog): written when the environment variable DNDUMP is set. }
procedure SysTrace(const Msg: String);
{ The keyboard of the plain console: is a key waiting, and the character of the key (SysReadKey waits for one). }
function SysKeyPressed: Boolean;
function SysReadKey: Char;
{ The place in the source of an address (VP: from the debug information); here the line information of FPC (the units are
  compiled with -gl): the file with the routine, the line; nil if there is none. }
function GetLocationInfo(Addr: Pointer; var FileName: ShortString; var LineNo: LongInt): Pointer;
procedure SysBeepEx(Frequency, Duration: LongInt);
{ Bytes of memory that can be used for buffers. }
function PhysMemAvail: LongInt;
{ Runs a program and waits for it; returns the DOS error code (0 = the program was run). Env, Async and the
  redirection handles of the Virtual Pascal version are ignored: DOS has no use for them. }
type
  { how DN starts a program (DNExec compares ExecFlags with efAsync; here only the names, the value is not used) }
  TExecFlags = (efSync, efAsync, efDetach, efInherit);
var
  ExecFlags: TExecFlags = efSync;

function SysExecute(Path, Args, Env: PChar; Async: Boolean; ReportPid: Pointer;
  StdIn, StdOut, StdErr: LongInt): LongInt;
{ In DOS: the critical error handler does not stop the program (INT 24h answers "fail"). }
procedure SysDisableHardErrors;
{ A place for the Ctrl-Break handler of the program; here it only remembers that it was set. }
procedure SysCtrlSetCBreakHandler;

var
  { the text screen of the program that started DN (16-bit cells: character + attribute), copied before the application takes
    the screen over: the "user screen" of DN (Ctrl-O, Alt-F5) and what is seen after the exit }
  SysStartScreen: array of Word;
  SysStartScreenWidth: Integer = 0;

implementation

uses
  SysUtils, Dos, TvCell, TvColors, TvScreen, TvEvents, TvSys, TvObjs, TvCodePg, TvUtf8, DNErrLog, LineInfo
{$IFDEF GO32V2}, go32, TvDos{$ENDIF}
{$IFDEF UNIX}, BaseUnix, Unix{$ENDIF}
{$IF DEFINED(UNIX) OR DEFINED(WINDOWS)}, TvUnix{$ENDIF};

{ --- names of files ----------------------------------------------------------- }

{$IFDEF UNIX}
function PathExists(const P: string): Boolean;
begin
  Result := fpAccess(P, F_OK) = 0;
end;

{ The names of the files in DN are bytes of its code page (CP866 for the Russian text of the language files and the screen), in
  Linux they are UTF-8. At the border the names are converted: a name that is valid UTF-8 and has only characters that the
  page of DN has is turned into the bytes of the page (so that Russian names are shown as Russian); a name that is not (other
  characters, not UTF-8) stays as it is. The way back (SysOsPath) takes the converted name if such a file exists, else the
  name as it is. This is a stop-gap until DN is UTF-8 inside (PLAN.md, item 4). DN_NAME_CONV=0 switches it off. }
var
  NameConv: Boolean = True;

function HasHigh(const S: string): Boolean;
var
  I: Integer;
begin
  for I := 1 to Length(S) do
    if Byte(S[I]) >= $80 then
      Exit(True);
  Result := False;
end;

function NameFromOs(const S: string): string;
var
  I, Used: Integer;
  CP: LongWord;
  B: Byte;
begin
  Result := S;
  if not NameConv or not HasHigh(S) then
    Exit;
  Result := '';
  I := 1;
  while I <= Length(S) do
  begin
    if Byte(S[I]) < $80 then
    begin
      Result := Result + S[I];
      Inc(I);
      Continue;
    end;
    if not Utf8Decode(@S[I], Length(S) - I + 1, CP, Used) then
      Exit(S);
    B := CpFromUnicode(CP);
    if B = 0 then
      Exit(S);
    Result := Result + Chr(B);
    Inc(I, Used);
  end;
end;

function NameToOs(const S: string): string;
var
  I, J, N: Integer;
  Buf: array[0..7] of Byte;
begin
  Result := S;
  if not NameConv or not HasHigh(S) then
    Exit;
  Result := '';
  for I := 1 to Length(S) do
    if Byte(S[I]) < $80 then
      Result := Result + S[I]
    else
    begin
      N := Utf8Encode(CpToUnicode(Byte(S[I])), @Buf[0]);
      for J := 0 to N - 1 do
        Result := Result + Chr(Buf[J]);
    end;
end;

{ the case of the names of the path that exist is found by listing the directories }
function ResolveCase(const P: string): string;
var
  I, Start: Integer;
  Base, Comp, Cand, Dir: string;
  SR: SysUtils.TSearchRec;
  Found: Boolean;
begin
  if (P = '') or PathExists(P) then
    Exit(P);
  Base := '';
  I := 1;
  if P[1] = '/' then
  begin
    Base := '/';
    I := 2;
  end;
  while I <= Length(P) do
  begin
    Start := I;
    while (I <= Length(P)) and (P[I] <> '/') do
      Inc(I);
    Comp := Copy(P, Start, I - Start);
    if Comp = '' then
    begin
      Inc(I);
      Continue;
    end;
    Cand := Base + Comp;
    if not PathExists(Cand) then
    begin
      Dir := Base;
      if Dir = '' then
        Dir := '.';
      Found := False;
      if SysUtils.FindFirst(IncludeTrailingPathDelimiter(Dir) + '*', faAnyFile, SR) = 0 then
      begin
        repeat
          if SameText(SR.Name, Comp) then
          begin
            Cand := Base + SR.Name;
            Found := True;
            Break;
          end;
        until SysUtils.FindNext(SR) <> 0;
        SysUtils.FindClose(SR);
      end;
      if not Found then
        Exit(Base + Copy(P, Start, MaxInt));       { it does not exist: as it is }
    end;
    Base := Cand;
    if I <= Length(P) then
    begin
      Base := Base + '/';
      Inc(I);
    end;
  end;
  Result := Base;
end;

function SysOsPath(const S: string): string;
var
  I: Integer;
  Raw: string;
begin
  Result := S;
  if (Length(Result) >= 2) and (Result[2] = ':') and (UpCase(Result[1]) in ['A'..'Z']) then
  begin
    Delete(Result, 1, 2);
    if Result = '' then
      Result := '.';
  end;
  for I := 1 to Length(Result) do
    if Result[I] = '\' then
      Result[I] := '/';
  if NameConv and HasHigh(Result) then
  begin
    Raw := Result;
    Result := ResolveCase(NameToOs(Raw));
    if not PathExists(Result) and PathExists(ResolveCase(Raw)) then
      Result := ResolveCase(Raw);          { a file whose name is not in the page of DN: its bytes }
    Exit;
  end;
  Result := ResolveCase(Result);
end;

function SysNameToOs(const S: string): string;
begin
  Result := NameToOs(S);
end;

function SysRunShell(const CmdLine: string): LongInt;
begin
  UnixSuspend;
  Writeln;
  Writeln('$ ', NameToOs(CmdLine));
  Flush(Output);
  Result := fpSystem(NameToOs(CmdLine));
  if UnixActive then
  begin
    Writeln;
    Write('[DN] Press Enter to return...');
    Flush(Output);
    Readln;
  end;
  UnixResume;
end;

procedure SysGetDirDos(D: Byte; var S: string);
var
  I: Integer;
begin
  S := NameFromOs(GetCurrentDir);
  for I := 1 to Length(S) do
    if S[I] = '/' then
      S[I] := '\';
  if S = '' then
    S := '\';
  S := 'C:' + S;
end;
{$ELSE}
function SysOsPath(const S: string): string;
begin
  Result := S;
end;

function SysNameToOs(const S: string): string;
begin
  Result := S;
end;

function SysRunShell(const CmdLine: string): LongInt;
{$IFDEF WINDOWS}
begin
  UnixSuspend;
  Writeln;
  Writeln('> ', CmdLine);
  Flush(Output);
  try
    Result := ExecuteProcess(GetEnvironmentVariable('COMSPEC'), '/c ' + CmdLine);
  except
    Result := -1;
  end;
  if UnixActive then
  begin
    Writeln;
    Write('[DN] Press Enter to return...');
    Flush(Output);
    Readln;
  end;
  UnixResume;
  if Result > 0 then
    Result := Result shl 8;        { as the status of waitpid on Unix: the exit code is in the second byte }
end;
{$ELSE}
begin
  Result := -1;
end;
{$ENDIF}

procedure SysGetDirDos(D: Byte; var S: string);
begin
  GetDir(D, S);
end;
{$ENDIF}

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
  H := FileOpen(SysOsPath(StrPas(FileName)), M or fmShareDenyNone);
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
  H := FileCreate(SysOsPath(StrPas(FileName)));
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
{$IF DEFINED(UNIX) OR DEFINED(WINDOWS)}
  UnixFlush;                 { DN writes the screen and goes on working (a long loop): the terminal gets it now }
{$ENDIF}
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
{$IFDEF UNIX}
  N := NameFromOs(N);
{$ENDIF}
  F.Attr := Byte(R.Attr);
  if R.Attr and faSymLink <> 0 then
    F.Attr := F.Attr or SysLinkAttr;
  F.Time := R.Time;
  F.Size := R.Size;
  F.Name := N;
  F.Name[Length(N) + 1] := #0;
end;

{ the DOS mask "*.*" is every file (on Unix it would be the files with a dot in the name) }
function FixMask(const P: string): string;
begin
  Result := P;
{$IFDEF UNIX}
  if (Length(P) >= 3) and (Copy(P, Length(P) - 2, 3) = '*.*') and ((Length(P) = 3) or (P[Length(P) - 3] = '/')) then
    Result := Copy(P, 1, Length(P) - 2);
{$ENDIF}
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
  if SysUtils.FindFirst(FixMask(SysOsPath(StrPas(Path))), Attr or faSymLink, Searches[I]^) <> 0 then
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
{$IF DEFINED(GO32V2) OR DEFINED(WINDOWS)}
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

procedure SysDiskReset;
{$IFDEF GO32V2}
var
  R: Registers;
begin
  FillChar(R, SizeOf(R), 0);
  R.AH := $0D;
  Intr($21, R);
end;
{$ELSE}
begin
end;
{$ENDIF}

procedure SysTrace(const Msg: String);
begin
  DNTrace(Msg);
end;

var
  KeyIsPending: Boolean = False;
  PendingKey: TEvent;

var
  AutoKeyStart: QWord = 0;
  AutoKeyDone: Boolean = False;

function SysKeyPressed: Boolean;
var
  E: TEvent;
begin
  { a test aid: with DNDUMP set the "press any key" of the fatal error screen of DN is answered after 3 seconds, so that the
    program ends and its files are closed (DOS keeps the data of a file that is not closed only in memory) }
  if (not KeyIsPending) and (not AutoKeyDone) and (GetEnvironmentVariable('DNDUMP') <> '') then
  begin
    if AutoKeyStart = 0 then
      AutoKeyStart := GetTickCount64;
    if GetTickCount64 - AutoKeyStart > 3000 then
    begin
      FillChar(PendingKey, SizeOf(PendingKey), 0);
      PendingKey.What := evKeyDown;
      PendingKey.CharCode := 13;
      KeyIsPending := True;
      AutoKeyDone := True;
    end;
  end;
  if not KeyIsPending then
  begin
    TvSys.PollEvent(0, E);
    if E.What = evKeyDown then
    begin
      PendingKey := E;
      KeyIsPending := True;
    end;
  end;
  Result := KeyIsPending;
end;

function SysReadKey: Char;
begin
  while not SysKeyPressed do
    SysCtrlSleep(20);
  KeyIsPending := False;
  Result := Chr(PendingKey.CharCode);
end;

function GetLocationInfo(Addr: Pointer; var FileName: ShortString; var LineNo: LongInt): Pointer;
var
  Func: ShortString;
begin
  FileName := '';
  LineNo := 0;
  Result := nil;
  Func := ShortString(BackTraceStrFunc(Addr));       { '  $0001FF3  ROUTINE,  line 12 of file.pas' }
  if (Func <> '') and (Pos('line', Func) > 0) then
  begin
    FileName := Func;
    LineNo := 0;
    Result := Addr;
  end;
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
{$IF DEFINED(UNIX) OR DEFINED(WINDOWS)}
var
  R: LongInt;
{$ENDIF}
begin
{$IF DEFINED(UNIX) OR DEFINED(WINDOWS)}
  { through the shell, with the terminal: the program may write to it and read from it }
  R := SysRunShell('"' + StrPas(Path) + '" ' + StrPas(Args));
  Result := 0;
  if (R < 0) or ((R shr 8) = 127) or (R = 9009) then
    Result := 2;                   { the shell could not run it: DOS "file not found" }
{$ELSE}
  Dos.DosError := 0;
  Dos.Exec(StrPas(Path), StrPas(Args));
  Result := Dos.DosError;          { 0 = the program was run; its exit code is Dos.DosExitCode }
{$ENDIF}
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

{ The program takes over the screen at the start (DN reads the size of the screen before it creates the application; the
  application of TV needs the screen of TvScreen to be there). Other targets: their backends do the same. }
{$IFDEF GO32V2}
procedure GrabStartScreen;
var
  Rows: Byte;
  Cols: Word;
begin
  dosmemget($40, $84, Rows, 1);
  dosmemget($40, $4A, Cols, 2);
  Inc(Rows);
  if (Cols = 0) or (Cols > 255) or (Rows < 2) or (Rows > 100) then
    Exit;
  SetLength(SysStartScreen, Cols * Rows);
  dosmemget($B800, 0, SysStartScreen[0], Cols * Rows * 2);
  SysStartScreenWidth := Cols;
end;

initialization
  GrabStartScreen;
  DosInit;
finalization
  DosDone;
{$ENDIF}
{$IF DEFINED(UNIX) OR DEFINED(WINDOWS)}
initialization
{$IFDEF UNIX}
  OnFileName := @SysOsPath;
  NameConv := GetEnvironmentVariable('DN_NAME_CONV') <> '0';
{$ENDIF}
  UnixInit;                        { False when the program has no terminal (the resource compiler): no screen then }
finalization
  UnixDone;
{$ENDIF}

end.
