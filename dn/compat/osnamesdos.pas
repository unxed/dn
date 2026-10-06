{ OSNamesDos: the names of the files of DN at the border of the DOS (the backend of the facade in OSDep).
  Moved from OSDep (platform separation, stage 3): the code is the same, only the place is new. }
unit OSNamesDos;

{$mode objfpc}
{$H-}

interface

{$IFDEF GO32V2}
var
  { the UTF-8 build for DOS: the provider DOS-UTF8/NAMES is on, the names to and from the DOS are UTF-8 (see DosNamesInit in the initialization of OSDep) }
  DosNamesUtf8: Boolean = False;

{$IFNDEF DNUTF8}
function DosNameToUtf8(const S: string): string;
function DosNameFromUtf8(const S: string): string;
{$ENDIF}
procedure DosNamesInit;
{$ENDIF}

implementation

{$IFDEF GO32V2}
uses
  SysUtils, TvDos, TvCodePg, TvUtf8, DNErrLog;

{$IF DEFINED(GO32V2) AND NOT DEFINED(DNUTF8)}
{ The build for DOS with the code page inside (the text of DN is bytes of the page of the screen, the resources are landed on it): when the DOS has the
  provider DOS-UTF8/NAMES and it is on for this process (DosNamesInit), the names go to the DOS and come back in UTF-8, so DN turns them at this border.
  A name that the page cannot show (a Japanese one on cp866) comes as the UTF-8 bytes, stays so inside and goes back unchanged: it is told by being valid UTF-8
  with a character that the page lacks. }
function Utf8Chars(const S: string; var Lost: Boolean): Boolean;     { False: not valid UTF-8; Lost: a character that the page lacks }
var
  I, Used: Integer;
  CP: LongWord;
begin
  Result := True;
  Lost := False;
  I := 1;
  while I <= Length(S) do
    if Byte(S[I]) < $80 then
      Inc(I)
    else
    begin
      if not Utf8Decode(@S[I], Length(S) - I + 1, CP, Used) then
        Exit(False);
      if CpFromUnicode(CP) = 0 then
        Lost := True;
      Inc(I, Used);
    end;
end;

function DosNameToUtf8(const S: string): string;
var
  I, J, N: Integer;
  Buf: array[0..7] of Byte;
  Lost: Boolean;
begin
  Result := S;
  if not DosNamesUtf8 then
    Exit;
  Lost := False;
  if Utf8Chars(S, Lost) and Lost then
    Exit;                          { the UTF-8 bytes of a name that came from the DOS and has a character outside the page }
  Result := '';
  for I := 1 to Length(S) do
    if Byte(S[I]) < $80 then
      Result := Result + S[I]
    else
    begin
      N := Utf8Encode(CpToUnicode(Byte(S[I])), @Buf[0]);
      for J := 0 to N - 1 do
        Result := Result + Chr(Buf[J]);
    end;
end;

function DosNameFromUtf8(const S: string): string;
var
  I, Used: Integer;
  CP: LongWord;
  Lost: Boolean;
begin
  Result := S;
  if not DosNamesUtf8 then
    Exit;
  Lost := False;
  if not Utf8Chars(S, Lost) or Lost then
    Exit;                          { not UTF-8, or not all of it can be shown on the page: as it is }
  Result := '';
  I := 1;
  while I <= Length(S) do
    if Byte(S[I]) < $80 then
    begin
      Result := Result + S[I];
      Inc(I);
    end
    else
    begin
      Utf8Decode(@S[I], Length(S) - I + 1, CP, Used);
      Result := Result + Chr(CpFromUnicode(CP));
      Inc(I, Used);
    end;
end;
{$ENDIF}

{$IFDEF GO32V2}
{ The names of the files are UTF-8 inside DN in the UTF-8 build for DOS, so the DOS must give and take them in UTF-8: the provider DOS-UTF8/NAMES of AMIS (go2dos,
  DOSBox-X with the patches) is switched on for this process (UTF8NAMES.md of go2dos). Without the provider the names are what the DOS gives (the bytes of the code page:
  shown as such, since invalid UTF-8 is taken as the code page by tv/; a new name typed with characters outside ASCII is then wrong): DN_DOS_UTF8_NAMES=0 leaves it so. }
procedure DosNamesInit;
var
  Mux: Byte;
begin
  DosNamesUtf8 := False;
  if GetEnvironmentVariable('DN_DOS_UTF8_NAMES') = '0' then
    Exit;
  if AmisFind('DOS-UTF8', 'NAMES   ', Mux) then
    DosNamesUtf8 := AmisSetEncoding(Mux, 65001);
  DNTrace('DOS UTF-8 names: ' + BoolToStr(DosNamesUtf8, True));
end;
{$ENDIF}
{$ENDIF}

end.
