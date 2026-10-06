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
{ The extension of the files that DN writes for a command interpreter (the swap batch files, the list of files): .BAT on DOS, .CMD elsewhere. }
function OSBatchExt: string;
{ The directory for temporary files when neither DN.INI nor TEMP and TMP name one: C:\tmp\ on Unix (it is /tmp in the DN way of paths), '' elsewhere. }
function OSDefaultTempDir: string;

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

function OSBatchExt: string;
begin
  Result := BackendBatchExt;
end;

function OSDefaultTempDir: string;
begin
  Result := BackendDefaultTempDir;
end;

end.
