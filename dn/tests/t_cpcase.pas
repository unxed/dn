program t_cpcase;
{ DN_TEST: code page build (no -dDNUTF8)
  The case of the letters of the code page 1125 (Ukrainian) in the tables of DN: the OS may not know the page, the letters are added from it (keymap.CompleteUpcaseFromPage). }
{$mode objfpc}{$H-}
uses SysUtils, TvCodePg, strutil, keymap;
{$I dntest.inc}

function B(const U: UnicodeString): Char;
begin
  Result := Chr(CpFromUnicode(Ord(U[1])));
end;

begin
  Check(CpSelect(1125), 'the page 1125 is selected');
  RefreshCaseTables;
  Check(UpCaseArray[B(#$0454)] = B(#$0404), 'є is made Є');
  Check(UpCaseArray[B(#$0491)] = B(#$0490), 'ґ is made Ґ');
  Check(UpCaseArray[B(#$0456)] = B(#$0406), 'і is made І');
  Check(UpCaseArray[B(#$0457)] = B(#$0407), 'ї is made Ї');
  Check(UpCaseArray[B(#$0430)] = B(#$0410), 'а is made А');
  Check(LowCaseArray[B(#$0404)] = B(#$0454), 'Є is made є');
  Check(LowCaseArray[B(#$0490)] = B(#$0491), 'Ґ is made ґ');
  Check(UpCaseArray['a'] = 'A', 'ASCII is as it was');
  Check(UpCaseArray[B(#$0410)] = B(#$0410), 'a capital stays');
  Finish;
end.
