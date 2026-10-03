program t_locale;
{ TvLocale: the OEM code page of a locale. }
{$I ../src/tvdefs.inc}
uses TvLocale;
{$I testlib.inc}
begin
  Check(LocaleOemCodePage('ru_RU') = 866, 'ru_RU is 866');
  Check(LocaleOemCodePage('ru_RU.UTF-8') = 866, 'the encoding is dropped');
  Check(LocaleOemCodePage('uk_UA.UTF-8') = 866, 'uk_UA is 866');
  Check(LocaleOemCodePage('en_US.UTF-8') = 437, 'en_US is 437');
  Check(LocaleOemCodePage('de_DE.UTF-8') = 850, 'de_DE is 850');
  Check(LocaleOemCodePage('pl_PL') = 852, 'pl_PL is 852');
  Check(LocaleOemCodePage('el_GR') = 737, 'el_GR is 737');
  Check(LocaleOemCodePage('sr_RS@latin') = 852, 'sr_RS@latin is 852');
  Check(LocaleOemCodePage('sr_RS') = 855, 'sr_RS is 855');
  Check(LocaleOemCodePage('sr_RS.UTF-8@latin') = 852, 'the encoding is dropped before the modifier');
  Check(LocaleOemCodePage('ru') = 866, 'a language without the country: the first entry of it');
  Check(LocaleOemCodePage('ja_JP.UTF-8') = 437, 'a multi-byte page: 437');
  Check(LocaleOemCodePage('C') = 0, 'C: nothing');
  Check(LocaleOemCodePage('POSIX') = 0, 'POSIX: nothing');
  Check(LocaleOemCodePage('') = 0, 'empty: nothing');
  Check(LocaleOemCodePage('xx_YY') = 0, 'unknown: nothing');
  Finish;
end.
