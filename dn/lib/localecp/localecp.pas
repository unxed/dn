{ LocaleCp: host locale → legacy OEM/ANSI code pages and UTF-8 decoders.
  Behavioral lock to github.com/unxed/localecp (BSD-3-Clause), including
  getEncodingByName fallbacks (IBM737→1253, IBM775→1257, …). Unix init matches
  localecp_unix.go (LANG/LC_ALL/LC_CTYPE, strip at '.'). Multi-byte pages are
  not decoded here (nil → caller keeps raw bytes). See dn/lib/localecp/README.md. }
{$mode objfpc}{$H+}
unit localecp;

interface

var
  { Windows-style codepage numbers; 0 on Unix (Go localecp same). Defaults 437/1252. }
  OEMCodepage: Integer = 0;
  ANSICodepage: Integer = 0;

{ Decode raw single-byte text with the host OEM / ANSI / System decoder.
  Empty input → ''; unknown page → raw bytes as Latin-1-ish UTF-8 copy (Go returns
  string(raw) when decoder is nil / fails). }
function OEMDecode(const Raw: RawByteString): AnsiString;
function ANSIDecode(const Raw: RawByteString): AnsiString;
function SystemDecode(const Raw: RawByteString): AnsiString;

{ Override active pages (tests). Page=0 keeps default 437/1252 maps. }
procedure SetOEMCodePage(Page: Integer);
procedure SetANSICodePage(Page: Integer);

{ Locale name → OEM/ANSI page numbers (0 if unknown). }
function LocaleOemPage(const Loc: ShortString): Integer;
function LocaleAnsiPage(const Loc: ShortString): Integer;

implementation

uses
  SysUtils, TvUtf8;

{$I localecp_tables.inc}

type
  TLocEnc = record
    L: string[16];
    OemName: string[16];
    AnsiName: string[16];
  end;

