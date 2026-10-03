{ Tests of dn/compat/use16.pas (16-bit Integer and Word as in Turbo Pascal) }
{$mode objfpc}{$H-}
program t_use16;
uses Use16;
{$I dntest.inc}
var
  I: Integer;
begin
  Check(SizeOf(Integer) = 2, 'Use16: Integer is 16-bit');
  I := 32767;
  Inc(I);
  Check(I < 0, 'Use16: Integer wraps at 16 bits');
  Check(SizeOf(Word) = 2, 'Use16: Word is 16-bit');
  Finish;
end.
