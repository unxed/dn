{ DNUtf8: the names of files in UTF-8 inside DN (branch utf8-inside, build option -dDNUTF8).

  The routines of DN that cut and align a name (FormatLongName, AddSpace...) count in bytes: one byte, one column.
  Here a UTF-8 string is turned into a "proxy": every character that is not ASCII becomes one byte #128..#254 (the
  table Tab keeps what the byte stands for), the routine works with the proxy as before, and ProxyToUtf8 turns the
  result back. A byte that is not a part of a UTF-8 character (a name in another code page) stands for itself, so
  nothing is lost. More than 127 different non-ASCII characters in one string: the others become '?'.
  A character is one column here: the wide characters (CJK) and the combining marks are not counted by their width
  yet (dn/TODO-later.md).

  This unit is our own code (MIT, see LICENSE). }
unit DNUtf8;

interface

function Utf8Chars(const S: String): Integer;
  {` The number of characters (not bytes) of S. `}

function StrCols(const S: String): Integer;
  {` The width of S in columns: characters with -dDNUTF8, else bytes (a name is shown in one byte per column). `}

function CpUpper(C: LongWord): LongWord;
function CpLower(C: LongWord): LongWord;
  {` The case of a character (the code point): ASCII, Latin-1, Latin Extended-A, Greek, Cyrillic. The others stay as they are. `}

procedure Utf8UpStr(var S: String);
procedure Utf8LowStr(var S: String);
  {` The case of a UTF-8 string, character by character (a byte that is not UTF-8 stays as it is). `}

function Utf8ToProxy(const S: String; var Tab: String): String;
  {` S with each non-ASCII character as one byte #128+i; Tab[i+1] is that character (its bytes). `}

function ProxyToUtf8(const S, Tab: String): String;
  {` The reverse of Utf8ToProxy: the bytes #128+i of S become Tab[i+1]. `}

implementation

uses
  TvUtf8;

function CharLen(const S: String; I: Integer): Integer;
  var
    Cp: LongWord;
    Used: Integer;
  begin
  if  (Byte(S[I]) >= $80) and Utf8Decode(@S[I], Length(S) - I + 1, Cp, Used) then
    Result := Used
  else
    Result := 1;
  end;

function StrCols(const S: String): Integer;
  begin
{$IFDEF DNUTF8}
  Result := Utf8Chars(S);
{$ELSE}
  Result := Length(S);
{$ENDIF}
  end;

function Utf8Chars(const S: String): Integer;
  var
    I: Integer;
  begin
  Result := 0;
  I := 1;
  while I <= Length(S) do
    begin
    Inc(I, CharLen(S, I));
    Inc(Result);
    end;
  end;

function CpUpper(C: LongWord): LongWord;
  begin
  Result := C;
  case C of
    $61..$7A: Result := C - 32;
    $E0..$F6, $F8..$FE: Result := C - 32;
    $FF: Result := $178;
    $100..$137, $14A..$177: if Odd(C) then Result := C - 1;
    $139..$148, $179..$17E: if not Odd(C) then Result := C - 1;
    $3AC: Result := $386;
    $3AD..$3AF: Result := C - 37;
    $3B1..$3C1, $3C3..$3CB: Result := C - 32;
    $3C2: Result := $3A3;
    $430..$44F: Result := C - 32;
    $450..$45F: Result := C - 80;
    $460..$481, $48A..$4BF, $4D0..$4FF: if Odd(C) then Result := C - 1;
  end;
  end;

function CpLower(C: LongWord): LongWord;
  begin
  Result := C;
  case C of
    $41..$5A: Result := C + 32;
    $C0..$D6, $D8..$DE: Result := C + 32;
    $178: Result := $FF;
    $100..$137, $14A..$177: if not Odd(C) then Result := C + 1;
    $139..$148, $179..$17E: if Odd(C) then Result := C + 1;
    $386: Result := $3AC;
    $388..$38A: Result := C + 37;
    $391..$3A1, $3A3..$3AB: Result := C + 32;
    $410..$42F: Result := C + 32;
    $400..$40F: Result := C + 80;
    $460..$481, $48A..$4BF, $4D0..$4FF: if not Odd(C) then Result := C + 1;
  end;
  end;

procedure Utf8Case(var S: String; Up: Boolean);
  var
    I, L, N: Integer;
    Cp, Cp2: LongWord;
    Used: Integer;
    R: String;
    Buf: array[0..7] of Byte;
  begin
  R := '';
  I := 1;
  while I <= Length(S) do
    begin
    if  Byte(S[I]) < $80 then
      begin
      if Up then
        R := R + Chr(CpUpper(Byte(S[I])))
      else
        R := R + Chr(CpLower(Byte(S[I])));
      Inc(I);
      Continue;
      end;
    L := CharLen(S, I);
    if  (L > 1) and Utf8Decode(@S[I], Length(S) - I + 1, Cp, Used) then
      begin
      if Up then
        Cp2 := CpUpper(Cp)
      else
        Cp2 := CpLower(Cp);
      N := Utf8Encode(Cp2, @Buf[0]);
      for L := 0 to N - 1 do
        R := R + Chr(Buf[L]);
      Inc(I, Used);
      end
    else
      begin
      R := R + S[I];
      Inc(I);
      end;
    end;
  if Length(R) <= 255 then
    S := R;
  end;

procedure Utf8UpStr(var S: String);
  begin
  Utf8Case(S, True);
  end;

procedure Utf8LowStr(var S: String);
  begin
  Utf8Case(S, False);
  end;

function Utf8ToProxy(const S: String; var Tab: String): String;
  var
    I, L, K, N: Integer;
    C: String[4];
  begin
  Result := '';
  Tab := '';
  N := 0;
  I := 1;
  while I <= Length(S) do
    begin
    if  Byte(S[I]) < $80 then
      begin
      Result := Result + S[I];
      Inc(I);
      Continue;
      end;
    L := CharLen(S, I);
    C := Copy(S, I, L);
    Inc(I, L);
    K := 0;
    while (K < N) and (Copy(Tab, K * 4 + 1, 4) <> C + Copy('    ', 1, 4 - Length(C))) do
      Inc(K);
    if  K = N then
      begin
      if  N >= 127 then
        begin
        Result := Result + '?';
        Continue;
        end;
      Tab := Tab + C + Copy('    ', 1, 4 - Length(C));
      Inc(N);
      end;
    Result := Result + Char($80 + K);
    end;
  end;

function ProxyToUtf8(const S, Tab: String): String;
  var
    I, K: Integer;
    C: String;
  begin
  Result := '';
  for I := 1 to Length(S) do
    if  (Byte(S[I]) < $80) or (Byte(S[I]) - $80 >= Length(Tab) div 4) then
      Result := Result + S[I]
    else
      begin
      K := (Byte(S[I]) - $80) * 4;
      C := Copy(Tab, K + 1, 4);
      while (Length(C) > 0) and (C[Length(C)] = ' ') do
        SetLength(C, Length(C) - 1);
      Result := Result + C;
      end;
  end;

end.
