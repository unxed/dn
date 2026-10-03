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

procedure CpBytesToUtf8(var S: String; From: Integer);
  {` The bytes $80 and up of S from the position From on are the bytes of the current code page: they become UTF-8 (one character each, so the
  columns do not change). Used for a text that DN has put through a code table; does nothing without -dDNUTF8. `}

function CpCharToUtf8(B: Byte): String;
  {` The character of the code page with the byte B (the key of the keyboard of DN) in UTF-8; ASCII stays. `}
procedure Utf8DeleteLast(var S: String);
  {` Removes the last character of the UTF-8 string S (not a byte). `}

function HotMatches(const Name: String; At: Integer; Ch: Char): Boolean;
  {` Is the hot letter of a menu item (the character of Name at At, which may be UTF-8) the key Ch, the character of the code page that DN
  takes from the keyboard (CharCode)? The case does not matter. `}

{ --- the table of a document of the editor ---------------------------------------------------------------------
  The editor of DN works on one byte per column. With UTF-8 inside, a document has a table: the byte $80..$FF of its lines (the internal text)
  stands for a character. The table starts as the current code page (so a Cyrillic letter has the same byte as in the code page of DN, the keyboard
  gives that byte, the tables of DN fit); the characters of the document that the page does not have take the cells of the frame characters
  ($B0..$DF of 866: U+2500..U+259F) that the document does not use. The file keeps UTF-8; the table is made when the file is read. }
type
  TDocTab = record
    Cp: array[128..255] of LongWord;          { the character of the byte }
    Seen: array[0..191] of LongWord;          { the characters of the document that are not ASCII (before TabBuild) }
    SeenN: Integer;
    Over: Boolean;                            { more different characters than the table can have }
    Used: array[128..255] of Boolean;         { the cells that the text has (or had): a frame cell that is not Used can be given to a rare character }
  end;

type
  TCaseTab = array[0..255] of Byte;

procedure TabCase(const T: TDocTab; var Up, Low, Tog: TCaseTab);
  {` The tables of the case of the internal bytes of a document: Up and Low give the byte of the capital and the small letter (the byte itself when
  the document has no such letter), Tog the other case. `}

function Utf8CharsL(const S: AnsiString): LongInt;
  {` The number of characters of a long UTF-8 string (the bytes that are not continuation bytes). `}
procedure TabNatural(var T: TDocTab);
  {` The table of the current code page, nothing seen. `}
procedure TabMark(var T: TDocTab; B: Byte);
  {` The byte B is typed or pasted as it is: its cell is used. `}
function TabSee(var T: TDocTab; const S: AnsiString): Boolean;
  {` The non-ASCII characters of the UTF-8 line S are noted; False when S is not UTF-8. `}
function TabBuild(var T: TDocTab): Boolean;
  {` The cells for the noted characters; False when they do not fit. `}
function TabToInternal(var T: TDocTab; const S: AnsiString; Alloc: Boolean): AnsiString;
  {` The UTF-8 line S as the internal line (one byte per character). A character that the table does not have takes a free cell when Alloc,
  else '?'. `}
function TabToUtf8(const T: TDocTab; const S: AnsiString): AnsiString;
  {` The internal line as UTF-8. `}
function TabTyped(var T: TDocTab; const Text: ShortString; Def: Byte): Byte;
  {` The byte of a typed character (the UTF-8 text of a key event) in the table of the document: the cell it has or a free one; Def when the text is
  ASCII (or empty), 0 when the table has no cell for it. `}

function Utf8ToProxy(const S: String; var Tab: String): String;
  {` S with each non-ASCII character as one byte #128+i; Tab[i+1] is that character (its bytes). `}

function ProxyToUtf8(const S, Tab: String): String;
  {` The reverse of Utf8ToProxy: the bytes #128+i of S become Tab[i+1]. `}

implementation

uses
  TvUtf8, TvCodePg;

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