const
  { Same keys as localecp lcToOemTable / lcToAnsiTable (encoding names). }
  Table: array[0..130] of TLocEnc = (
    (L: 'af_ZA'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'ar_SA'; OemName: 'IBM720'; AnsiName: 'WINDOWS-1256'),
    (L: 'ar_LB'; OemName: 'IBM720'; AnsiName: 'WINDOWS-1256'),
    (L: 'ar_EG'; OemName: 'IBM720'; AnsiName: 'WINDOWS-1256'),
    (L: 'ar_DZ'; OemName: 'IBM720'; AnsiName: 'WINDOWS-1256'),
    (L: 'ar_BH'; OemName: 'IBM720'; AnsiName: 'WINDOWS-1256'),
    (L: 'ar_IQ'; OemName: 'IBM720'; AnsiName: 'WINDOWS-1256'),
    (L: 'ar_JO'; OemName: 'IBM720'; AnsiName: 'WINDOWS-1256'),
    (L: 'ar_KW'; OemName: 'IBM720'; AnsiName: 'WINDOWS-1256'),
    (L: 'ar_LY'; OemName: 'IBM720'; AnsiName: 'WINDOWS-1256'),
    (L: 'ar_MA'; OemName: 'IBM720'; AnsiName: 'WINDOWS-1256'),
    (L: 'ar_OM'; OemName: 'IBM720'; AnsiName: 'WINDOWS-1256'),
    (L: 'ar_QA'; OemName: 'IBM720'; AnsiName: 'WINDOWS-1256'),
    (L: 'ar_SY'; OemName: 'IBM720'; AnsiName: 'WINDOWS-1256'),
    (L: 'ar_TN'; OemName: 'IBM720'; AnsiName: 'WINDOWS-1256'),
    (L: 'ar_AE'; OemName: 'IBM720'; AnsiName: 'WINDOWS-1256'),
    (L: 'ar_YE'; OemName: 'IBM720'; AnsiName: 'WINDOWS-1256'),
    (L: 'ast_ES'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'az_AZ@cyrillic'; OemName: 'IBM866'; AnsiName: 'WINDOWS-1251'),
    (L: 'az_AZ'; OemName: 'IBM857'; AnsiName: 'WINDOWS-1254'),
    (L: 'be_BY'; OemName: 'IBM866'; AnsiName: 'WINDOWS-1251'),
    (L: 'bg_BG'; OemName: 'IBM866'; AnsiName: 'WINDOWS-1251'),
    (L: 'br_FR'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'ca_ES'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'zh_CN'; OemName: 'GBK'; AnsiName: 'GBK'),
    (L: 'zh_TW'; OemName: 'BIG5'; AnsiName: 'BIG5'),
    (L: 'kw_GB'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'cs_CZ'; OemName: 'IBM852'; AnsiName: 'WINDOWS-1250'),
    (L: 'cy_GB'; OemName: 'IBM850'; AnsiName: 'ISO-8859-4'),
    (L: 'da_DK'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'de_AT'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'de_LI'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'de_LU'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'de_CH'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'de_DE'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'el_GR'; OemName: 'IBM737'; AnsiName: 'WINDOWS-1253'),
    (L: 'en_AU'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'en_CA'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'en_GB'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'en_IE'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'en_JM'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'en_BZ'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'en_PH'; OemName: 'IBM437'; AnsiName: 'WINDOWS-1252'),
    (L: 'en_ZA'; OemName: 'IBM437'; AnsiName: 'WINDOWS-1252'),
    (L: 'en_TT'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'en_US'; OemName: 'IBM437'; AnsiName: 'WINDOWS-1252'),
    (L: 'en_ZW'; OemName: 'IBM437'; AnsiName: 'WINDOWS-1252'),
    (L: 'en_NZ'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'es_PA'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'es_BO'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'es_CR'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'es_DO'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'es_SV'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'es_EC'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'es_GT'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'es_HN'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'es_NI'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'es_CL'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'es_MX'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'es_ES'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'es_CO'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'es_PE'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'es_AR'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'es_PR'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'es_VE'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'es_UY'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'es_PY'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'et_EE'; OemName: 'IBM775'; AnsiName: 'WINDOWS-1257'),
    (L: 'eu_ES'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'fa_IR'; OemName: 'IBM720'; AnsiName: 'WINDOWS-1256'),
    (L: 'fi_FI'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'fo_FO'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'fr_FR'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'fr_BE'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'fr_CA'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'fr_LU'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'fr_MC'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'fr_CH'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'ga_IE'; OemName: 'IBM437'; AnsiName: 'WINDOWS-1252'),
    (L: 'gd_GB'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'gv_IM'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'gl_ES'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'he_IL'; OemName: 'IBM862'; AnsiName: 'WINDOWS-1255'),
    (L: 'hr_HR'; OemName: 'IBM852'; AnsiName: 'WINDOWS-1250'),
    (L: 'hu_HU'; OemName: 'IBM852'; AnsiName: 'WINDOWS-1250'),
    (L: 'id_ID'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'is_IS'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'it_IT'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'it_CH'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'iv_IV'; OemName: 'IBM437'; AnsiName: 'WINDOWS-1252'),
    (L: 'ja_JP'; OemName: 'CP932'; AnsiName: 'CP932'),
    (L: 'kk_KZ'; OemName: 'IBM866'; AnsiName: 'WINDOWS-1251'),
    (L: 'ko_KR'; OemName: 'CP949'; AnsiName: 'CP949'),
    (L: 'ky_KG'; OemName: 'IBM866'; AnsiName: 'WINDOWS-1251'),
    (L: 'lt_LT'; OemName: 'IBM775'; AnsiName: 'WINDOWS-1251'),
    (L: 'lv_LV'; OemName: 'IBM775'; AnsiName: 'WINDOWS-1257'),
    (L: 'mk_MK'; OemName: 'IBM866'; AnsiName: 'WINDOWS-1251'),
    (L: 'mn_MN'; OemName: 'IBM866'; AnsiName: 'WINDOWS-1251'),
    (L: 'ms_BN'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'ms_MY'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'nl_BE'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'nl_NL'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'nl_SR'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'nn_NO'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'nb_NO'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'pl_PL'; OemName: 'IBM852'; AnsiName: 'WINDOWS-1250'),
    (L: 'pt_BR'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'pt_PT'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'rm_CH'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'ro_RO'; OemName: 'IBM852'; AnsiName: 'WINDOWS-1250'),
    (L: 'ru_RU'; OemName: 'IBM866'; AnsiName: 'WINDOWS-1251'),
    (L: 'sk_SK'; OemName: 'IBM852'; AnsiName: 'WINDOWS-1250'),
    (L: 'sl_SI'; OemName: 'IBM852'; AnsiName: 'WINDOWS-1250'),
    (L: 'sq_AL'; OemName: 'IBM852'; AnsiName: 'WINDOWS-1250'),
    (L: 'sr_RS@latin'; OemName: 'IBM852'; AnsiName: 'WINDOWS-1250'),
    (L: 'sr_RS'; OemName: 'IBM855'; AnsiName: 'WINDOWS-1251'),
    (L: 'sv_SE'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'sv_FI'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'sw_KE'; OemName: 'IBM437'; AnsiName: 'WINDOWS-1252'),
    (L: 'th_TH'; OemName: 'TIS-620'; AnsiName: 'WINDOWS-874'),
    (L: 'tr_TR'; OemName: 'IBM857'; AnsiName: 'WINDOWS-1254'),
    (L: 'tt_RU'; OemName: 'IBM866'; AnsiName: 'WINDOWS-1251'),
    (L: 'uk_UA'; OemName: 'IBM866'; AnsiName: 'WINDOWS-1251'),
    (L: 'ur_PK'; OemName: 'IBM720'; AnsiName: 'WINDOWS-1256'),
    (L: 'uz_UZ@cyrillic'; OemName: 'IBM866'; AnsiName: 'WINDOWS-1251'),
    (L: 'uz_UZ'; OemName: 'IBM857'; AnsiName: 'WINDOWS-1254'),
    (L: 'vi_VN'; OemName: 'WINDOWS-1258'; AnsiName: 'WINDOWS-1258'),
    (L: 'wa_BE'; OemName: 'IBM850'; AnsiName: 'WINDOWS-1252'),
    (L: 'zh_HK'; OemName: 'BIG5'; AnsiName: 'BIG5'),
    (L: 'zh_SG'; OemName: 'GBK'; AnsiName: 'GBK'),
    (L: 'zh_MO'; OemName: 'BIG5'; AnsiName: 'WINDOWS-1252')
  );

