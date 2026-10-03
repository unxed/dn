{ Tests of DNUtf8 (the proxy of UTF-8 names): tools/dn-test.sh }
{$mode objfpc}{$H-}
program t_dnutf8;
uses DNUtf8;
{$I dntest.inc}

var
  Tab, P: String;
begin
  Check(Utf8Chars('abc') = 3, 'chars: ASCII');
  Check(Utf8Chars('Каталог') = 7, 'chars: 7 Cyrillic letters are 14 bytes');
  Check(Utf8Chars(#$D0) = 1, 'chars: a stray byte is one character');

  P := Utf8ToProxy('abc', Tab);
  Check((P = 'abc') and (Tab = ''), 'proxy: ASCII stays as it is');

  P := Utf8ToProxy('Каталог', Tab);
  Check(Length(P) = 7, 'proxy: one byte for each character');
  Check(Byte(P[1]) >= $80, 'proxy: the byte is not ASCII');
  Check(ProxyToUtf8(P, Tab) = 'Каталог', 'proxy: and back');

  P := Utf8ToProxy('аба.txt', Tab);
  Check((P[1] = P[3]) and (P[1] <> P[2]), 'proxy: the same character, the same byte');
  Check(Copy(P, 4, 4) = '.txt', 'proxy: the ASCII part is kept');

  { the algorithm of DN works on the proxy (here: a cut to 3 columns), the result goes back }
  P := Utf8ToProxy('Каталог', Tab);
  Check(ProxyToUtf8(Copy(P, 1, 3), Tab) = 'Кат', 'cut by columns: no half of a character');

  P := Utf8ToProxy('a' + #$FF + 'b', Tab);
  Check(ProxyToUtf8(P, Tab) = 'a' + #$FF + 'b', 'a byte that is not UTF-8 is kept');

  P := Utf8ToProxy('日本語', Tab);
  Check((Length(P) = 3) and (ProxyToUtf8(P, Tab) = '日本語'), 'proxy: 3-byte characters');

  { the case }
  P := 'Привет, Мир! abc ЁЖ';
  Utf8UpStr(P);
  Check(P = 'ПРИВЕТ, МИР! ABC ЁЖ', 'up: Cyrillic and ASCII: ' + P);
  Utf8LowStr(P);
  Check(P = 'привет, мир! abc ёж', 'low: Cyrillic, Yo, ASCII: ' + P);
  P := 'ÄÖÜ äöü Ωω';
  Utf8UpStr(P);
  Check(P = 'ÄÖÜ ÄÖÜ ΩΩ', 'up: Latin-1 and Greek: ' + P);
  P := 'a' + #$FF + 'z';
  Utf8UpStr(P);
  Check(P = 'A' + #$FF + 'Z', 'a byte that is not UTF-8 stays');
  Check((CpUpper($44F) = $42F) and (CpLower($42F) = $44F) and (CpUpper($451) = $401), 'the code points: ya, yo');
  Check(CpUpper($3C2) = $3A3, 'the final sigma');
  Check(CpUpper($D7) = $D7, 'the sign of multiplication has no case');

  Finish;
end.
