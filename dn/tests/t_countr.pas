{ Tests of dn/new/country_.pas }
{$mode objfpc}{$H-}
program t_countr;
uses SysUtils, Country_, TvCodePg;
{$I dntest.inc}
var
  Saved: TCountryInfo;
  Up, Tr: array[0..255] of Char;
begin
  Check(CountryInfo.DateFmt in [0..2], 'the format of the date is 0..2');
  Check(CountryInfo.TimeFmt in [0..1], 'the format of the time is 0..1');
  Check(Length(CountryInfo.DateSep) >= 1, 'there is a separator of the date');
  Check(Length(CountryInfo.TimeSep) >= 1, 'there is a separator of the time');
  Check((CountryInfo.DecSign >= '0') and (CountryInfo.DecSign <= '9'), 'DecSign is a digit');
  { the record is copied as a whole (DN keeps and restores it) }
  Saved := CountryInfo;
  CountryInfo.DateSep := '-';
  CountryInfo := Saved;
  Check(CountryInfo.DateSep = Saved.DateSep, 'the record can be saved and restored');
  InitCountryInfo;
  Check(CountryInfo.DateSep = Saved.DateSep, 'InitCountryInfo gives the same settings again');
  { the upper case table of the screen code page }
  Check(CpSelect(866), 'select the page 866');
  QueryUpcaseTable(Up);
  Check((Up[Ord('a')] = 'A') and (Up[Ord('A')] = 'A'), 'upper case of ASCII letters');
  Check(Up[$A0] = Chr($80), 'cp866: Cyrillic a -> A');
  Check(Up[$E0] = Chr($90), 'cp866: Cyrillic r -> R (the second row)');
  Check(Up[$B0] = Chr($B0), 'cp866: a pseudographic character stays');
  Check(CpSelect(437), 'select the page 437');
  QueryUpcaseTable(Up);
  Check((Up[$84] = Chr($8E)) and (Up[$87] = Chr($80)), 'cp437: a-umlaut, c-cedilla');
  { the conversion table: the page 866 to the screen page 437 keeps the ASCII and maps the letters it can }
  Check(QueryToAscii(866, Tr), 'QueryToAscii knows 866');
  Check(Tr[Ord('x')] = 'x', 'ASCII stays');
  Check(not QueryToAscii(1251, Tr), 'a Windows page is not known (TODO)');
  Check(Tr[$41] = Chr($41), 'the table is the identity then');
  CpSelect(866);
  Finish;
end.
