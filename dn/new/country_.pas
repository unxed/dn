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
{ The same, under the name that DN calls. }
procedure GetSysCountryInfo;

{ X[C] is the upper case letter of C in the screen code page (the tables of tv/); C itself if it has no
  upper case. (DOS gives such a table by INT 21h AX=6502h; here it is computed from Unicode, the same on
  every system.) X is an array of 256 characters. }
procedure QueryUpcaseTable(var X: array of Char);
{ X[C] is the character of the screen code page for the character C of the code page CP. False (X is the
  identity) when CP is not one of the DOS pages of tv/. TODO: the Windows pages (1251, 1252...). }
function QueryToAscii(CP: Integer; var X: array of Char): Boolean;

implementation

uses SysUtils, TvCodePg;

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

procedure GetSysCountryInfo;
begin
  InitCountryInfo;
end;

{ Upper case of a Unicode character of the BMP for Latin, Greek and Cyrillic; the character itself otherwise. }
function UpperUnicode(U: LongWord): LongWord;
begin
  Result := U;
  case U of
    $61..$7A: Result := U - 32;
    $B5: Result := $39C;
    $E0..$F6, $F8..$FE: Result := U - 32;
    $FF: Result := $178;
    $100..$137, $14A..$177: if Odd(U) then Result := U - 1;
    $139..$148, $179..$17E: if not Odd(U) then Result := U - 1;
    $3AC: Result := $386;
    $3AD..$3AF: Result := U - 37;
    $3B1..$3C1, $3C3..$3CB: Result := U - 32;
    $3C2: Result := $3A3;
    $3CC: Result := $38C;
    $3CD, $3CE: Result := U - 63;
    $430..$44F: Result := U - 32;
    $450..$45F: Result := U - 80;
    $460..$481, $48A..$4BF, $4D0..$4FF: if Odd(U) then Result := U - 1;
    $4C1..$4CE: if not Odd(U) then Result := U - 1;
  end;
end;

procedure QueryUpcaseTable(var X: array of Char);
var
  B: Integer;
  U: LongWord;
  R: Byte;
begin
  for B := 0 to High(X) do
  begin
    X[B] := Chr(B and 255);
    if B > 255 then
      Break;
    U := CpToUnicode(B);
    R := CpFromUnicode(UpperUnicode(U));
    if (R <> 0) and (UpperUnicode(U) <> U) then
      X[B] := Chr(R);
  end;
end;

function QueryToAscii(CP: Integer; var X: array of Char): Boolean;
var
  Screen, B: Integer;
  U: LongWord;
  Back: array[0..255] of LongWord;
begin
  for B := 0 to High(X) do
    X[B] := Chr(B and 255);
  Screen := CpCurrent;
  if not CpSelect(CP) then
    Exit(False);
  for B := 0 to 255 do
    Back[B] := CpToUnicode(B);
  CpSelect(Screen);
  for B := 0 to 255 do
    if B <= High(X) then
    begin
      U := Back[B];
      if (CpFromUnicode(U) <> 0) or (B = 0) then
        X[B] := Chr(CpFromUnicode(U));
    end;
  Result := True;
end;

initialization
  InitCountryInfo;
end.
