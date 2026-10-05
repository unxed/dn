{ OSDiskUnix: the single host disk exposed to DN as drive C:. }
unit OSDiskUnix;

{$mode objfpc}
{$H-}

interface

function BackendDiskFree(Drive: Byte): Int64;
function BackendDiskSize(Drive: Byte): Int64;
function BackendValidDiskMap: LongWord;

implementation

uses
  Dos;

function BackendDiskFree(Drive: Byte): Int64;
begin
  Result := DiskFree(Drive);
end;

function BackendDiskSize(Drive: Byte): Int64;
begin
  Result := DiskSize(Drive);
end;

function BackendValidDiskMap: LongWord;
begin
  Result := 1 shl 2;
end;

end.
