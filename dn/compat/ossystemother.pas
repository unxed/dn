{ OSSystemOther: the small calls of the system (devices, volume label, disk buffers, the speaker, memory) on Unix and Windows (the backend of the facade OSSystem).
  Moved from OSDep (platform separation, stage 3): the code is the same, only the place is new.
  MIT, see LICENSE. }
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
function BackendConfigDir: string;
function BackendDescribe: string;
function BackendHasShortNames: Boolean;
function BackendMemAvail: LongInt;

implementation

uses
  SysUtils;

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
  Result := {$IFDEF UNIX}'/tmp/'{$ELSE}''{$ENDIF};
end;

function BackendConfigDir: string;
var
  Base: string;
begin
{$IFDEF UNIX}
  Base := GetEnvironmentVariable('XDG_CONFIG_HOME');
  if (Base = '') or (Base[1] <> '/') then
  begin
    Base := GetEnvironmentVariable('HOME');
    if Base = '' then
      Exit('');
    Base := Base + '/.config';
  end;
  Result := Base + '/dn/';
{$ELSE}
  Base := GetEnvironmentVariable('APPDATA');
  if Base = '' then
    Exit('');
  Result := Base + '\DN\';
{$ENDIF}
end;

function BackendHasShortNames: Boolean;
begin
{$IFDEF UNIX}
  Result := False;
{$ELSE}
  Result := True;
{$ENDIF}
end;

function BackendDescribe: string;
{$IFDEF UNIX}
  function FirstLine(const Name: string): string;
  var
    T: TextFile;
  begin
    Result := '';
    if not FileExists(Name) then
      Exit;
    {$I-}
    Assign(T, Name);
    Reset(T);
    if IOResult = 0 then
    begin
      Readln(T, Result);
      Close(T);
    end;
    {$I+}
  end;
{$ENDIF}
begin
{$IFDEF UNIX}
  Result := Trim(FirstLine('/proc/sys/kernel/ostype') + ' ' + FirstLine('/proc/sys/kernel/osrelease'));
  if Result = '' then
    Result := 'Unix';
{$ELSE}
  Result := 'Windows ' + IntToStr(Win32MajorVersion) + '.' + IntToStr(Win32MinorVersion) + ' build ' + IntToStr(Win32BuildNumber);
{$ENDIF}
end;

function BackendMemAvail: LongInt;
begin
  Result := 256 * 1024 * 1024;
end;

end.