var
  OEMMap: PCpMap = @Cp437;
  ANSIMap: PCpMap = @Cp1252;
  SystemMap: PCpMap = @Cp437;

function MapByName(const Name: ShortString): PCpMap;
  { Matches localecp getEncodingByName, including intentional fallbacks. }
begin
  if (Name = 'IBM437') or (Name = 'cp437') then
    Exit(@Cp437);
  if (Name = 'IBM850') or (Name = 'cp850') then
    Exit(@Cp850);
  if (Name = 'IBM852') or (Name = 'cp852') then
    Exit(@Cp852);
  if (Name = 'IBM855') or (Name = 'cp855') then
    Exit(@Cp855);
  if (Name = 'IBM862') or (Name = 'cp862') then
    Exit(@Cp862);
  if (Name = 'IBM866') or (Name = 'cp866') then
    Exit(@Cp866);
  if Name = 'IBM720' then
    Exit(@Cp1256); { localecp fallback }
  if Name = 'IBM737' then
    Exit(@Cp1253); { localecp fallback }
  if Name = 'IBM775' then
    Exit(@Cp1257); { localecp fallback }
  if Name = 'IBM857' then
    Exit(@Cp1254); { localecp fallback }
  if (Name = 'WINDOWS-1250') or (Name = 'windows-1250') then
    Exit(@Cp1250);
  if (Name = 'WINDOWS-1251') or (Name = 'windows-1251') then
    Exit(@Cp1251);
  if (Name = 'WINDOWS-1252') or (Name = 'windows-1252') then
    Exit(@Cp1252);
  if (Name = 'WINDOWS-1253') or (Name = 'windows-1253') then
    Exit(@Cp1253);
  if (Name = 'WINDOWS-1254') or (Name = 'windows-1254') then
    Exit(@Cp1254);
  if (Name = 'WINDOWS-1255') or (Name = 'windows-1255') then
    Exit(@Cp1255);
  if (Name = 'WINDOWS-1256') or (Name = 'windows-1256') then
    Exit(@Cp1256);
  if (Name = 'WINDOWS-1257') or (Name = 'windows-1257') then
    Exit(@Cp1257);
  if (Name = 'WINDOWS-1258') or (Name = 'windows-1258') then
    Exit(@Cp1258);
  if (Name = 'WINDOWS-874') or (Name = 'windows-874') or (Name = 'TIS-620') then
    Exit(@Cp874);
  if (Name = 'ISO-8859-4') or (Name = 'iso-8859-4') then
    Exit(@Iso8859_4);
  Result := nil; { GBK/BIG5/CP932/CP949 — not in this minimal port }