procedure CpBytesToUtf8(var S: String; From: Integer);
{$IFDEF DNUTF8}
  var
    I, N: Integer;
    R: String;
    Buf: array[0..7] of Byte;
  begin
  if From < 1 then
    From := 1;
  R := Copy(S, 1, From - 1);
  for I := From to Length(S) do
    if Byte(S[I]) < $80 then
      R := R + S[I]
    else
      begin
      N := CpToUtf8(Byte(S[I]), @Buf[0]);
      if Length(R) + N > 255 then
        Break;
      R := R + Copy(PChar(@Buf[0]), 1, N);
      end;
  S := R;
  end;
{$ELSE}
  begin
  end;
{$ENDIF}

function CpCharToUtf8(B: Byte): String;
  var
    Buf: array[0..7] of Byte;
    N: Integer;
  begin
  if B < $80 then
    Exit(Chr(B));
  N := CpToUtf8(B, @Buf[0]);
  SetString(Result, PChar(@Buf[0]), N);
  end;

procedure Utf8DeleteLast(var S: String);
  var
    L: Integer;
  begin
  L := Length(S);
  if L = 0 then
    Exit;
  while (L > 1) and ((Byte(S[L]) and $C0) = $80) do
    Dec(L);
  SetLength(S, L - 1);
  end;

function HotMatches(const Name: String; At: Integer; Ch: Char): Boolean;
  var
    Cp, Cp2: LongWord;
    Used: Integer;
  begin
  Result := False;
  if (At < 1) or (At > Length(Name)) then
    Exit;
  if  Byte(Name[At]) < $80 then
    begin
    Result := (Byte(Ch) < $80) and (CpUpper(Byte(Name[At])) = CpUpper(Byte(Ch)));
    Exit;
    end;
  if  (Byte(Ch) >= $80) and Utf8Decode(@Name[At], Length(Name) - At + 1, Cp, Used) and (Used > 1) then
    begin
    Cp2 := CpToUnicode(Byte(Ch));
    Result := CpUpper(Cp) = CpUpper(Cp2);
    end;
  end;

procedure TabCase(const T: TDocTab; var Up, Low, Tog: TCaseTab);
  var
    B, X: Integer;
    function Find(Cp: LongWord): Integer;
      var
        K: Integer;
      begin
      for K := 128 to 255 do
        if T.Cp[K] = Cp then
          Exit(K);
      Result := -1;
      end;
  begin
  for B := 0 to 255 do
    begin
    Up[B] := B;
    Low[B] := B;
    Tog[B] := B;
    end;
  for B := Ord('a') to Ord('z') do
    begin
    Up[B] := B - 32;
    Low[B - 32] := B;
    Tog[B] := B - 32;
    Tog[B - 32] := B;
    end;
  for B := 128 to 255 do
    begin
    X := Find(CpUpper(T.Cp[B]));
    if (X >= 0) and (X <> B) then
      begin
      Up[B] := X;
      Low[X] := B;
      Tog[B] := X;
      Tog[X] := B;
      end;
    end;
  end;

function Utf8CharsL(const S: AnsiString): LongInt;
  var
    I: LongInt;
  begin
  Result := 0;
  for I := 1 to Length(S) do
    if (Byte(S[I]) and $C0) <> $80 then
      Inc(Result);
  end;

procedure TabNatural(var T: TDocTab);
  var
    B: Integer;
  begin
  for B := 128 to 255 do
    T.Cp[B] := CpToUnicode(B);
  T.SeenN := 0;
  T.Over := False;
  FillChar(T.Used, SizeOf(T.Used), 0);
  end;

procedure TabMark(var T: TDocTab; B: Byte);
  begin
  if B >= 128 then
    T.Used[B] := True;
  end;

function TabHas(const T: TDocTab; Cp: LongWord): Integer;
  var
    B: Integer;
  begin
  if Cp < $80 then
    Exit(Integer(Cp));
  for B := 128 to 255 do
    if T.Cp[B] = Cp then
      Exit(B);
  Result := -1;
  end;

