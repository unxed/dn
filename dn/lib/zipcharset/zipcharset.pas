{ ZipCharset: ZIP name/comment decode 1:1 with github.com/unxed/zipcharset
  (BSD-3-Clause). Uses dn/lib/localecp for OEM/ANSI/System decoders. }
{$mode objfpc}{$H+}
unit zipcharset;

interface

const
  UnicodePathExtraID = $7075;
  UnicodeCommentExtraID = $6375;

  CreatorFAT = 0;
  CreatorUnix = 3;
  CreatorHPFS = 6;
  CreatorNTFS = 11;
  CreatorMacOSX = 19;

{ Decode ZIP filename or comment bytes (extra = local/central extra field). }
function DecodeText(const Raw: RawByteString; IsUTF8Flag: Boolean;
  PackOS: Byte; PackVer: Word; const Extra: RawByteString;
  IsComment: Boolean): AnsiString;

function ParseUnicodeExtraField(const Extra: RawByteString; TargetID: Word;
  const RawData: RawByteString): AnsiString;

implementation

uses
  localecp, TvUtf8;

function Crc32IEEE(const Data: RawByteString): LongWord;
  { hash/crc32.ChecksumIEEE }
var
  Table: array[0..255] of LongWord;
  I, J: Integer;
  C: LongWord;
begin
  for I := 0 to 255 do
  begin
    C := LongWord(I);
    for J := 0 to 7 do
      if (C and 1) <> 0 then
        C := ($EDB88320 xor (C shr 1))
      else
        C := C shr 1;
    Table[I] := C;
  end;
  C := $FFFFFFFF;
  for I := 1 to Length(Data) do
    C := Table[Byte(C) xor Byte(Data[I])] xor (C shr 8);
  Result := C xor $FFFFFFFF;
end;

function Utf8ValidString(const S: AnsiString): Boolean;
var
  I, Used: Integer;
  CP: LongWord;
begin
  I := 1;
  while I <= Length(S) do
  begin
    if not Utf8Decode(@S[I], Length(S) - I + 1, CP, Used) then
      Exit(False);
    Inc(I, Used);
  end;
  Result := True;
end;

function ParseUnicodeExtraField(const Extra: RawByteString; TargetID: Word;
  const RawData: RawByteString): AnsiString;
var
  Pos, Tag, Size: Integer;
  Version: Byte;
  ExpectedCRC, ActualCRC: LongWord;
  Utf8Str: AnsiString;
begin
  Result := '';
  Pos := 1;
  while Length(Extra) - Pos + 1 >= 4 do
  begin
    Tag := Byte(Extra[Pos]) or (Byte(Extra[Pos + 1]) shl 8);
    Size := Byte(Extra[Pos + 2]) or (Byte(Extra[Pos + 3]) shl 8);
    Inc(Pos, 4);
    if Size > Length(Extra) - Pos + 1 then
      Break;
    if (Tag = TargetID) and (Size >= 5) then
    begin
      Version := Byte(Extra[Pos]);
      if Version = 1 then
      begin
        ExpectedCRC := Byte(Extra[Pos + 1]) or (Byte(Extra[Pos + 2]) shl 8) or
          (Byte(Extra[Pos + 3]) shl 16) or (Byte(Extra[Pos + 4]) shl 24);
        ActualCRC := Crc32IEEE(RawData);
        if ExpectedCRC = ActualCRC then
        begin
          Utf8Str := Copy(Extra, Pos + 5, Size - 5);
          if Utf8ValidString(Utf8Str) then
            Exit(Utf8Str);
        end;
      end;
    end;
    Inc(Pos, Size);
  end;
end;

function DecodeText(const Raw: RawByteString; IsUTF8Flag: Boolean;
  PackOS: Byte; PackVer: Word; const Extra: RawByteString;
  IsComment: Boolean): AnsiString;
var
  TargetID: Word;
  Dec: AnsiString;
begin
  if Length(Raw) = 0 then
    Exit('');

  if IsComment then
    TargetID := UnicodeCommentExtraID
  else
    TargetID := UnicodePathExtraID;

  Result := ParseUnicodeExtraField(Extra, TargetID, Raw);
  if Result <> '' then
    Exit;

  if IsUTF8Flag or (PackOS = CreatorUnix) or (PackOS = CreatorMacOSX) then
    Exit(AnsiString(Raw));

  if (PackOS = CreatorNTFS) and (PackVer >= 20) then
    Dec := ANSIDecode(Raw)
  else if (PackOS = CreatorFAT) and (PackVer >= 25) and (PackVer <= 40) then
    Dec := OEMDecode(Raw)
  else if (PackOS = CreatorFAT) or (PackOS = CreatorHPFS) or (PackOS = CreatorNTFS) then
    Dec := OEMDecode(Raw)
  else
    Dec := SystemDecode(Raw);

  { Go: if decoder nil or err → string(raw). Our decoders always return something;
    OEMDecode returns raw on undefined bytes. }
  if Dec <> '' then
    Result := Dec
  else
    Result := AnsiString(Raw);
end;

end.
