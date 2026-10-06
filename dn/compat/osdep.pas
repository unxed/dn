{ osdep: the system layer that DN OSP takes from the runtime library of Virtual Pascal, written anew
  for Free Pascal. It replaces osdep.pas of the archive (code of vpascal.com, see dn/exclude.list).

  MIT (see LICENSE). The names and the way they are called
  come from the call sites in DN (spec/vp-api-osdep.md, tools/vp-api.py).

  Done here: the types, the open mode constants, the file, disk and system functions that DN calls on
  the DOS target (DPMI32). The screen glue is in dnscreen.pas; the keyboard and the mouse are done by tv/ (TvSys). }
unit osdep;

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

{ --- files -------------------------------------------------------------------- }
{ The result is 0 when done, else the error code of the system (DOS codes: 2 no such file, 3 no such
  path, 5 access denied...). }
function SysFileOpen(FileName: PChar; Mode: LongInt; var Handle: LongInt): LongInt;
function SysFileCreate(FileName: PChar; Mode, Attr: LongInt; var Handle: LongInt): LongInt;
{ Method: 0 from the beginning, 1 from the current position, 2 from the end. }
function SysFileSeek(Handle: THandle; Distance, Method: LongInt; var Actual: LongInt): LongInt;
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
{ Convert a DN command line to the host shell's encoding and path syntax. }
function SysCommandLineToOs(const S: string): string;
{ Unix: runs a command of the shell with the terminal (the screen of the application is left, the command writes to the terminal, Enter
  returns to DN and the screen is drawn again); returns the exit code of the shell. Elsewhere: -1 (nothing is run). }
function SysRunShell(const CmdLine: string): LongInt;
{ Replaces the current process with DN and its original arguments, or starts a new DN process on other targets. }
procedure SysRestartSelf;
{ GetDir for DN: the current directory as "C:\DIR" (on Unix: C: is the root). }
procedure SysGetDirDos(D: Byte; var S: string);

{ --- searching a directory ---------------------------------------------------- }
type
  { The record of a search. The state of
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
    CreationTime: LongInt;       { DOS date and time; 0 when the system does not tell }
    LastAccessTime: LongInt;
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
{ The disk buffers go to the disks (DOS INT 21h AH=0Dh); elsewhere: nothing. }
procedure SysDiskReset;
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

implementation

uses
  SysUtils, Dos, OSDisk, OSRun, OSSystem, TvCell, TvColors, TvScreen, TvEvents, TvSys, TvObjs, TvCodePg, TvUtf8, DNErrLog, LineInfo
{$IFDEF GO32V2}, go32, TvDos, OSNamesDos, OSStartScreen{$ENDIF}   { OSStartScreen: its initialization (the grab of the screen) must come before DosInit below }
{$IFDEF UNIX}, BaseUnix, Unix, OSNamesUnix{$ENDIF}
{$IF DEFINED(UNIX) OR DEFINED(WINDOWS)}, TvUnix{$ENDIF};

{ --- names of files ----------------------------------------------------------- }

{$IFDEF UNIX}

function SysOsPath(const S: string): string;
begin
  Result := OsPath(S);
end;

function SysNameToOs(const S: string): string;
begin
  Result := NameToOs(S);
end;

function SysCommandLineToOs(const S: string): string;
begin
  Result := CommandLineToOs(S);
end;

function SysRunShell(const CmdLine: string): LongInt;
begin
  Result := RunShell(CmdLine);
end;

procedure SysRestartSelf;
begin
  RestartSelf;
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
{$IF DEFINED(GO32V2) AND NOT DEFINED(DNUTF8)}
  Result := DosNameToUtf8(S);
{$ELSE}
  Result := S;
{$ENDIF}
end;

function SysNameToOs(const S: string): string;
begin
{$IF DEFINED(GO32V2) AND NOT DEFINED(DNUTF8)}
  Result := DosNameToUtf8(S);
{$ELSE}
  Result := S;
{$ENDIF}
end;

function SysCommandLineToOs(const S: string): string;
begin
  Result := S;
end;

function SysRunShell(const CmdLine: string): LongInt;
begin
  Result := RunShell(CmdLine);
end;

procedure SysRestartSelf;
begin
  RestartSelf;
end;

procedure SysGetDirDos(D: Byte; var S: string);
begin
  GetDir(D, S);
{$IF DEFINED(GO32V2) AND NOT DEFINED(DNUTF8)}
  S := DosNameFromUtf8(S);
{$ENDIF}
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
begin
  Result := OSFileIsDevice(Handle);
end;

function SysGetVolumeLabel(Drive: Char): ShortString;
begin
  Result := OSVolumeLabel(Drive);
end;

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
{$IF DEFINED(GO32V2) AND NOT DEFINED(DNUTF8)}
  N := DosNameFromUtf8(N);
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
  Mask, Dir: string;
begin
  I := 1;
  while (I <= MaxSearches) and (Searches[I] <> nil) do
    Inc(I);
  if I > MaxSearches then
    Exit(4);                       { too many open files }
  New(Searches[I]);
  Mask := FixMask(SysOsPath(StrPas(Path)));
  if SysUtils.FindFirst(Mask, Attr or faSymLink, Searches[I]^) <> 0 then
  begin
    SysUtils.FindClose(Searches[I]^);
    Dispose(Searches[I]);
    Searches[I] := nil;
    F.Handle := 0;
    { DOS tells "path not found" (3) from "no more files" (18): PathExist of DN takes any of 0, 2, 18 of a probe of DIR\*.* as "the directory exists" }
    Dir := ExtractFileDir(Mask);
    if Dir = '' then
      Dir := '.';
    if not DirectoryExists(Dir) then
      Exit(3);
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

function SysDiskFreeLongX(Path: PChar): TQuad;
begin
  Result := OSDisk.DiskFreeByPath(Path);
end;

function SysDiskSizeLongX(Path: PChar): TQuad;
begin
  Result := OSDisk.DiskSizeByPath(Path);
end;

function SysDiskFreeLong(Drive: Byte): TQuad;
begin
  Result := OSDisk.DiskFreeByNumber(Drive);
end;

function SysGetValidDrives: LongWord;
begin
  Result := OSDisk.ValidDiskMap;
end;

{ --- the system --------------------------------------------------------------- }

procedure SysDiskReset;
begin
  OSDiskReset;
end;

procedure SysBeepEx(Frequency, Duration: LongInt);
begin
  OSBeep(Frequency, Duration);
end;

function PhysMemAvail: LongInt;
begin
  Result := OSMemAvail;
end;

function SysExecute(Path, Args, Env: PChar; Async: Boolean; ReportPid: Pointer;
  StdIn, StdOut, StdErr: LongInt): LongInt;
begin
  Result := Execute(Path, Args);
end;

{$IFDEF GO32V2}
initialization
  DosInit;
  DosNamesInit;
finalization
  DosDone;
{$ENDIF}
{$IF DEFINED(UNIX) OR DEFINED(WINDOWS)}
initialization
{$IF DEFINED(WINDOWS) AND DEFINED(DNUTF8)}
  { the names of the files are UTF-8 strings inside DN: the RTL turns them into UTF-16 for the wide API of Windows (not the ANSI page) }
  SetMultiByteConversionCodePage(CP_UTF8);
  SetMultiByteFileSystemCodePage(CP_UTF8);
  SetMultiByteRTLFileSystemCodePage(CP_UTF8);
{$ENDIF}
{$IFDEF UNIX}
  OnFileName := @SysOsPath;
{$IFDEF DNUTF8}
  NameConv := False;               { the names are UTF-8 inside DN: no conversion at the border }
{$ELSE}
  NameConv := GetEnvironmentVariable('DN_NAME_CONV') <> '0';
{$ENDIF}
{$ENDIF}
  UnixInit;                        { False when the program has no terminal (the resource compiler): no screen then }
finalization
  UnixDone;
{$ENDIF}

end.