end;

function MapByPage(Page: Integer): PCpMap;
begin
  case Page of
    437: Result := @Cp437;
    850: Result := @Cp850;
    852: Result := @Cp852;
    855: Result := @Cp855;
    862: Result := @Cp862;
    866: Result := @Cp866;
    1250: Result := @Cp1250;
    1251: Result := @Cp1251;
    1252: Result := @Cp1252;
    1253: Result := @Cp1253;
    1254: Result := @Cp1254;
    1255: Result := @Cp1255;
    1256: Result := @Cp1256;
    1257: Result := @Cp1257;
    1258: Result := @Cp1258;
    874: Result := @Cp874;
  else
    Result := nil;
  end;
end;

function DecodeWithMap(M: PCpMap; const Raw: RawByteString): AnsiString;
var
  I, N: Integer;
  Buf: array[0..7] of Byte;
  CP: LongWord;
begin
  if Length(Raw) = 0 then
    Exit('');
  if M = nil then
    Exit(AnsiString(Raw));
  Result := '';
  for I := 1 to Length(Raw) do
  begin
    CP := M^[Byte(Raw[I])];
    if CP = $FFFD then
      Exit(AnsiString(Raw)); { treat undefined like decode error → raw }
    N := Utf8Encode(CP, @Buf[0]);
    Result := Result + Copy(PChar(@Buf[0]), 1, N);
  end;
end;

function OEMDecode(const Raw: RawByteString): AnsiString;
begin
  Result := DecodeWithMap(OEMMap, Raw);
end;

function ANSIDecode(const Raw: RawByteString): AnsiString;
begin
  Result := DecodeWithMap(ANSIMap, Raw);
end;

function SystemDecode(const Raw: RawByteString): AnsiString;
begin
  Result := DecodeWithMap(SystemMap, Raw);
end;

procedure SetOEMCodePage(Page: Integer);
var
  M: PCpMap;
begin
  M := MapByPage(Page);
  if M = nil then
    M := @Cp437;
  OEMMap := M;
  SystemMap := M;
  if Page <> 0 then
    OEMCodepage := Page
  else
    OEMCodepage := 0;
end;

procedure SetANSICodePage(Page: Integer);
var
  M: PCpMap;
begin
  M := MapByPage(Page);
  if M = nil then
    M := @Cp1252;
  ANSIMap := M;
  if Page <> 0 then
    ANSICodepage := Page
  else
    ANSICodepage := 0;
end;

function FindLoc(const Base: ShortString; out Idx: Integer): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(Table) do
    if Table[I].L = Base then
    begin
      Idx := I;
      Exit(True);
    end;
  Result := False;
end;

function LocaleBase(const Loc: ShortString): ShortString;
var
  N: Integer;
begin
  Result := Loc;
  N := Pos('.', Result);
  if N > 0 then
    Result := Copy(Result, 1, N - 1);
end;

