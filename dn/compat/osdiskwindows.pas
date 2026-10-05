{ OSDiskWindows: disk queries for Windows drive-letter volumes. }
unit OSDiskWindows;

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
var
  I: Integer;
begin
  Result := 0;
  for I := 1 to 26 do
    if DiskSize(I) <> -1 then
      Result := Result or (LongWord(1) shl (I - 1));
end;

end.
