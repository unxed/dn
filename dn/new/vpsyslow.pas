{ VPSysLow: the system layer that DN OSP takes from the runtime library of Virtual Pascal, written anew
  for Free Pascal. It replaces vpsyslow.pas of the archive (code of vpascal.com, see dn/exclude.list).

  License of DN (see dn/README.md). The names and the way they are called
  come from the call sites in DN (spec/vp-api-vpsyslow.md, tools/vp-api.py).

  Done here: the types, the open mode constants, the file, disk and system functions that DN calls on
  the DOS target (DPMI32). The screen, keyboard and mouse functions (SysTv*, SysSetVideoMode) are not
  here: in DN they serve its own drivers.pas and videoman.pas, which have to be fitted to our TV (tv/)
  (PLAN.md, milestone 4). }
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

{ --- files -------------------------------------------------------------------- }
{ 0 when done, else the error code of the system }
function SysFileClose(Handle: THandle): LongInt;
function SysFileSetSize(Handle: THandle; Size: TFileSize): LongInt;
{ nonzero (the low byte) when the handle is a device (a terminal, a printer...), 0 for a file }
function SysFileIsDevice(Handle: THandle): LongInt;

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
  SysUtils, Dos
{$IFDEF GO32V2}, go32{$ENDIF};

{ --- files -------------------------------------------------------------------- }

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
