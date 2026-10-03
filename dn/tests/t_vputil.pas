{ Tests of dn/new/vputils.pas and use16.pas }
{$mode objfpc}{$H-}
program t_vputil;
uses VPUtils, Math, Use16;
{$I dntest.inc}
var
  I: Integer;
  T1, T2: LongInt;
begin
  Check((Min(3, 5) = 3) and (Max(3, 5) = 5) and (Min(-1, -2) = -2), 'Min and Max');
  Check(Int2Hex($1F, 4) = '001F', 'Int2Hex pads with zeros');
  Check(Int2Hex(-1, 2) = 'FFFFFFFF', 'Int2Hex of a negative number');
  T1 := GetTimeMSec;
  T2 := GetTimeMSec;
  Check(T2 - T1 >= 0, 'GetTimeMSec does not go back');
  Check(GetVolumeLabel('Z') = '', 'no label of a drive that is not there');
  Check(SizeOf(Integer) = 2, 'Use16: Integer is 16-bit');
  I := 32767;
  Inc(I);
  Check(I < 0, 'Use16: Integer wraps at 16 bits');
  Check(SizeOf(Word) = 2, 'Use16: Word is 16-bit');
  Finish;
end.
