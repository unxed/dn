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
  Check(UpCaseArray[B(#$0454)] = B(#$0404), 'U+0454 is made U+0404');
  Check(UpCaseArray[B(#$0491)] = B(#$0490), 'U+0491 is made U+0490');
  Check(UpCaseArray[B(#$0456)] = B(#$0406), 'U+0456 is made U+0406');
  Check(UpCaseArray[B(#$0457)] = B(#$0407), 'U+0457 is made U+0407');
  Check(UpCaseArray[B(#$0430)] = B(#$0410), 'U+0430 is made U+0410');
  Check(LowCaseArray[B(#$0404)] = B(#$0454), 'U+0404 is made U+0454');
  Check(LowCaseArray[B(#$0490)] = B(#$0491), 'U+0490 is made U+0491');
  Check(UpCaseArray['a'] = 'A', 'ASCII is as it was');
  Check(UpCaseArray[B(#$0410)] = B(#$0410), 'a capital stays');
  Finish;
end.
