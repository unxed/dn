{ Tests of dn/new/country_.pas }
{$mode objfpc}{$H-}
program t_countr;
uses SysUtils, Country_;
{$I dntest.inc}
var
  Saved: TCountryInfo;
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
  Finish;
end.