function TabSee(var T: TDocTab; const S: AnsiString): Boolean;
  var
    I, K: Integer;
    Cp: LongWord;
    Used: Integer;
  begin
  Result := True;
  I := 1;
  while I <= Length(S) do
    begin
    if  Byte(S[I]) < $80 then
      begin
      Inc(I);
      Continue;
      end;
    if not (Utf8Decode(@S[I], Length(S) - I + 1, Cp, Used) and (Used > 1)) then
      Exit(False);
    Inc(I, Used);
    K := 0;
    while (K < T.SeenN) and (T.Seen[K] <> Cp) do
      Inc(K);
    if K = T.SeenN then
      if T.SeenN > High(T.Seen) then
        T.Over := True
      else
        begin
        T.Seen[K] := Cp;
        Inc(T.SeenN);
        end;
    end;
  end;

function TabIsFrame(Cp: LongWord): Boolean;
  begin
  Result := (Cp >= $2500) and (Cp <= $259F);
  end;

function TabFreeCell(var T: TDocTab; const Used: array of Boolean): Integer;
  var
    B: Integer;
  begin
  for B := 128 to 255 do
    if  TabIsFrame(T.Cp[B]) and not Used[B - 128] then
      Exit(B);
  Result := -1;
  end;

function TabBuild(var T: TDocTab): Boolean;
  var
    I, B: Integer;
    Used: array[0..127] of Boolean;
  begin
  Result := not T.Over;
  if T.Over then
    Exit;
  FillChar(Used, SizeOf(Used), 0);
  { the cells of the characters that the document has already (the table is the page) }
  for I := 0 to T.SeenN - 1 do
    begin
    B := TabHas(T, T.Seen[I]);
    if B >= 0 then
      Used[B - 128] := True;
    end;
  for I := 0 to T.SeenN - 1 do
    if TabHas(T, T.Seen[I]) < 0 then
      begin
      B := TabFreeCell(T, Used);
      if B < 0 then
        Exit(False);
      T.Cp[B] := T.Seen[I];
      Used[B - 128] := True;
      end;
  for B := 128 to 255 do
    if Used[B - 128] then
      T.Used[B] := True;
  T.SeenN := 0;
  end;

function TabToInternal(var T: TDocTab; const S: AnsiString; Alloc: Boolean): AnsiString;
  var
    I, B, K: Integer;
    Cp: LongWord;
    Used: Integer;
    Taken: array[0..127] of Boolean;
  begin
  Result := '';
  I := 1;
  while I <= Length(S) do
    begin
    if  Byte(S[I]) < $80 then
      begin
      Result := Result + S[I];
      Inc(I);
      Continue;
      end;
    if  Utf8Decode(@S[I], Length(S) - I + 1, Cp, Used) and (Used > 1) then
      begin
      B := TabHas(T, Cp);
      if (B < 0) and Alloc then
        begin
        { a free cell: a frame cell that no character of the text needs: here the cells are found by what the table has now }
        for K := 128 to 255 do
          Taken[K - 128] := T.Used[K] or not TabIsFrame(T.Cp[K]) or (T.Cp[K] <> CpToUnicode(K));
        B := TabFreeCell(T, Taken);
        if B >= 0 then
          T.Cp[B] := Cp;
        end;
      if B >= 0 then
        T.Used[B] := True;
      if B < 0 then
        Result := Result + '?'
      else
        Result := Result + Chr(B);
      Inc(I, Used);
      end
    else
      begin
      Result := Result + '?';
      Inc(I);
      end;
    end;
  end;

function TabTyped(var T: TDocTab; const Text: ShortString; Def: Byte): Byte;
  var
    R: AnsiString;
  begin
  Result := Def;
  if (Length(Text) = 0) or (Byte(Text[1]) < $80) then
    Exit;
  Result := 0;
  R := TabToInternal(T, Copy(Text, 1, Length(Text)), True);
  if (Length(R) = 1) and (Byte(R[1]) >= $80) then
    Result := Byte(R[1]);
  end;

function TabToUtf8(const T: TDocTab; const S: AnsiString): AnsiString;
  var
    I, N: Integer;
    Buf: array[0..7] of Byte;
  begin
  Result := '';
  for I := 1 to Length(S) do
    if Byte(S[I]) < $80 then
      Result := Result + S[I]
    else
      begin
      N := Utf8Encode(T.Cp[Byte(S[I])], @Buf[0]);
      Result := Result + Copy(PChar(@Buf[0]), 1, N);
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