function LocaleOemPage(const Loc: ShortString): Integer;
var
  Base: ShortString;
  Idx: Integer;
  M: PCpMap;
begin
  Result := 0;
  Base := LocaleBase(Loc);
  if (Base = '') or (Base = 'C') or (Base = 'POSIX') then
    Exit;
  if not FindLoc(Base, Idx) then
    Exit;
  M := MapByName(Table[Idx].OemName);
  if M = nil then
    Exit;
  { Prefer known page numbers for tests/UI; multi-byte names stay 0. }
  if Table[Idx].OemName = 'IBM437' then Result := 437
  else if Table[Idx].OemName = 'IBM850' then Result := 850
  else if Table[Idx].OemName = 'IBM852' then Result := 852
  else if Table[Idx].OemName = 'IBM855' then Result := 855
  else if Table[Idx].OemName = 'IBM862' then Result := 862
  else if Table[Idx].OemName = 'IBM866' then Result := 866
  else if Table[Idx].OemName = 'IBM720' then Result := 1256
  else if Table[Idx].OemName = 'IBM737' then Result := 1253
  else if Table[Idx].OemName = 'IBM775' then Result := 1257
  else if Table[Idx].OemName = 'IBM857' then Result := 1254
  else if Table[Idx].OemName = 'WINDOWS-1258' then Result := 1258
  else if (Table[Idx].OemName = 'TIS-620') or (Table[Idx].OemName = 'WINDOWS-874') then
    Result := 874;
end;

function LocaleAnsiPage(const Loc: ShortString): Integer;
var
  Base: ShortString;
  Idx: Integer;
begin
  Result := 0;
  Base := LocaleBase(Loc);
  if (Base = '') or (Base = 'C') or (Base = 'POSIX') then
    Exit;
  if not FindLoc(Base, Idx) then
    Exit;
  if Table[Idx].AnsiName = 'WINDOWS-1250' then Result := 1250
  else if Table[Idx].AnsiName = 'WINDOWS-1251' then Result := 1251
  else if Table[Idx].AnsiName = 'WINDOWS-1252' then Result := 1252
  else if Table[Idx].AnsiName = 'WINDOWS-1253' then Result := 1253
  else if Table[Idx].AnsiName = 'WINDOWS-1254' then Result := 1254
  else if Table[Idx].AnsiName = 'WINDOWS-1255' then Result := 1255
  else if Table[Idx].AnsiName = 'WINDOWS-1256' then Result := 1256
  else if Table[Idx].AnsiName = 'WINDOWS-1257' then Result := 1257
  else if Table[Idx].AnsiName = 'WINDOWS-1258' then Result := 1258
  else if Table[Idx].AnsiName = 'WINDOWS-874' then Result := 874
  else if Table[Idx].AnsiName = 'ISO-8859-4' then Result := 0 { no Windows number }
  else
    Result := 0;
end;

procedure ApplyLocMaps(const Base: ShortString);
var
  Idx: Integer;
  M: PCpMap;
begin
  if not FindLoc(Base, Idx) then
    Exit;
  M := MapByName(Table[Idx].OemName);
  if M <> nil then
  begin
    OEMMap := M;
    SystemMap := M;
  end;
  M := MapByName(Table[Idx].AnsiName);
  if M <> nil then
    ANSIMap := M;
end;

procedure InitSystemLocales;
  { localecp_unix.go: LC_ALL, else LC_CTYPE, else LANG; strip at '.'; skip C/POSIX. }
var
  Lc, Base: string;
begin
  Lc := GetEnvironmentVariable('LC_ALL');
  if Lc = '' then
    Lc := GetEnvironmentVariable('LC_CTYPE');
  if Lc = '' then
    Lc := GetEnvironmentVariable('LANG');
  if (Lc = '') or (Lc = 'C') or (Lc = 'POSIX') then
    Exit;
  Base := LocaleBase(ShortString(Lc));
  if (Base = '') or (Base = 'C') or (Base = 'POSIX') then
    Exit;
  ApplyLocMaps(ShortString(Base));
end;

initialization
  InitSystemLocales;
end.
