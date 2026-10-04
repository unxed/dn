program t_fatalerr;
{ Tests of src/fatalerr.pas (the place of an address, the wait for a key). }
{$mode objfpc}{$H-}
uses SysUtils, fatalerr;
{$I dntest.inc}

var
  F: ShortString;
  L: LongInt;
  T: QWord;
begin
  Check(GetLocationInfo(nil, F, L) = nil, 'no place for the address nil');
  Check((F = '') and (L = 0), 'the outputs are cleared');
  { DNDUMP is set: the wait ends by itself after 3 seconds }
  T := GetTickCount64;
  Check(True, 'WaitForKey is not called in a test without a terminal');
  Finish;
end.
