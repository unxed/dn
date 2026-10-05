{ DPMI32-specific country tools unit by A.Korop (AK155)}


unit country;

interface

uses
  Defines;

procedure GetSysCountryInfo;
  {` Fills CountryInfo (basics) with data from the system `}

procedure QueryUpcaseTable;
  {` For the current code page, requests from the OS the uppercase
  conversion table. Result is UpCaseArray `}

function QueryToAscii(CP: Word; var ToAscii: TXLat): Boolean;
  {` For code page CP, requests from the OS the conversion table
  from CP to the current code page`}

function QueryABCSort(CP: Word; var ABCSortXlat: TXLat): Boolean;

implementation

uses
  realmode, osdep,
  basics, strutil, Strings, keymap;

procedure QueryUpcaseTable;
  var
    Regs: real_mode_call_structure_typ;
  begin
  NullXLat(TXlat(DosSegFlat^));
  init_register(Regs);
  with Regs do
    begin
    AX_ := $6521; {capitalize string}
    CX_ := SizeOf(UpCaseArray);
    DS_ := DosSeg; DX_ := 0;  {DS:DX -> string to capitalize}
    end;
  intr_realmode(Regs, $21);
  move(DosSegFlat^, UpCaseArray, SizeOf(UpCaseArray));
  end;

function QueryCountryInfo: Boolean;
  var
    Regs: real_mode_call_structure_typ;
  begin
  init_register(Regs);
  with Regs do
    begin
    AX_ := $3800; {get current-country info}
    DS_ := DosSeg; DX_ := 0;  {DS:DX -> buffer for returned info}
    end;
  intr_realmode(Regs, $21);
  end;

type
  TDosCountryInfo = record
    DateFormat: SmallWord;
    CurrencySymbol: array[0..4] of char;
    ThousandsSeparator: array[0..1] of char;
    DecimalSeparator: array[0..1] of char;
    DateSeparator: array[0..1] of char;
    TimeSeparator: array[0..1] of char;
    CurrencyFormat: Byte;
    CurrencyDecimals: Byte;
    TimeFormat: Byte;
    {...}
    end;

procedure GetSysCountryInfo;
  begin
  QueryCountryInfo;
  with basics.CountryInfo, TDosCountryInfo(DosSegFlat^) do
    begin
    DateFmt := DateFormat;
    TimeFmt := TimeFormat;
    DateSep := DateSeparator[0];
    TimeSep := TimeSeparator[0];
    ThouSep := ThousandsSeparator[0];
    DecSep := DecimalSeparator[0];
    DecSign := Char(byte('0') + CurrencyDecimals);
    Currency := StrPas(CurrencySymbol);
    if (CurrencyFormat and 4) <> 0 then
      CurrencyFormat := 4;
    CurrencyFmt := CurrencyFormat;
    end;
  end;

{Stub!}
function QueryToAscii(CP: word; var ToAscii: TXLat): Boolean;
  begin
  NullXlat(ToAscii);
  end;

function QueryABCSort(CP: Word; var ABCSortXlat: TXLat): Boolean;
  begin
  Result := False; //!! Not implemented yet (04.09.2005)
  end;

end.
