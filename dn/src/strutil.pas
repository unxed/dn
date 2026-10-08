{/////////////////////////////////////////////////////////////////////////
//
//  Dos Navigator Open Source 1.51.08
//  Based on Dos Navigator (C) 1991-99 RIT Research Labs
//
//  This programs is free for commercial and non-commercial use as long as
//  the following conditions are aheared to.
//
//  Copyright remains RIT Research Labs, and as such any Copyright notices
//  in the code are not to be removed. If this package is used in a
//  product, RIT Research Labs should be given attribution as the RIT Research
//  Labs of the parts of the library used. This can be in the form of a textual
//  message at program startup or in documentation (online or textual)
//  provided with the package.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are
//  met:
//
//  1. Redistributions of source code must retain the copyright
//     notice, this list of conditions and the following disclaimer.
//  2. Redistributions in binary form must reproduce the above copyright
//     notice, this list of conditions and the following disclaimer in the
//     documentation and/or other materials provided with the distribution.
//  3. All advertising materials mentioning features or use of this software
//     must display the following acknowledgement:
//     "Based on Dos Navigator by RIT Research Labs."
//
//  THIS SOFTWARE IS PROVIDED BY RIT RESEARCH LABS "AS IS" AND ANY EXPRESS
//  OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
//  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE FOR
//  ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
//  GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
//  IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
//  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
//  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//  The licence and distribution terms for any publically available
//  version or derivative of this code cannot be changed. i.e. this code
//  cannot simply be copied and put under another distribution licence
//  (including the GNU Public Licence).
//
//////////////////////////////////////////////////////////////////////////}
{$I STDEFINE.INC}
{AK155 = Alexey Korop, 2:461/155@fidonet}
{Cat = Aleksej Kozlov, 2:5030/1326.13@fidonet}

{Cat
   28/08/2001 - reworked many existing functions for AnsiString
   compatibility; added similar functions that work with LongString
   16/01/2002 - buffer string search functions now take LongInt
   parameters instead of Word
}

unit strutil; {String functions}

interface

uses
  Defines, Dos {Cat}
  ;

var
 {The following three tables are used instead of XlatCP for "recoding"
  Ascii-Ascii (see the first KeyMapDescr elements). Therefore all three
  must be present, and in exactly this order. }
  UpCaseArray: TXlat;
    {` Convert to upper case in ASCII`}
  NullXlatTable: TXlat;
    {` Identity recoding `}
  NullXlatTable1: TXlat;

  LowCaseArray: TXlat;
    {` Convert to lower case in ASCII`}

function NewStr(const S: String): PString;
function NewLongStr(const S: LongString): PLongString;
procedure DisposeStr(var P: PString);
procedure DisposeLongStr(var P: PLongString);
procedure ReplaceP(var P: PString; S: String);
function CnvString(P: PString): String; {conversion: PString to String}
function CnvLongString(P: PLongString): LongString;
{conversion: PLongString to LongString}
function StrGrd(AMax, ACur: TSize; Wide: Byte; Rev: Boolean): String;
function Percent(AMax, ACur: TSize): String;
  {` Build a string like 57%; length is as it comes out. `}
procedure Hex8Lo(L: LongInt; var HexLo);
procedure AddStr(var S: String; C: Char);
{procedure DelFC(var s:String);}

{---  ' '-related string functions }
function CenterStr(const s: String; n: Byte): String; {DataCompBoy}
function AddSpace(const s: String; n: Byte): String;
function LongAddSpace(const s: LongString; n: LongInt): LongString;
function PredSpace(s: String; n: Byte): String;
function DelSpaces(s: String): String;
procedure DelSpace(var s: String);
procedure DelRight(var S: String);
procedure LongDelRight(var S: LongString);
function fDelRight(s: String): String;
procedure DelLeft(var S: String);
procedure LongDelLeft(var S: LongString);
function fDelLeft(s: String): String;

function Cut(p: String; len: Integer): String;
function CutH(p: String; len: Integer): String;
function CutCols(const S: String; Width: Integer; Rest: Char): String;
  {` S as a field of Width columns: padded with blanks, or cut with Rest as its last column (UTF-8 inside: a column is a character, not a byte) `}

function Strg(C: Char; Num: Byte): String;
  {` Create a string of length Num filled with character C `}

function LongStrg(C: Char; Num: LongInt): LongString;
  {` Create a string of length Num filled with character C `}

{case functions}
function UpCase(c: Char): Char;

procedure UpStr(var s: String);
function UpStrg(s: String): String;

function LowCase(c: Char): Char;
procedure LowStr(var s: String);
function LowStrg(s: String): String;

procedure UpLowStr(var s: String); {JO}
function UpLowStrg(s: String): String; {JO}

procedure CapStr(var S: String);
procedure CapLongStr(var S: LongString; First, Last: Integer);
function CapStrg(S: String): String;
function CapLongStrg(const S: LongString; First, Last: Integer): LongString;

{procedure MakeCase(CaseSensitive: Boolean);}

function ItoS(a: LongInt): String;
function ZtoS(a: TSize): String;
function RtoS(a: Real; M, F: Integer): String;
function StoI(const s: String): LongInt;
function SStr(a: LongInt; B: Byte; C: Char): String;
function SSt2(a: LongInt; B: Byte; C: Char): String;
function FStr(a: TSize): String;
  {` String representation of a size.
    Result length is at most 12 characters, no leading spaces.
    Triads are separated according to country settings `}
function FileSizeStr(X: TSize): String;
  {` String representation of a file length.
    Result length is 9 characters, right-aligned.
    Triads are separated according to country settings `}
function Hex2(a: Byte): Str2;
function Hex4(a: Word): Str4;
function Hex8(a: LongInt): Str8;
function HexFilePos(C: Int64): String;
  {`9 hex digits`}
function HexChar(a: Byte): Char;
function Replace(const Pattern, ReplaceString: String; var S: String)
  : Boolean;
function Dec2(w: Word): Str2;
  {` Exactly two decimal digits (low-order) `}
function fReplace(const SubFrom, SubTo: String; S: String): String;
function PosChar(C: Char; const S: String): Byte;
function CharCount(C: Char; const S: String): Byte; {DataCompBoy}
function SecToStr(t: Word): String;
  {` time, with time separator, result like 12:34:56 `}
function FormatTimeStr(H, M, SS: Word): String; {DataCompBoy}
  {` time, with format and time separator; result may
   be like 01:23:45pm `}
function FormatDateTime(const DT: DateTime; Time: Boolean): String; {cat}
procedure MakeCurrency(R: Real; var S: String);
function GetDateTime(Time: Boolean): String;
function Real2Str(X: Real; n: Byte): String;
function Long2Str(X: LongInt; l: Byte): String;
function Long0Str(X: LongInt; l: Byte): String;
function ToHex(I: Word): String;
procedure DelDoubles(const St: String; var Source: String);
procedure AnsiDelDoubles(const St: String; var Source: AnsiString);
procedure LongDelDoubles(const St: LongString; var Source: LongString);
procedure MakeDate(const Day, Month, Year, Hour, Min: Word;
     var S: String);
procedure MakeDateFull(const Day, Month: Word; {-$VOL moidfied}
    Year, Hour: Word;
    const Min: Word;
    var S: String;
    const YFull: Boolean);

function DumpStr
  {` Build Hex+Text representation with a 9-digit
     address on the left. First Hex character is S[12]`}
  (var B; Addr: Int64; Count: Integer; Filter: Byte): String;

function MemEqual(var Buf1; var Buf2; Len: Word): Boolean;

type
  BMTable = array[0..255] of Byte;
   {` Boyer-Moore index-table data definition. `}

procedure Create_BMTable
    ( {output} var BMT: BMTable;
    {input/output} var Pattern: String;
    ExactCase: Boolean);

procedure Create_BackBMTable
    ( {output} var BMT: BMTable;
    {input/output} var Pattern: String;
    ExactCase: Boolean);

function BMsearch(
{` Boyer-Moore Search function. Result is the 1-based index
    of the start of the found text, or 0 if not found }
    const BMT: BMTable;
      {` must be built in advance `}
    var Buffer;
    BuffSize: LongInt;
    const Pattern: String;
    const UpXlatArray: TXlat
    {` combines recoding from Buffer encoding to ASCII and
     uppercasing (if needed). In the simplest case, when
     case-sensitive ASCII search is needed, this is NullXlatTAble`}
    ): LongInt;
{`}

function BackBMsearch(
{` Boyer-Moore Search function. Made from BMsearch}
    const BMT: BMTable;
    var Buffer;
    BuffSize: LongInt;
    const Pattern: String;
    const UpXlatArray: TXlat
    ): LongInt;
{`}

function BackSearchForAllCP(S: String; var B; l: LongInt;
     CaseSensitive: Boolean): LongInt; {-$VIV 14.05.99}

function SearchForAllCP(S: String; var B; l: LongInt;
     CaseSensitive: Boolean): LongInt;

procedure CompressString(var S: LongString);
{AK155}
function PosLastDot(StrToMake: String): Byte;
  {` Position of the extension dot. If no extension - length plus 1 `}
function IsDummyDir(const DirName: String): Boolean;
procedure CopyShortString(const s1, s2: ShortString);
  {` Copies a string according to its length, regardless of how
  the destination string is declared. Used to copy a long
  name into TFileRec, which syntactically has length 12, but
  actually continues in the Dummy field`}
{/AK155}

function SPos(SubStr, S: String; Start: Integer): Integer;
  {` Analog of Pos, but search starts at S[Start] `}

function MinBufSize(x: TFileSize; y: LongInt): LongInt;
  {` The lesser of file size and buffer size `}

function Positive(x: TFileSize): TFileSize;
  {` File size, clamped below at zero `}

function i32(x: TFileSize): LongInt;


function CompToFSize(x: Int64): TFileSize;
  {` Int64 -> TFileSize `}

function FSizeMod(x: TFileSize; y: LongInt): LongInt;


function Str2Comp(const s: String): Int64;

implementation

uses DnPath,
  DnIni, Startup, Commands, basics, keymap, DNUtf8, TvGlyphs
  ;
procedure AddStr(var S: String; C: Char);
  
  begin
  S := S+C
  end; {Cat}

function UpCase(c: Char): Char;
{AK155}
  
  begin
  UpCase := UpCaseArray[C]
  end;

function LowCase(c: Char): Char;
{AK155}
  
  begin
  LowCase := LowCaseArray[C]
  end;

function i32(x: TFileSize): LongInt;
  {` TFileSize -> LongInt `}

  
  begin
  Result := x;
  end;

function FSizeMod(x: TFileSize; y: LongInt): LongInt;
  {` Remainder of x divided by y `}

  
  begin
  Result := x mod y;
  end;


function Dec2(w: Word): Str2;
  begin
  w := abs(w) mod 100;
  Result := HexChar(w div 10) + HexChar(w mod 10);
  end;

function StrGrd(AMax, ACur: TSize; Wide: Byte; Rev: Boolean): String;
  var
    A: Byte;
  begin
  if AMax = 0 then
    A := Wide
  else
    A := Round((ACur*Wide)/AMax);
  if Rev then
    StrGrd := Strg(GlyphChar(glShadeMedium), Wide-A)+Strg(GlyphChar(glBlockFull), A)
  else
    StrGrd := Strg(GlyphChar(glBlockFull), A)+Strg(GlyphChar(glShadeMedium), Wide-A);
  end;

function Percent(AMax, ACur: TSize): String;
  begin
  if AMax = 0 then
    Percent := {0}'100%' {AK155}
  else
    Percent := ItoS(Trunc((ACur*100)/AMax)) + '%';
  end;

procedure Hex8Lo(L: LongInt; var HexLo);
  
  type
    ChArr = array[1..8] of Char;
  var
    i: integer;
  begin { Hex8Lo }
  for i := 1 to 8 do ChArr(HexLo)[i] := HexStr[L shr (32-(i*4)) and $F];
  end { Hex8Lo };


{Cat: I think it's simpler... this is just System.Delete(s, 1, 1)... threw it out}
(*
procedure DelFC(var s:String);
begin
  if Length(s) > 0 then
    begin
      Move(s[2], s[1], Length(s)-1);
      SetLength(s, Length(s)-1)
    end;
end;
*)

function CenterStrB(const s: String; n: Byte): String;
  begin
  if Length(s) >= n then
    CenterStrB := Copy(s, 1, n)
  else
    CenterStrB := Copy(Strg(#32, (n-Length(s)) div 2)+s+Strg(#32,
               (n-Length(s)) div 2+1), 1, n);
  end;

function CenterStr(const s: String; n: Byte): String;
{$IFDEF DNUTF8}
  var
    Tab: String;
  begin
  Result := ProxyToUtf8(CenterStrB(Utf8ToProxy(s, Tab), n), Tab);
  end;
{$ELSE}
  begin
  Result := CenterStrB(s, n);
  end;
{$ENDIF}

function AddSpaceB(const s: String; n: Byte): String;
  
  var
    s2: String;
  begin { AddSpace }
  s2 := s;
  if Length(s) < n then
    begin
    FillChar(s2[Length(s2)+1], n-Length(s2), ' ');
    s2[0] := Char(n);
    end;
  AddSpaceB := s2;
  end { AddSpace };

function AddSpace(const s: String; n: Byte): String;
{$IFDEF DNUTF8}
  var
    Tab: String;
  begin
  Result := ProxyToUtf8(AddSpaceB(Utf8ToProxy(s, Tab), n), Tab);
  end;
{$ELSE}
  begin
  Result := AddSpaceB(s, n);
  end;
{$ENDIF}


function CutCols(const S: String; Width: Integer; Rest: Char): String;
{$IFDEF DNUTF8}
  var
    Tab, P: String;
  begin
  P := Utf8ToProxy(S, Tab);
  if Length(P) > Width then
    begin
    SetLength(P, Width);
    if Width > 0 then
      P[Width] := Rest;
    end
  else
    P := AddSpaceB(P, Width);
  Result := ProxyToUtf8(P, Tab);
  end;
{$ELSE}
  begin
  if Length(S) > Width then
    begin
    Result := Copy(S, 1, Width);
    if Width > 0 then
      Result[Width] := Rest;
    end
  else
    Result := AddSpaceB(S, Width);
  end;
{$ENDIF}


{Cat}
function LongAddSpace(const s: LongString; n: LongInt): LongString;
  var
    s2: LongString;
    L: LongInt;
  begin
  s2 := s;
  L := Length(s);
  if L < n then
    begin
    SetLength(s2, n);
    FillChar(s2[L+1], n-L, ' ');
    end;
  LongAddSpace := s2;
  end;
{/Cat}

function PredSpace(s: String; n: Byte): String;
  begin
  if Length(s) >= n then
    PredSpace := s
  else
    begin
    FillChar(FreeStr[1], 255, ' ');
    Move(s[1], FreeStr[Succ(n-Length(s))], Length(s));
    SetLength(FreeStr, n);
    PredSpace := FreeStr
    end
  end;

procedure DelSpace(var s: String);
  
  var
    a, b, j: Byte;
  begin { DelSpace }
  if s = '' then
    Exit;
  b := 1;
  j := Length(s);
  s[0] := #0;
  for a := 1 to j do
    if not (s[a] in [' ', #9]) then
      begin
      s[b] := s[a];
      Inc(s[0]);
      Inc(b);
      end;
  end { DelSpace };


function DelSpaces(s: String): String;
  begin
  DelSpace(s);
  DelSpaces := s;
  end;

procedure DelRight(var S: String);
  
  var
    L: Byte absolute S;
  begin
  while L > 0 do
    begin
    if S[L] <> ' ' then
      Break;
    Dec(L);
    end;
  end { DelRight };


procedure LongDelRight(var S: LongString);
  var
    I, I0: LongInt;
  begin
  I := Length(S);
  I0 := I;
  while (I > 0) and (S[I] = ' ') do
    Dec(I);
  if I0 <> I then
    SetLength(S, I);
  end;

function fDelRight(s: String): String;
  begin
  DelRight(s);
  fDelRight := s
  end;

procedure DelLeft(var S: String);
  
  var
    I: Byte;
    SL: Byte absolute S;
  begin { DelLeft }
  I := 1;
  while (SL >= I) and (S[I] in [#9, ' ']) do
    Inc(I);
  if I > 1 then
    begin
    Dec(SL, I-1);
    Move(S[I], S[1], SL);
    end;
  end { DelLeft };


procedure LongDelLeft(var S: LongString);
  var
    I: LongInt;
  begin
  I := 1;
  while (I <= Length(S)) and (S[I] in [#9, ' ']) do
    Inc(I);
  if I > 1 then
    S := Copy(S, I, Length(S)-I+1);
  end;

function fDelLeft(s: String): String;
  begin
  DelLeft(s);
  fDelLeft := s
  end;

(*
Procedure LowStr(var s : string);
var i:integer;
begin for i:=1 to Length(s) do
{if s[i]<>#0 then} s[i]:=LowCaseArray[s[i]]; {AK155}
end;
*)

function LowStrg(s: String): String;
  begin
  LowStr(s);
  LowStrg := s;
  end;

function UpStrg(s: String): String;
  begin
  UpStr(s);
  UpStrg := s;
  end;

procedure UpLowStr(var s: String); {JO}
  begin
  if UpperCaseSorting then
    UpStr(s)
  else
    LowStr(s);
  end;

function UpLowStrg(s: String): String; {JO}
  begin
  if UpperCaseSorting then
    begin
    UpStr(s);
    UpLowStrg := s;
    end
  else
    begin
    LowStr(s);
    UpLowStrg := s;
    end;
  end;

(*
Procedure CapStr(var S: String);
var
  I: Integer;
begin
 I:=1;
 repeat
  While (I<=Length(S)) and (S[I] in BreakChars) do Inc(I);
  If I>Length(S) then break;
  S[I]:=UpCase(S[I]);
  While (I<Length(S)) and (not (S[I] in BreakChars)) do begin
   Inc(I); S[I]:=LowCase(S[I]);
  end;
 until I>=Length(S);
end;
*)

function CapStrg(S: String): String;
  begin
  CapStr(S);
  CapStrg := S;
  end;

{Cat}
function CapLongStrg(const S: LongString; First, Last: Integer): LongString;
  begin
  Result := S;
  CapLongStr(Result, First, Last);
  end;
{/Cat}

{Cat}
procedure UpStr(var s: String);
  begin
{$IFDEF DNUTF8}
  Utf8UpStr(s);
{$ELSE}
  XLatBuf(s[1], Length(s), UpCaseArray);
{$ENDIF}
  end;

procedure LowStr(var s: String);
  begin
{$IFDEF DNUTF8}
  Utf8LowStr(s);
{$ELSE}
  XLatBuf(s[1], Length(s), LowCaseArray);
{$ENDIF}
  end;

procedure CapStr(var S: String);
  var
    I: LongInt;
  begin
  I := 1;
  repeat
    while (I <= Length(S)) and (S[I] in BreakChars) do
      Inc(I);
    if I > Length(S) then
      Break;
    S[I] := UpCase(S[I]);
    while (I < Length(S)) and (not (S[I] in BreakChars)) do
      begin
      Inc(I);
      S[I] := LowCase(S[I]);
      end;
  until I >= Length(S);
  end;

procedure CapLongStr(var S: LongString; First, Last: Integer);
  var
    I: LongInt;
  begin
  if Last > Length(S) then
    Last := Length(S);
  if First > Last then
    Exit;
  SetLength(S, Length(S));
  I := First;
  { If the word starts outside the region - skip it }
  if (I <> 1) and not (S[I-1] in BreakChars) then
    while not (S[I] in BreakChars) do
      begin
      if I = Last then
        Exit;
      Inc(I);
      end;

  while True do
    begin
    { Skip separators before the word }
    while I <= Last do
      begin
      if not (S[I] in BreakChars) then
        Break;
      Inc(I);
      end;
    if I > Last then
      Exit;

    { First letter of the word - to upper case }
    S[I] := UpCase(S[I]);

    { Remaining letters of the word - to lower case }
    while I < Last do
      begin
      Inc(I);
      if S[I] in BreakChars then
        Break;
      S[I] := LowCase(S[I]);
      end;
    Inc(I);
    end;
  end;

function Cut(p: String; len: Integer): String;
  begin
  (* X-Man *)
  if len < 0 then
    len := 0;
  Cut := FormatLongName(p, len, 0, 0, nfmNull)
  end;

function CutH(p: String; len: Integer): String;
  begin
  (* X-Man *)
  if len < 0 then
    len := 0;
  CutH := FormatLongName(p, len, 0, flnHighlight+flnHandleTildes, nfmNull)
  end;

function Strg(C: Char; Num: Byte): String;
  begin
  SetLength(Result, Num);
  FillChar(Result[1], Num, C);
  end;

function LongStrg(C: Char; Num: LongInt): LongString;
  begin
  SetLength(Result, Num);
  FillChar(Result[1], Num, C);
  end;
{/Cat}

function ItoS(a: LongInt): String;
  var
    s: String[12];
  begin
  Str(a, s);
  ItoS := s;
  end;

function ZtoS(a: TSize): String;
  var
    s: String[20];
  begin
  Str(a, s);
  ZtoS := s;
  end;

function RtoS(a: Real; M, F: Integer): String;
  var
    s: String[20];
  begin
  Str(a: M: F, s);
  RtoS := s;
  end;

function StoI(const s: String): LongInt;
  var
    i: LongInt;
    j: Integer;
  begin
  Val(s, i, j);
  StoI := i;
  end;

function SStr(a: LongInt; B: Byte; C: Char): String;
  var
    s: String[40];
    i: Integer;
  begin
  Str(a: B, s);
  i := 1;
  while i < B do
    begin
    if s[i] = ' ' then
      s[i] := C
    else
      i := 255;
    Inc(i);
    end;
  SStr := s;
  end;

function SSt2(a: LongInt; B: Byte; C: Char): String;
  var
    s: String[40];
  begin
  Str(a: B, s);
  while (s[1] = ' ') do
    begin
    Delete(s, 1, 1); {DelFC(s);}
    s := s+' '
    end;
  while B > 0 do
    begin
    if s[B] = ' ' then
      s[B] := C
    else
      B := 1;
    Dec(B);
    end;
  SSt2 := s;
  end;

const
  Magnif: string[4] = 'KMGT';

function SizeStr(a: TSize; MaxVal: TSize): String;
  var
    i, j, b: Integer;
  begin
  if a >= 0 then
    begin
    i := 0;
    if a >= MaxVal then
      MaxVal := MaxVal div 10; // room for the multiplier letter
    while a >= MaxVal do
      begin
      a := a div 1024;
      inc(i);
      end;
    Str(a, Result);
    if CountryInfo.ThouSep[0] > #0 then
      begin
      b := 2 + (Length(Result)-1) mod 3;
      for j := (Length(Result)-1) div 3 downto 1 do
        Insert(CountryInfo.ThouSep[1], Result, b + 3*(j-1));
      end;
    if i <> 0 then
      Result := Result + Magnif[i];
    end
  else
    Result := '?';
  end { SizeStr };

function FStr(a: TSize): String;
  begin
  Result := SizeStr(a, 1000000000);
  end;

function FileSizeStr(X: TSize): String;
  begin
  Result := SizeStr(X, 10000000);
  if Length(Result) > 9 then
    Delete(Result, 2, 1) { remove the first separator}
  else
    Result := PredSpace(Result, 9);
  end;

function Hex2(a: Byte): Str2;
  begin
  Hex2 := HexChar(a shr 4)+HexChar(a)
  end;

function Hex4(a: Word): Str4;
  begin
  Hex4 := HexChar(Hi(a) shr 4)+HexChar(Hi(a))+
    HexChar(Lo(a) shr 4)+HexChar(Lo(a));
  end;

function Hex8(a: LongInt): Str8;
  var
    s: Str8;
  begin
  s[0] := #8;
  Hex8Lo(a, s[1]);
  Hex8 := s;
  end;

function HexFilePos(C: Int64): String;
  var
    FilePosRec: record lo32, hi32: Longint end absolute C;
  begin
  Result := HexChar($0F and FilePosRec.hi32) + Hex8(FilePosRec.lo32);
  end;

function HexChar(a: Byte): Char;
  
  begin
  a := a and 15;
  if a < 10 then
    HexChar := Char(Ord('0')+a)
  else
    HexChar := Char(Ord('A')+a-10);
  end;


function Replace(const Pattern, ReplaceString: String; var S: String) : Boolean;
  var
    I, J, K: Integer;
  begin
  J := 1;
  K := 1;
  Replace := False;
  if  (Pattern = '') or (S = '') then
    Exit;
  repeat
    I := Pos(Pattern, Copy(S, J, MaxStringLength));
    if I > 0 then
      begin
      Delete(S, J+I-1, Length(Pattern));
      Insert(ReplaceString, S, J+I-1);
      Replace := True;
      end;
    K := I;
    Inc(J, I+Length(ReplaceString)-1);
  until I = 0;
  end;

function fReplace(const SubFrom, SubTo: String; S: String): String;
  var
    P: Integer;
  begin
  repeat
    P := Pos(SubFrom, S);
    if P <> 0 then
      begin
      S := Copy(S, 1, P-1)
          +SubTo+Copy(S, P+Length(SubFrom), Length(S)-P-Length(SubFrom)+1);
      end;
  until (P = 0);
  fReplace := S;
  end;

function PosChar(C: Char; const S: String): Byte;
  
  {Cat}
  var
    I: Integer;
  begin { PosChar }
  for I := 1 to Length(S) do
    if S[I] = C then
      begin
      PosChar := I;
      Exit;
      end;
  PosChar := 0;
  end { PosChar };
{/Cat}


function CharCount(C: Char; const S: String): Byte; {DataCompBoy}
  
  var
    i, j: Byte;
  begin { CharCount }
  j := 1;
  for i := 1 to Length(S) do
    if S[i] = C then
      Inc(j);
  CharCount := j;
  end { CharCount };


function GetDateTime(Time: Boolean): String;
  var
    S: String[30];
    Y, M, D, DW: Word;
    H, Mn, SS, S100: Word;

  begin
  GetDate(Y, M, D, DW);
  GetTime(H, Mn, SS, S100);
  MakeDateFull(D, M, Y, H, Mn, S, not Time); {-$VOL modified}
  if Time then
    S := FormatTimeStr(H, Mn, SS)
  else
    SetLength(S, 10); {S[0] := #10;}
  GetDateTime := S;
  end;

function SecToStr(t: Word {in seconds }): String;
  var
    s: word;
  begin
  s := t mod 3600;
  Result :=
    Dec2(t div 3600) + CountryInfo.TimeSep + { hours }
    Dec2(s div 60) + CountryInfo.TimeSep + { minutes }
    Dec2(s mod 60); { seconds }
  end;


function FormatTimeStr(H, M, SS: Word): String;
  var
    N: String[3];
    S: String[20];
  begin
  if  (CountryInfo.TimeFmt = 0) and (H > 12) then
    begin
    S := Dec2(H-12)+CountryInfo.TimeSep+Dec2(M)
      +CountryInfo.TimeSep+Dec2(SS);
    N := 'pm';
    end
  else
    begin
    S := Dec2(H)+CountryInfo.TimeSep+Dec2(M)
      +CountryInfo.TimeSep+Dec2(SS);
    if CountryInfo.TimeFmt = 0
    then
      if  (H < 12) then
        N := 'am'
      else
        N := 'pm'
    else
      N := '';
    end;
  FormatTimeStr := S+N;
  end { FormatTimeStr };

{cat}
function FormatDateTime(const DT: DateTime; Time: Boolean): String; {cat}
  begin
  if Time then
    Result := Dec2(DT.Hour)+CountryInfo.TimeSep+
              Dec2(DT.Min)+CountryInfo.TimeSep+
              Dec2(DT.Sec)
  else
    case CountryInfo.DateFmt of
      0: {MM-DD-YY}
        Result := Dec2(DT.Month)+CountryInfo.DateSep+
                  ItoS(DT.Day)+CountryInfo.DateSep+
                  ItoS(DT.Year);
      1: {DD-MM-YY}
        Result := ItoS(DT.Day)+CountryInfo.DateSep+
                  Dec2(DT.Month)+CountryInfo.DateSep+
                  ItoS(DT.Year);
      2: {YY-MM-DD}
        Result := ItoS(DT.Year)+CountryInfo.DateSep+
                  Dec2(DT.Month)+CountryInfo.DateSep+
                  ItoS(DT.Day);
    else
      Result := '';
    end;
  end;
{/cat}

procedure MakeCurrency(R: Real; var S: String);
  var
    I: Integer;
  begin
  with CountryInfo do
    begin
    if  (DecSign >= '0') and (DecSign <= '9') then
      I := Byte(DecSign[1])-48
    else
      I := 2;
    Str(R: 0: I, S);
    I := PosChar('.', S);
    if I = 0 then
      I := Length(S)
    else
      Move(DecSep[1], S[I], Length(DecSep));
    case CurrencyFmt of
      0:
        S := Currency+S;
      1:
        S := S+Currency;
      2:
        S := Currency+' '+S;
      3:
        S := S+' '+Currency;
      4:
        Insert(Currency, S, I);
    end {case};
    end;
  end { MakeCurrency };

function Real2Str(X: Real; n: Byte): String;
  begin
  System.Str(X: n, FreeStr);
  Real2Str := FreeStr
  end;
function Long2Str(X: LongInt; l: Byte): String;
  begin
  Str(X: l, FreeStr);
  Long2Str := FreeStr;
  end;
function Long0Str(X: LongInt; l: Byte): String;
  var
    I: Byte;
  begin
  Str(X: l, FreeStr);
  for I := 1 to Length(FreeStr) do
    if FreeStr[I] = ' ' then
      FreeStr[I] := '0';
  Long0Str := FreeStr
  end;
function ToHex(I: Word): String;
  var
    s: String;
    c: Byte;
    b: Byte;
  begin
  s := '';
  for c := 1 to 4 do
    begin
    s := Char(48+(I and 15)+Byte((I and 15) > 9)*7)+s;
    I := I div 16
    end;
  ToHex := s;
  end;

procedure DelDoubles(const St: String; var Source: String);
  var
    t, ls, p: Byte;
    j: Boolean;
  begin
  t := 1;
  ls := Length(St);
  j := True;
  while t+ls <= Length(Source) do
    begin
    if Source[t] = '"' then
      j := not j;
    if j then
      p := Pos(St, Source);
    if j and (p <> 0) then
      Delete(Source, p, 1)
    else
      Inc(t);
    end;
  end;

procedure AnsiDelDoubles(const St: String; var Source: AnsiString);
  var
    t, ls, p: LongInt;
    j: Boolean;
  begin
  t := 1;
  ls := Length(St);
  j := True;
  while t+ls <= Length(Source) do
    begin
    if Source[t] = '"' then
      j := not j;
    if j then
      p := Pos(St, Source);
    if j and (p <> 0) then
      Delete(Source, p, 1)
    else
      Inc(t);
    end;
  end;

{Cat}
procedure LongDelDoubles(const St: LongString; var Source: LongString);
  var
    t, ls, p: LongInt;
    j: Boolean;
  begin
  t := 1;
  ls := Length(St);
  j := True;
  while t+ls <= Length(Source) do
    begin
    if Source[t] = '"' then
      j := not j;
    if j then
      p := Pos(St, Source);
    if j and (p <> 0) then
      Delete(Source, p, 1)
    else
      Inc(t);
    end;
  end;
{/Cat}

procedure MakeDate(const Day, Month, Year, Hour, Min: Word; var S: String);
  begin
  MakeDateFull(Day, Month, Year, Hour, Min, S, False);
  end;

procedure MakeDateFull(const Day, Month: Word; Year, Hour: Word; const Min: Word; var S: String; const YFull: Boolean); {-$VOL modified}

  procedure GetDig(R: Byte; var S);
    
    begin
    Word(S) := Word(((R div 10)+Ord('0'))+((R mod 10)+Ord('0')) shl 8);
    end;
  

  begin { MakeDateFull }
  if YFull then
    GetDig(Year div 100, S[16]);
  Year := Year mod 100;
  FillChar(S, 16, 32);
  SetLength(S, 15);
  Move(CountryInfo.DateSep[1], S[3], Length(CountryInfo.DateSep));
  Move(CountryInfo.DateSep[1], S[6], Length(CountryInfo.DateSep));
  Move(CountryInfo.TimeSep[1], S[12], Length(CountryInfo.TimeSep));
  case CountryInfo.DateFmt of
    0:
      begin
      GetDig(Day, S[4]);
      GetDig(Month, S[1]);
      GetDig(Year, S[7]);
      end;
    1:
      begin
      GetDig(Day, S[1]);
      GetDig(Month, S[4]);
      GetDig(Year, S[7]);
      if S[1] = '0' then
        S[1] := ' ';
      end;
    2:
      begin
      GetDig(Day, S[7]);
      GetDig(Month, S[4]);
      GetDig(Year, S[1]);
      end;
  end {case};
  GetDig(Min, S[13]);
  if CountryInfo.TimeFmt = 0 then
    begin
    if Hour <= 12 then
      if Hour = 12 then
        S[15] := 'p'
      else
        S[15] := 'a'
    else
      begin
      Dec(Hour, 12);
      S[15] := 'p'
      end;
    end
  else
    SetLength(S, Length(S)-1);
  GetDig(Hour, S[10]);
  if S[10] = '0' then
    S[10] := ' ';
  if YFull then
    case CountryInfo.DateFmt of
      0, 1:
        S := Copy(S, 1, 6)+S[16]+S[17]+Copy(S, 7, MaxStringLength);
      2:
        S := S[16]+S[17]+S;
    end {case};
  end { MakeDateFull };

const
  LastCase: Byte = 2;


function DumpStr;
  var
    S: String;
    i, j, l, l0, l1: Byte;
    Buf: array[0..$FF] of Byte absolute B;
  begin { DumpStr }
  DumpStr := '';
  if Count <= 0 then
    Exit;
  S := HexFilePos(Addr);
  j := 10;
  SetLength(S, Count*4+12);
  S[j] := ':';
  S[j+1] := ' ';
  Inc(j, 2);
  S[j+Count*3] := Char($B3);
  S[j+1+Count*3] := ' ';
  for i := 0 to Count-1 do
    begin
    l := Buf[i];
    l0 := (l shr 4)+$30;
    l1 := (l and $0F)+$30;
    if l0 > $39 then
      Inc(l0, 7);
    if l1 > $39 then
      Inc(l1, 7);
    if Filter <> 0 then
      begin
      if l < $20 then
        l := 250
      else if (Filter = 1) and (l >= $80) then
        l := 250;
      end;
    S[j] := Char(l0);
    Inc(j);
    S[j] := Char(l1);
    Inc(j);
    S[j] := ' ';
    Inc(j);
    S[i+13+Count*3] := Char(l);
    end;
  DumpStr := S;
  end { DumpStr };

{AK155: Threw out the mess that was here and replaced it with
a proper BM search, based on the program
demobmse.pas from SWAG }
(* Public-domain demo of Boyer-Moore search algorithm.  *)
(* Guy McLoughlin - May 2, 1993.                        *)


  (***** Create a Boyer-Moore index-table to search with.  *)
procedure Create_BMTable
    ( {output} var BMT: BMTable;
    {input/output} var Pattern: String;
    ExactCase: Boolean);
  var
    Index: Byte;
  begin
  FillChar(BMT, SizeOf(BMT), Length(Pattern));
  if not ExactCase then
    UpStr(Pattern);
  for Index := 1 to Length(Pattern) do
    BMT[Ord(Pattern[Index])] := (Length(Pattern)-Index)
  end;

function BMsearch(
    const BMT: BMTable;
    var Buffer;
    BuffSize: LongInt;
    const Pattern: String;
    const UpXlatArray: TXlat
    ): LongInt;
  var
    Buffer2: array[1..MaxLongInt] of Char absolute Buffer;
    BufIndex,
    PatternIndex,
    PatSize: LongInt;
    c: Char;
    d, l: LongInt;

  begin
  PatSize := Length(Pattern);
  if PatSize > BuffSize then
    begin
    BMsearch := 0;
    Exit;
    end;
  BufIndex := PatSize;
  PatternIndex := PatSize;
  while true do
    begin
    c := UpXlatArray[Buffer2[BufIndex]];
    if  (c = Pattern[PatternIndex]) then
      begin
      if PatternIndex = 1 then
        begin
        BMsearch := BufIndex;
        Exit;
        end;
      Dec(BufIndex);
      Dec(PatternIndex);
      end
    else
      begin
      d := BMT[Ord(c)];
      l := Succ(PatSize-PatternIndex);
      if l > d then
        Inc(BufIndex, l)
      else
        Inc(BufIndex, d);
      if BufIndex > BuffSize then
        begin
        BMsearch := 0;
        Exit;
        end;
      PatternIndex := PatSize
      end;
    end;
  end { BMsearch };

{Cat: reverse Boyer-Moore search, reworked from the forward one}
procedure Create_BackBMTable
    ( {output} var BMT: BMTable;
    {input/output} var Pattern: String;
    ExactCase: Boolean);
  var
    Index: Byte;
  begin
  FillChar(BMT, SizeOf(BMT), Length(Pattern));
  if not ExactCase then
    for Index := 1 to Length(Pattern) do
      Pattern[Index] := UpCaseArray[Pattern[Index]];
  for Index := Length(Pattern) downto 1 do
    BMT[Ord(Pattern[Index])] := (Index-1)
  end;

function BackBMsearch(
    const BMT: BMTable;
    var Buffer;
    BuffSize: LongInt;
    const Pattern: String;
    const UpXlatArray: TXlat
    ): LongInt;
  var
    Buffer2: array[1..MaxLongInt] of Char absolute Buffer;
    BufIndex,
    PatternIndex,
    PatSize: LongInt;
    c: Char;
    d: LongInt;

  begin
  PatSize := Length(Pattern);
  if PatSize > BuffSize then
    begin
    BackBMsearch := 0;
    Exit;
    end;
  BufIndex := BuffSize-PatSize+1;
  PatternIndex := 1;
  while true do
    begin
    c := UpXlatArray[Buffer2[BufIndex]];
    if  (c = Pattern[PatternIndex]) then
      begin
      Inc(BufIndex);
      Inc(PatternIndex);
      if PatternIndex > PatSize then
        begin
        Result := BufIndex - PatSize;
        Exit;
        end;
      end
    else
      begin
      d := BMT[Ord(c)];
      if PatternIndex > d then
        Dec(BufIndex, PatternIndex)
      else
        Dec(BufIndex, d);
      PatternIndex := 1;
      if BufIndex < 1 then
        begin
        BackBMsearch := 0;
        Exit;
        end;
      end;
    end;
  end { BackBMsearch };
{/Cat}

function SearchForAllCP(S: String; var B; l: LongInt;
     CaseSensitive: Boolean): LongInt;
  var
    i: TKeyMap;
    R: Longint;
    BMT: BMTable;
  begin
  Create_BMTable(BMT, S, CaseSensitive);
  Result := 0;
  for i := kmAscii to MaxKeyMap do
    begin
    R := BMsearch(BMT, B, l, S,
      KeyMapDescr[i].XLatCP^[Ord(CaseSensitive)]);
    if (Result = 0) or ((R <> 0) and (R < Result)) then
      Result := R;
    end;
  end { SearchForAllCP };

function BackSearchForAllCP(S: String; var B; l: LongInt;
     CaseSensitive: Boolean): LongInt;
  var
    i: TKeyMap;
    R: Longint;
    BMT: BMTable;
  begin
  Create_BackBMTable(BMT, S, CaseSensitive);
  Result := 0;
  for i := kmAscii to MaxKeyMap do
    begin
    R := BackBMsearch(BMT, B, l, S,
      KeyMapDescr[i].XLatCP^[Ord(CaseSensitive)]);
    if (Result = 0) or ((R <> 0) and (R < Result)) then
      Result := R;
    end;
  end { BackSearchForAllCP };
{/Cat}

function NewStr(const S: String): PString;
  var
    P: PString;
  begin
  (*
  GetMem(P, Length(S) + 1);
  if (P <> nil) then
    P^:=S else
    FatalError('No memory for new string');
  NewStr:=P;
  *)
  if S = '' then
    P := nil
  else
    begin
    GetMem(P, Length(S)+1);
    P^:= S;
    end;
  NewStr := P;
  end;

procedure DisposeStr(var P: PString);
  begin
  if P <> nil then
    FreeMem(P, Length(P^)+1);
  P := nil;
  end;

procedure ReplaceP(var P: PString; S: String);
  begin
  DelRight(S);
  if P = nil then
    begin
    if S <> '' then
      P := NewStr(S);
    end
  else if Length(S) = Length(P^) then
    P^:= S
  else
    begin
    DisposeStr(P);
    P := NewStr(S);
    end;
  end;

function CnvString(P: PString): String;
  begin
  if P = nil then
    CnvString := ''
  else
    CnvString := P^;
  end;

{Cat}
function CnvLongString(P: PLongString): LongString;
  begin
  if P = nil then
    CnvLongString := ''
  else
    CnvLongString := P^;
  end;
{/Cat}

{Cat: rewrote NewStr, DisposeStr for AnsiString compatibility
      added NewLongStr, DisposeLongStr
      not final; changes possible
      when changing, must keep in sync with:
        Streams.TStream.ReadAnsiStr
        Streams.TStream.WriteAnsiStr
        WINCLP.Str2Collection}

function NewLongStr(const S: LongString): PLongString;
  var
    P: PLongString;
  begin
  if S = '' then
    P := nil
  else
    begin
    New(P);
    SetLength(P^, Length(S));
    Move(S[1], P^[1], Length(S))
    end;
  NewLongStr := P;
  end;

procedure DisposeLongStr(var P: PLongString);
  begin
  if P <> nil then
    Dispose(P);
  P := nil;
  end;
{/Cat}

procedure CompressShortStr(var S: String);
  var
    TSt, I, N, Cnt, Spaces: Integer;
    Out: String;
    C: Char;
  begin
  TSt := StoI(EditorDefaults.TabSize);
  if TSt = 0 then
    TSt := 8;
  N := Length(S);
  Out := '';
  I := 1;
  while I <= N do
    begin
    Cnt := 0;
    Spaces := 0;
    while (Cnt < TSt) and (I <= N) do
      begin
      C := S[I];
      Inc(I);
      Out := Out+C;
      Inc(Cnt);
      if C = ' ' then
        Inc(Spaces)
      else
        Spaces := 0;
      end;
    if Cnt < TSt then
      Break;
    if Spaces > 1 then   { the spaces up to the tab stop become a tab }
      begin
      SetLength(Out, Length(Out)-Spaces);
      Out := Out+#9;
      end;
    end;
  S := Out;
  end { CompressShortStr };

procedure CompressString(var S: LongString);
  var
    S1: String;
    S2: LongString;
    I: Word;
  begin
  I := 1;
  S2 := '';
  repeat
    S1 := Copy(S, I, 254);
    CompressShortStr(S1);
    S2 := S2+S1;
    Inc(I, 254);
  until S1 = '';
  S := S2;
  end;

(*
{Cat: added long-string support;
      this procedure is now used instead of the similar ones from editcore and editundo}
procedure CompressString(var S: LongString);
{$IFDEF USELONGSTRING}
{Cat}
var
  I, L, SpaceCount: LongInt;
  TSt1: Integer;
begin
  TSt1 := StoI(EditorDefaults.TabSize);
  if TSt1 = 0 then TSt1 := 8;
  Dec(TSt1);
  L := Length(S);
  I := 1;
  SpaceCount := 0;
  while I<=L do
    begin
      if S[I]=' ' then
        begin
          Inc(SpaceCount);
          if SpaceCount=TSt1+1 then
            begin
              S[I] := #9;
              Delete(S, I-TSt1, TSt1);
              Dec(I, TSt1);
              Dec(L, TSt1);
              SpaceCount := 0;
            end;
        end
      else
        SpaceCount := 0;
      Inc(I);
    end;
end;
{/Cat}
{$ELSE}
var PP: Pointer;
    TSt: Integer;
begin
 PP := @S;
 TSt := StoI(EditorDefaults.TabSize);
 if TSt = 0 then TSt := 8;
 {$IFNDEF BIT_32}
 asm
    les bx, PP
    mov cl, es:[bx]
    inc bx
    xor ch, ch
    jcxz @@Ex
    xor di, di
    xor si, si
    mov byte ptr es:[bx-1], ch
  @@1:
    mov ah, byte ptr TSt
    xor dx, dx
  @@2:
    mov al, es:[bx][si]
    mov es:[bx][di], al
    inc si
    cmp si, cx
    ja  @@Ex
    inc di
    inc byte ptr es:[bx-1]
    cmp al, ' '
    jne @@3
    inc dl
    jmp @@4
   @@3:
    xor Dl, dl
   @@4:
    dec ah
    jnz @@2
    or  dl, dl
    jz @@5
    dec dl
    jz @@5
    sub di, dx
    sub byte ptr es:[bx-1], dl
    mov al, 9
    mov es:[bx][di-1], al
   @@5:
    jmp @@1
  @@Ex:
 end;
 {$ELSE BIT_32}
 asm
    push ebx
    push edx
    push edi
    push esi
    mov ebx, PP
    xor ecx, ecx
    mov cl, [ebx]
    inc ebx
    jcxz @@Ex
    xor edi, edi
    xor esi, esi
    mov byte ptr [ebx-1], ch
  @@1:
    mov ah, byte ptr TSt
    xor edx, edx
  @@2:
    mov al, [ebx+esi]
    mov [ebx+edi], al
    inc esi
    cmp esi, ecx
    ja  @@Ex
    inc edi
    inc byte ptr [ebx-1]
    cmp al, ' '
    jne @@3
    inc dl
    jmp @@4
   @@3:
    xor dl, dl
   @@4:
    dec ah
    jnz @@2
    or  dl, dl
    jz @@5
    dec dl
    jz @@5
    sub edi, edx
    sub byte ptr [ebx-1], dl
    mov al, 9
    mov [ebx+edi-1], al
   @@5:
    jmp @@1
  @@Ex:
    pop esi
    pop edi
    pop edx
    pop ebx
 end;
 {$ENDIF}
end;
{$ENDIF}
*)

{AK155}

function PosLastDot(StrToMake: String): Byte;
  var
    I: Byte;
  begin
  for I := Length(StrToMake) downto 1 do
    begin
    case StrToMake[I] of
      '\', '/':
        Break;
      '.':
        begin
        PosLastDot := I;
        Exit;
        end;
    end {case};
    end;
  PosLastDot := Length(StrToMake)+1;
  end;

function IsDummyDir(const DirName: String): Boolean;
  begin
  IsDummyDir := (DirName = '.') or (DirName = '..');
  end;

procedure CopyShortString(const s1, s2: ShortString);
  begin
  Move(PByte(@s1)^, PByte(@s2)^, PByte(@s1)^+1);
  end;

function SPos(SubStr, S: String; Start: Integer): Integer;
  begin
  Result := Pos(SubStr, Copy(S, Start, 255));
  if Result <> 0 then
    inc(Result, Start-1);
  end;

function MemEqual(var Buf1; var Buf2; Len: Word): Boolean;
  begin
  Result := CompareByte(Buf1, Buf2, Len) = 0;
  end;

function MinBufSize(x: TFileSize; y: LongInt): LongInt;
  begin
  Result := y;
  if Result > x then
    Result := i32(x);
  end;

function Positive(x: TFileSize): TFileSize;
  begin
  Result := 0;
  if x > 0 then
    Result := x;
  end;



function CompToFSize(x: Int64): TFileSize;
  begin
  Result :=  Round  (x);
  end;

function Str2Comp(const s: String): Int64;
  var
    j: Integer;
  begin
  Val(s, result, j);
  end;


{/AK155}

end.
