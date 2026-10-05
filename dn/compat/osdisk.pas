{ OSDisk: the stable disk-information facade used by the DN compatibility layer. }
unit OSDisk;

{$mode objfpc}
{$H-}

interface

function DiskFreeByPath(Path: PChar): Int64;
function DiskSizeByPath(Path: PChar): Int64;
function DiskFreeByNumber(Drive: Byte): Int64;
function ValidDiskMap: LongWord;

implementation

uses
{$IFDEF GO32V2}
  OSDiskDos;
{$ELSE}
{$IFDEF WINDOWS}
  OSDiskWindows;
{$ELSE}
  OSDiskUnix;
{$ENDIF}
{$ENDIF}

function DriveOfPath(Path: PChar): Byte;
begin
  Result := 0;
  if (Path <> nil) and (Path[0] <> #0) and (Path[1] = ':') then
    if UpCase(Path[0]) in ['A'..'Z'] then
      Result := Ord(UpCase(Path[0])) - Ord('A') + 1;
end;

function DiskFreeByPath(Path: PChar): Int64;
begin
  Result := BackendDiskFree(DriveOfPath(Path));
end;

function DiskSizeByPath(Path: PChar): Int64;
begin
  Result := BackendDiskSize(DriveOfPath(Path));
end;

function DiskFreeByNumber(Drive: Byte): Int64;
begin
  Result := BackendDiskFree(Drive);
end;

function ValidDiskMap: LongWord;
begin
  Result := BackendValidDiskMap;
end;

end.
