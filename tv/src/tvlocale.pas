{ TvLocale: the OEM code page (the single-byte page of DOS) that goes with the locale of the host: LC_ALL, LC_CTYPE, LANG ("ru_RU.UTF-8" ->
  866). Written for this port; the table is that of github.com/unxed/localecp (lcToOemTable; the same author; BSD-3-Clause), the pages that TvCodePg
  does not have (720, the multi-byte ones: GBK, BIG5, CP932, CP949; TIS-620, 1258) are 437 here. A language without the country is taken by the
  first entry of the language ("ru" -> ru_RU). }
{$mode objfpc}{$H-}
unit TvLocale;

interface

{ The page for a locale name as the environment gives it ("ru_RU", "ru_RU.UTF-8", "sr_RS@latin"); 0 if the locale is not known. }
function LocaleOemCodePage(const Loc: ShortString): Integer;
{ The page of the host by the environment variables; 0 if they say nothing ("C", "POSIX", "C.UTF-8", not set) or the locale is not known. }
function HostOemCodePage: Integer;

implementation

uses
  SysUtils;

type
  TLocPage = record
    L: string[16];
    P: Integer;
  end;

const
  Table: array[0..130] of TLocPage = (
    (L: 'af_ZA'; P: 850), (L: 'ar_SA'; P: 437), (L: 'ar_LB'; P: 437),
    (L: 'ar_EG'; P: 437), (L: 'ar_DZ'; P: 437), (L: 'ar_BH'; P: 437),
    (L: 'ar_IQ'; P: 437), (L: 'ar_JO'; P: 437), (L: 'ar_KW'; P: 437),
    (L: 'ar_LY'; P: 437), (L: 'ar_MA'; P: 437), (L: 'ar_OM'; P: 437),
    (L: 'ar_QA'; P: 437), (L: 'ar_SY'; P: 437), (L: 'ar_TN'; P: 437),
    (L: 'ar_AE'; P: 437), (L: 'ar_YE'; P: 437), (L: 'ast_ES'; P: 850),
    (L: 'az_AZ@cyrillic'; P: 866), (L: 'az_AZ'; P: 857), (L: 'be_BY'; P: 866),
    (L: 'bg_BG'; P: 866), (L: 'br_FR'; P: 850), (L: 'ca_ES'; P: 850),
    (L: 'zh_CN'; P: 437), (L: 'zh_TW'; P: 437), (L: 'kw_GB'; P: 850),
    (L: 'cs_CZ'; P: 852), (L: 'cy_GB'; P: 850), (L: 'da_DK'; P: 850),
    (L: 'de_AT'; P: 850), (L: 'de_LI'; P: 850), (L: 'de_LU'; P: 850),
    (L: 'de_CH'; P: 850), (L: 'de_DE'; P: 850), (L: 'el_GR'; P: 737),
    (L: 'en_AU'; P: 850), (L: 'en_CA'; P: 850), (L: 'en_GB'; P: 850),
    (L: 'en_IE'; P: 850), (L: 'en_JM'; P: 850), (L: 'en_BZ'; P: 850),
    (L: 'en_PH'; P: 437), (L: 'en_ZA'; P: 437), (L: 'en_TT'; P: 850),
    (L: 'en_US'; P: 437), (L: 'en_ZW'; P: 437), (L: 'en_NZ'; P: 850),
    (L: 'es_PA'; P: 850), (L: 'es_BO'; P: 850), (L: 'es_CR'; P: 850),
    (L: 'es_DO'; P: 850), (L: 'es_SV'; P: 850), (L: 'es_EC'; P: 850),
    (L: 'es_GT'; P: 850), (L: 'es_HN'; P: 850), (L: 'es_NI'; P: 850),
    (L: 'es_CL'; P: 850), (L: 'es_MX'; P: 850), (L: 'es_ES'; P: 850),
    (L: 'es_CO'; P: 850), (L: 'es_PE'; P: 850), (L: 'es_AR'; P: 850),
    (L: 'es_PR'; P: 850), (L: 'es_VE'; P: 850), (L: 'es_UY'; P: 850),
    (L: 'es_PY'; P: 850), (L: 'et_EE'; P: 775), (L: 'eu_ES'; P: 850),
    (L: 'fa_IR'; P: 437), (L: 'fi_FI'; P: 850), (L: 'fo_FO'; P: 850),
    (L: 'fr_FR'; P: 850), (L: 'fr_BE'; P: 850), (L: 'fr_CA'; P: 850),
    (L: 'fr_LU'; P: 850), (L: 'fr_MC'; P: 850), (L: 'fr_CH'; P: 850),
    (L: 'ga_IE'; P: 437), (L: 'gd_GB'; P: 850), (L: 'gv_IM'; P: 850),
    (L: 'gl_ES'; P: 850), (L: 'he_IL'; P: 862), (L: 'hr_HR'; P: 852),
    (L: 'hu_HU'; P: 852), (L: 'id_ID'; P: 850), (L: 'is_IS'; P: 850),
    (L: 'it_IT'; P: 850), (L: 'it_CH'; P: 850), (L: 'iv_IV'; P: 437),
    (L: 'ja_JP'; P: 437), (L: 'kk_KZ'; P: 866), (L: 'ko_KR'; P: 437),
    (L: 'ky_KG'; P: 866), (L: 'lt_LT'; P: 775), (L: 'lv_LV'; P: 775),
    (L: 'mk_MK'; P: 866), (L: 'mn_MN'; P: 866), (L: 'ms_BN'; P: 850),
    (L: 'ms_MY'; P: 850), (L: 'nl_BE'; P: 850), (L: 'nl_NL'; P: 850),
    (L: 'nl_SR'; P: 850), (L: 'nn_NO'; P: 850), (L: 'nb_NO'; P: 850),
    (L: 'pl_PL'; P: 852), (L: 'pt_BR'; P: 850), (L: 'pt_PT'; P: 850),
    (L: 'rm_CH'; P: 850), (L: 'ro_RO'; P: 852), (L: 'ru_RU'; P: 866),
    (L: 'sk_SK'; P: 852), (L: 'sl_SI'; P: 852), (L: 'sq_AL'; P: 852),
    (L: 'sr_RS@latin'; P: 852), (L: 'sr_RS'; P: 855), (L: 'sv_SE'; P: 850),
    (L: 'sv_FI'; P: 850), (L: 'sw_KE'; P: 437), (L: 'th_TH'; P: 437),
    (L: 'tr_TR'; P: 857), (L: 'tt_RU'; P: 866), (L: 'uk_UA'; P: 866),
    (L: 'ur_PK'; P: 437), (L: 'uz_UZ@cyrillic'; P: 866), (L: 'uz_UZ'; P: 857),
    (L: 'vi_VN'; P: 437), (L: 'wa_BE'; P: 850), (L: 'zh_HK'; P: 437),
    (L: 'zh_SG'; P: 437), (L: 'zh_MO'; P: 437)
  );

