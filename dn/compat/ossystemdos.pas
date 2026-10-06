{ OSSystemDos: the small calls of the system (devices, volume label, disk buffers, the speaker, memory) on DOS (the backend of the facade OSSystem).
  Moved from OSDep (platform separation, stage 3): the code is the same, only the place is new.
  MIT (see LICENSE). }
unit OSSystemDos;

{$mode objfpc}
{$H-}

interface

{ 0 if the handle is a file; else the device information word (low byte) of DOS. }
function BackendFileIsDevice(Handle: THandle): LongInt;
{ The label of the volume of the drive ('' if there is none). }
function BackendVolumeLabel(Drive: Char): ShortString;
{ The disk buffers go to the disks. }
procedure BackendDiskReset;
procedure BackendBeep(Frequency, Duration: LongInt);
{ Bytes of memory that can be used for buffers. }
function BackendMemAvail: LongInt;

implementation

uses
  SysUtils, Dos, go32;

function BackendFileIsDevice(Handle: THandle): LongInt;
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

function BackendVolumeLabel(Drive: Char): ShortString;
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

procedure BackendDiskReset;
var
  R: Registers;
begin
  FillChar(R, SizeOf(R), 0);
  R.AH := $0D;
  Intr($21, R);
end;

procedure BackendBeep(Frequency, Duration: LongInt);
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

function BackendMemAvail: LongInt;
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

end.
