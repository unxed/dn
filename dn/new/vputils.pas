{ VPUtils: the small helpers of the Virtual Pascal RTL that DN calls (our unit; the VP one is not available).
  Written from the use of the names in the sources of DN; TODO: more names as the units of DN compile. }
{$mode objfpc}{$H-}
unit VPUtils;

interface

{ The hexadecimal text of Value, with at least Digits digits (zeros in front). }
function Int2Hex(Value: LongInt; Digits: Integer): String;

implementation

uses SysUtils;

function Int2Hex(Value: LongInt; Digits: Integer): String;
begin
  Result := IntToHex(Cardinal(Value), Digits);
end;

end.
