{ Country_ for Linux: the country tools of DN (our unit; it replaces the DPMI32 unit of the archive, which asks DOS for them:
  INT 21h AX=6521h and 3800h). Here: the table of the upper case of the code page of DN (CP866: the texts of DN are DOS
  OEM bytes, the Russian resources are in it) and the settings of a country that do not depend on the system (the
  defaults of DN). TODO: the settings of the country from the locale (LC_*), the tables of other code pages. }
{$mode objfpc}{$H-}
unit Country_;

interface

uses
  Defines;

procedure GetSysCountryInfo;
procedure QueryUpcaseTable;
function QueryToAscii(CP: Word; var ToAscii: TXLat): Boolean;
function QueryABCSort(CP: Word; var ABCSortXlat: TXLat): Boolean;

implementation

uses
  advance, advance1;

procedure QueryUpcaseTable;
var
  I: Integer;
begin
  for I := 0 to 255 do
    UpCaseArray[Chr(I)] := Chr(I);
  for I := Ord('a') to Ord('z') do
    UpCaseArray[Chr(I)] := Chr(I - 32);
  { CP866: the small Cyrillic letters (A0-AF, E0-EF) are the capitals (80-8F, 90-9F) +32 and +80; yo, Ukrainian ye, yi, short u }
  for I := $A0 to $AF do
    UpCaseArray[Chr(I)] := Chr(I - $20);
  for I := $E0 to $EF do
    UpCaseArray[Chr(I)] := Chr(I - $50);
  UpCaseArray[Chr($F1)] := Chr($F0);
  UpCaseArray[Chr($F3)] := Chr($F2);
  UpCaseArray[Chr($F5)] := Chr($F4);
  UpCaseArray[Chr($F7)] := Chr($F6);
end;

procedure GetSysCountryInfo;
begin
  { the defaults of DN stay: dd.mm.yy is not forced here, the 24-hour clock is what a terminal user expects }
  advance.CountryInfo.TimeFmt := 1;
  advance.CountryInfo.DateFmt := 1;
end;

function QueryToAscii(CP: Word; var ToAscii: TXLat): Boolean;
var
  I: Integer;
begin
  for I := 0 to 255 do
    ToAscii[Chr(I)] := Chr(I);
  Result := False;
end;

function QueryABCSort(CP: Word; var ABCSortXlat: TXLat): Boolean;
begin
  Result := False;
end;

end.
