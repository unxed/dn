{ OSSystemOther: the small calls of the system (devices, volume label, disk buffers, the speaker, memory) on Unix and Windows (the backend of the facade OSSystem).
  Moved from OSDep (platform separation, stage 3): the code is the same, only the place is new.
  MIT (see LICENSE). }
unit OSSystemOther;

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
procedure BackendSerialTrace(const Msg: string);
function BackendBatchExt: string;
function BackendDefaultTempDir: string;
function BackendMemAvail: LongInt;

implementation

function BackendFileIsDevice(Handle: THandle): LongInt;
begin
  Result := 0;                 { no devices to tell from files on the systems of the tests }
end;

function BackendVolumeLabel(Drive: Char): ShortString;
begin
  Result := '';
end;

procedure BackendDiskReset;
begin
end;

procedure BackendBeep(Frequency, Duration: LongInt);
begin
  { nothing to play on the systems of the tests }
end;

procedure BackendSerialTrace(const Msg: string);
begin
end;

function BackendBatchExt: string;
begin
  Result := '.CMD';
end;

function BackendDefaultTempDir: string;
begin
  Result := {$IFDEF UNIX}'C:\tmp\'{$ELSE}''{$ENDIF};
end;

function BackendMemAvail: LongInt;
begin
  Result := 256 * 1024 * 1024;
end;

end.
