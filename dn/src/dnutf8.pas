{ DNUtf8: the names of files in UTF-8 inside DN (branch utf8-inside, build option -dDNUTF8).

  The routines of DN that cut and align a name (FormatLongName, AddSpace...) count in bytes: one byte, one column.
  Here a UTF-8 string is turned into a "proxy": every character that is not ASCII becomes one byte #128..#254 (the
  table Tab keeps what the byte stands for), the routine works with the proxy as before, and ProxyToUtf8 turns the
  result back. A byte that is not a part of a UTF-8 character (a name in another code page) stands for itself, so
  nothing is lost. More than 127 different non-ASCII characters in one string: the others become '?'.
  A character is one column here: the wide characters (CJK) and the combining marks are not counted by their width
  yet (dn/TODO-later.md).

  MIT (see LICENSE). }
unit DNUtf8;

interface

function Utf8Chars(const S: String): Integer;
  {` The number of characters (not bytes) of S. `}

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
