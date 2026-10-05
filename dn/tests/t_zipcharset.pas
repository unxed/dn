{$mode objfpc}{$H+}
{ Golden vectors aligned with github.com/unxed/zipcharset zipcharset_test.go }
program t_zipcharset;
uses
  zipcharset, localecp;
{$I dntest.inc}

function BuildUnicodeExtra(const Raw: RawByteString; const Utf8Str: AnsiString): RawByteString;
var
  Crc: LongWord;
  Payload, Extra: RawByteString;
  I: Integer;
  function Crc32IEEE(const Data: RawByteString): LongWord;
  var
    Table: array[0..255] of LongWord;
    J, K: Integer;
    C: LongWord;
  begin
    for J := 0 to 255 do
    begin
      C := LongWord(J);
      for K := 0 to 7 do
        if (C and 1) <> 0 then
          C := ($EDB88320 xor (C shr 1))
        else
          C := C shr 1;
      Table[J] := C;
    end;
    C := $FFFFFFFF;
    for J := 1 to Length(Data) do
      C := Table[Byte(C) xor Byte(Data[J])] xor (C shr 8);
    Result := C xor $FFFFFFFF;
  end;
begin
  Crc := Crc32IEEE(Raw);
  SetLength(Payload, 5 + Length(Utf8Str));
  Payload[1] := #1;
  Payload[2] := Chr(Crc and $FF);
  Payload[3] := Chr((Crc shr 8) and $FF);
  Payload[4] := Chr((Crc shr 16) and $FF);
  Payload[5] := Chr((Crc shr 24) and $FF);
  for I := 1 to Length(Utf8Str) do
    Payload[5 + I] := Utf8Str[I];
  SetLength(Extra, 4 + Length(Payload));
  Extra[1] := Chr(UnicodePathExtraID and $FF);
  Extra[2] := Chr((UnicodePathExtraID shr 8) and $FF);
  Extra[3] := Chr(Length(Payload) and $FF);
  Extra[4] := Chr((Length(Payload) shr 8) and $FF);
  for I := 1 to Length(Payload) do
    Extra[4 + I] := Payload[I];
  Result := Extra;
end;

var
  Cp866Raw, Win1251Raw: RawByteString;
  Got: AnsiString;
begin
  SetOEMCodePage(866);
  SetANSICodePage(1251);

  SetLength(Cp866Raw, 6);
  Cp866Raw[1] := #$8F; Cp866Raw[2] := #$E0; Cp866Raw[3] := #$A8;
  Cp866Raw[4] := #$A2; Cp866Raw[5] := #$A5; Cp866Raw[6] := #$E2;

  SetLength(Win1251Raw, 6);
  Win1251Raw[1] := #$CF; Win1251Raw[2] := #$F0; Win1251Raw[3] := #$E8;
  Win1251Raw[4] := #$E2; Win1251Raw[5] := #$E5; Win1251Raw[6] := #$F2;

  Got := DecodeText('Привет', True, CreatorFAT, 20, '', False);
  Check(Got = 'Привет', 'EFS Flag');

  Got := DecodeText(Win1251Raw, False, CreatorNTFS, 20, '', False);
  Check(Got = 'Привет', 'NTFS (ANSI)');

  Got := DecodeText(Cp866Raw, False, CreatorFAT, 10, '', False);
  Check(Got = 'Привет', 'FAT (OEM)');

  Got := DecodeText(Cp866Raw, False, CreatorFAT, 10,
    BuildUnicodeExtra(Cp866Raw, 'Unicode'), False);
  Check(Got = 'Unicode', 'Unicode Extra valid');

  Got := DecodeText('Привет', False, CreatorUnix, 20, '', False);
  Check(Got = 'Привет', 'Unix OS (Always UTF-8)');

  Got := DecodeText('hello', False, 99, 10, '', False);
  Check(Got = 'hello', 'Fallback System Decoder');

  Got := DecodeText('', False, CreatorFAT, 10, '', False);
  Check(Got = '', 'Empty Input');

  Check(LocaleOemPage('ru_RU.UTF-8') = 866, 'locale OEM ru_RU');
  Check(LocaleAnsiPage('ru_RU.UTF-8') = 1251, 'locale ANSI ru_RU');

  Finish;
end.
