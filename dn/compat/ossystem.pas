{ OSSystem: the small calls of the system (devices, volume label, disk buffers, the speaker, memory): the stable facade used by the DN compatibility layer
  (osdep). The code of a target is in OSSystemDos or OSSystemOther.
  This unit is our own code (MIT, see LICENSE). }
unit OSSystem;

{$mode objfpc}
{$H-}

interface

{ 0 if the handle is a file; else the device information word (low byte) of DOS. }
function OSFileIsDevice(Handle: THandle): LongInt;
{ The label of the volume of the drive ('' if there is none). }
function OSVolumeLabel(Drive: Char): ShortString;
{ The disk buffers go to the disks (DOS INT 21h AH=0Dh); elsewhere: nothing. }
procedure OSDiskReset;
procedure OSBeep(Frequency, Duration: LongInt);
{ Bytes of memory that can be used for buffers. }
function OSMemAvail: LongInt;
{ DOS: the text and a line end go to the serial port COM1 (a debug trace that survives a program that dies, see DNErrLog); elsewhere: nothing. }
procedure OSSerialTrace(const Msg: string);

implementation

uses
{$IFDEF GO32V2}
  OSSystemDos;
{$ELSE}
  OSSystemOther;
{$ENDIF}

function OSFileIsDevice(Handle: THandle): LongInt;
begin
  Result := BackendFileIsDevice(Handle);
end;

function OSVolumeLabel(Drive: Char): ShortString;
begin
  Result := BackendVolumeLabel(Drive);
end;

procedure OSDiskReset;
begin
  BackendDiskReset;
end;

procedure OSBeep(Frequency, Duration: LongInt);
begin
  BackendBeep(Frequency, Duration);
end;

function OSMemAvail: LongInt;
begin
  Result := BackendMemAvail;
end;

procedure OSSerialTrace(const Msg: string);
begin
  BackendSerialTrace(Msg);
end;

end.
