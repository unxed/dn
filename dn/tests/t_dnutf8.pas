{ Tests of DNUtf8 (the proxy of UTF-8 names): tools/dn-test.sh }
{$mode objfpc}{$H-}
program t_dnutf8;
uses DNUtf8, TvCodePg;
{$I dntest.inc}

var
  Tab, P: String;
  DT: TDocTab;
  I, K: Integer;
  UpT, LowT, TogT: TCaseTab;
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
  Check((Length(P) = 6) and (ProxyToUtf8(P, Tab) = '日本語'), 'proxy: 3-byte wide characters (two columns each)');

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

  { the table of a document }
  CpSelect(866);
  TabNatural(DT);
  Check((DT.Cp[$A0] = $430) and (DT.Cp[$80] = $410), 'table: the page 866: a is $A0, A is $80');
  Check(TabSee(DT, 'Привет') and TabSee(DT, 'x') and (DT.SeenN = 6), 'table: the characters seen (without repeats)');
  Check(TabSee(DT, 'a' + #$FF + 'b') = False, 'table: not UTF-8 is not a document of UTF-8');
  Check(TabBuild(DT), 'table: built');
  P := TabToInternal(DT, 'Привет', False);
  Check((P = #$8F#$E0#$A8#$A2#$A5#$E2), 'table: the Cyrillic letters have the bytes of the page');
  Check(TabToUtf8(DT, P) = 'Привет', 'table: and back');
  TabNatural(DT);
  TabSee(DT, 'a — b «c»');
  Check(TabBuild(DT), 'table: the characters that the page has not take the cells of frame characters');
  P := TabToInternal(DT, 'a — b «c»', False);
  Check((Length(P) = 9) and (TabToUtf8(DT, P) = 'a — b «c»'), 'table: a text with a dash and quotes goes and comes back');
  P := TabToInternal(DT, 'Привет', False);
  Check(TabToUtf8(DT, P) = 'Привет', 'table: the letters stay where they were');
  P := TabToInternal(DT, 'a…b', False);
  Check(P = 'a?b', 'table: a new character without Alloc is ?');
  P := TabToInternal(DT, 'a…b', True);
  Check((Length(P) = 3) and (P[2] <> '?') and (TabToUtf8(DT, P) = 'a…b'), 'table: with Alloc it takes a free cell');
  TabNatural(DT);
  for I := 0 to 99 do
    TabSee(DT, Chr($D7) + Chr($80 + (I and $3F)) + 'x');
  Check(TabBuild(DT) or DT.Over or True, 'table: many characters do not crash');
  { the columns: a wide character is two bytes of the proxy, a combining mark goes with its character }
  P := Utf8ToProxy('a日b', Tab);
  Check((Length(P) = 4) and (P[1] = 'a') and (P[3] = #$FF) and (P[4] = 'b') and (Byte(P[2]) >= $80), 'proxy: a wide character takes two columns');
  Check(ProxyToUtf8(P, Tab) = 'a日b', 'proxy: and comes back');
  Check(ProxyToUtf8(Copy(P, 1, 2), Tab) = 'a ', 'proxy: a wide character that was cut in the middle is a blank');
  Check(ProxyToUtf8(Copy(P, 3, 2), Tab) = ' b', 'proxy: the second half alone is a blank');
  P := Utf8ToProxy('e' + #$CC#$81 + 'x', Tab);
  Check((Length(P) = 2) and (P[2] = 'x') and (Byte(P[1]) >= $80), 'proxy: a combining mark goes with its letter (one column)');
  Check(ProxyToUtf8(P, Tab) = 'e' + #$CC#$81 + 'x', 'proxy: the letter with its mark comes back');
  P := Utf8ToProxy('日本語', Tab);
  Check((Length(P) = 6) and (ProxyToUtf8(P, Tab) = '日本語'), 'proxy: three wide characters are six columns and come back');
  { the characters that the keyboard gives }
  TabNatural(DT);
  TabSee(DT, 'a│b');
  TabBuild(DT);
  Check(TabTyped(DT, 'п', 7) = $AF, 'typed: a letter of the page has its byte');
  Check(TabTyped(DT, 'x', 7) = 7, 'typed: ASCII stays as it is');
  I := TabTyped(DT, 'α', 0);
  Check((I >= $B0) and (I <> $B3) and (DT.Cp[I] = $3B1), 'typed: Greek alpha takes a free cell (not the cell of the frame character that the text has)');
  Check(TabTyped(DT, 'α', 0) = I, 'typed: and the same cell again');
  Check(TabTyped(DT, '│', 0) = $B3, 'typed: the frame character of the text is its own cell');
  TabMark(DT, $C4);
  for K := 1 to 200 do
    TabTyped(DT, Chr($D7) + Chr($80 + (K and $3F)), 0);
  Check(DT.Cp[$B3] = $2502, 'typed: the cell that the text uses is never given away');
  { the case tables of a document }
  TabNatural(DT);
  TabCase(DT, UpT, LowT, TogT);
  Check((UpT[$A0] = $80) and (LowT[$80] = $A0) and (TogT[$A0] = $80) and (TogT[$80] = $A0), 'case table: a and A of the page 866');
  Check((UpT[Ord('q')] = Ord('Q')) and (LowT[Ord('Q')] = Ord('q')) and (UpT[Ord('1')] = Ord('1')), 'case table: ASCII');
  Check((UpT[$B0] = $B0) and (LowT[$B0] = $B0), 'case table: a frame cell has no case');
  { the scroll bar characters of dn.ini: glyphs in UTF-8 -> the bytes of the page }
  CpSelect(866);
  Check(GlyphsToPage('▲▼▒■▓') = #30#31#177#254#178, 'glyphs: vertical scroll bar characters on cp866');
  Check(GlyphsToPage('◄►▒■▓') = #17#16#177#254#178, 'glyphs: horizontal scroll bar characters on cp866');
  Check(GlyphsToPage(#17#16#177#254#178) = #17#16#177#254#178, 'glyphs: the old form (bytes of a page) is returned as it is');
  Check(GlyphsToPage('日') = '?', 'glyphs: a character that the page lacks is ?');
  Check(GlyphsToPage('a═b') = 'a'#205'b', 'glyphs: ASCII is kept, a frame character is its byte');
  { the beginning of a name that is cut by bytes does not split a character (the 12 bytes of the short name of a file record) }
  Check(Utf8Prefix('abc.txt', 12) = 'abc.txt', 'prefix: a short name is as it is');
{$IFDEF DNUTF8}
  Check(Utf8Prefix('Привет.txt', 12) = 'Привет', 'prefix: twelve bytes are six Cyrillic letters');
  Check(Utf8Prefix('Привет.txt', 11) = 'Приве', 'prefix: eleven bytes: the sixth letter does not fit and is left out whole');
{$ELSE}
  Check(Length(Utf8Prefix('0123456789abcdef', 12)) = 12, 'prefix: bytes are characters');
{$ENDIF}
  Finish;
end.
