{ Country_: the country settings that DN uses to show dates, times and numbers (our unit: the VP one is
  not available). The record has the fields that DN reads; the values come from the settings of the system
  as the RTL of FPC knows them (on DOS the RTL asks INT 21h AX=3800h). }
{$mode objfpc}{$H-}
unit Country_;

interface

type
  TCountryInfo = record
    DateFmt: Byte;                 { 0 month-day-year, 1 day-month-year, 2 year-month-day }
    Currency: String[7];
    ThouSep: String[3];
    DecSep: String[3];
    DateSep: String[3];
    TimeSep: String[3];
    CurrencyFmt: Byte;             { 0 $1, 1 1$, 2 $ 1, 3 1 $, 4 the symbol replaces the decimal sign }
    DecSign: String[1];            { the number of digits after the decimal sign, as a character }
    TimeFmt: Byte;                 { 0 12 hours, 1 24 hours }
  end;

var
  CountryInfo: TCountryInfo;

{ Reads the settings of the system again. }
procedure InitCountryInfo;

implementation

uses SysUtils;

function FirstDateField(const Fmt: string): Byte;
var
  I: Integer;
begin
  Result := 1;                     { day first unless it is month or year }
  for I := 1 to Length(Fmt) do
    case UpCase(Fmt[I]) of
      'M': Exit(0);
      'D': Exit(1);
      'Y': Exit(2);
    end;
end;

procedure InitCountryInfo;
begin
  with CountryInfo, DefaultFormatSettings do
  begin
    DateFmt := FirstDateField(ShortDateFormat);
    Currency := Copy(CurrencyString, 1, 7);
    if ThousandSeparator = #0 then
      ThouSep := ''
    else
      ThouSep := ThousandSeparator;
    DecSep := DecimalSeparator;
    DateSep := DateSeparator;
    TimeSep := TimeSeparator;
    CurrencyFmt := CurrencyFormat;
    if CurrencyFmt > 3 then
      CurrencyFmt := 0;
    if CurrencyDecimals in [0..9] then
      DecSign := Chr(Ord('0') + CurrencyDecimals)
    else
      DecSign := '2';
    if Pos('AM', UpperCase(ShortTimeFormat)) > 0 then
      TimeFmt := 0
    else
      TimeFmt := 1;
  end;
end;

initialization
  InitCountryInfo;
end.