function LocaleOemCodePage(const Loc: ShortString): Integer;
var
  Base, Lang: ShortString;
  I, N: Integer;
begin
  Result := 0;
  Base := Loc;
  N := Pos('.', Base);
  if N > 0 then
  begin
    { "sr_RS.UTF-8@latin": the modifier stays, the encoding goes }
    I := Pos('@', Base);
    if (I > N) then
      Base := Copy(Base, 1, N - 1) + Copy(Base, I, 255)
    else
      Base := Copy(Base, 1, N - 1);
  end;
  if (Base = '') or (Base = 'C') or (Base = 'POSIX') then
    Exit;
  for I := 0 to High(Table) do
    if Table[I].L = Base then
      Exit(Table[I].P);
  { without the modifier, then by the language }
  N := Pos('@', Base);
  if N > 0 then
    Base := Copy(Base, 1, N - 1);
  for I := 0 to High(Table) do
    if Table[I].L = Base then
      Exit(Table[I].P);
  N := Pos('_', Base);
  if N > 0 then
    Lang := Copy(Base, 1, N)
  else
    Lang := Base + '_';
  for I := 0 to High(Table) do
    if Copy(Table[I].L, 1, Length(Lang)) = Lang then
      Exit(Table[I].P);
end;

function HostOemCodePage: Integer;
const
  Names: array[0..2] of string = ('LC_ALL', 'LC_CTYPE', 'LANG');
var
  S: string;
  I: Integer;
begin
  Result := 0;
  { the first variable that says something: "C", "POSIX" and "C.UTF-8" say nothing about a language (a shell may set LC_CTYPE=C.UTF-8
    and LANG=ru_RU.UTF-8 at once) }
  for I := 0 to High(Names) do
  begin
    S := GetEnvironmentVariable(Names[I]);
    if (S = '') or (S = 'C') or (S = 'POSIX') or (Copy(S, 1, 2) = 'C.') then
      Continue;
    Result := LocaleOemCodePage(ShortString(S));
    if Result <> 0 then
      Exit;
  end;
end;

end.
