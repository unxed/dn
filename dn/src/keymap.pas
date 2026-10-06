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

unit keymap;
{<keymap.001>}

interface

uses
  objutil, Defines, strutil
  ;

type
  TKeyMap = (kmXlat, kmNone, kmAscii, kmAnsi,
    kmKoi8r, km5, km6, km7, km8, km9);
  {`kmXlat and kmNone must come before kmAscii, and
  the rest after kmAscii`}

type
  PCodeConv = ^TCodeConv;
  TCodeConv = record
    A, B: Char
    end;

var
  RollKeyMap: array[TKeyMap] of TKeyMap;
  {` Code of the next built-in table in round-robin order `}
  MaxKeyMap: TKeyMap;
  {` Maximum number of an installed code-conversion table.`}

type
  {(c) SeYKo}
  TCodePageDetector = class
    procedure CheckString(P1: PChar; len: Integer);
    function DetectedCodePage: TKeyMap;
  private
    Koi, KoiA, Win, WinA, Win2: LongInt;
    end;
  {(c) SeYKo}

const
  ToUpAscii = 0;
    {` Index for TXLatCP - convert to ASCII with
    uppercase mapping. Used for case-insensitive
    search. (0 = ord(False))`}
  ToAscii = 1;
    {` Index for TXLatCP - convert to ASCII. (1 = ord(True))`}
  FromAscii = 2;
    {` Index for TXLatCP, convert from ASCII`}

type
  PXlatCP = ^TXLatCP;
  TXlatCP = array[0..2] of TXLat;

  TKeyMapDescr = record
    {` Codepage descriptor}
    Tag: string[3];
      {` Label shown in the window frame. Must be
      English letters only, uppercase only!
      See ProcessDefCodepage `}
    XlatCP: PXlatCP;
    end;
    {`}

var
  ToggleCaseArray: TXlat;
    {` Case flip in ASCII, like "cAPS lOCK" <-> "Caps Lock"`}
  LayoutConvXlat: TXLat;
    {` Layout correction
  For the case of two keyboard layouts (e.g. 866 and 850)
  remaps each character to what would have been typed from the
  same key in the other layout.
  Defined by an xlt file set by the KbdToggleLayout ini variable `}

  ABCSortXlat: TXLat;
    {' Weight table for alphabetical sort; no equal weights '}

  DosXlatCP: TXLatCP absolute UpCaseArray;
  WinXlatCP: TXLatCP;

const
  KeyMapDescr: array[TKeyMap] of TKeyMapDescr =
   {`Built-in codepages `}
    ((Tag: 'DOS'; XlatCP: @DosXlatCP) //kmXlat
    ,(Tag: 'DOS'; XlatCP: @DosXlatCP) //kmNone
    ,(Tag: 'DOS'; XlatCP: @DosXlatCP) //kmAscii
    ,(Tag: 'WIN'; XlatCP: @WinXlatCP) //kmAnsi
    ,(Tag: ''; XlatCP: nil)
    ,(Tag: ''; XlatCP: nil)
    ,(Tag: ''; XlatCP: nil)
    ,(Tag: ''; XlatCP: nil)
    ,(Tag: ''; XlatCP: nil)
    ,(Tag: ''; XlatCP: nil)
    );

function ProcessDefCodepage(DefCodepageS: String): TKeyMap;

procedure NullXLAT(var X: TXlat);
  {` Fill identity conversion `}

procedure AcceptToAscii(var XLatCP: TXLatCP);
  {` In XLatCP, based on the ready [ToAscii] table, fill the rest `}

function ReadXlt(FN: string; var N: Integer): PCodeConv;
  {` Read an xlt file. Memory for the result is allocated.
  N - length of the file read. If reading failed,
  result is nil and N = 0 `}

procedure ConvToXlat(Conv: PCodeConv; L: Integer; var Xlat: TXLat);
  {` Convert PCodeConv of length L into Xlat. Initial fill of
  XLat must be done by the caller. Conv is freed.`}

function BuildCodeTable(const S: string; var XlatCP: TXLatCP): Boolean;
  {` Builds XlatCP for codepage S. S may be either
  a number (then it is a codepage number) or an
  xlt file name. If the file name has no path (detected by '\'),
  the file is sought in the standard XLT directory. Result is success. `}

function BuildABCSortXlat(const FN: string): Boolean;
  {` Builds ABCSortXlat for codepage FN. FN may be either
  a number (then it is a codepage number) or an
  xlt file name. If the file name has no path (detected by '\'),
  the file is sought in the standard XLT directory.
  If FN='' or on error, ABCSortXlat is the identity conversion.
  Result is success.
  !! Note: at present (04.05.2005) only the
     xlt variant of FN is implemented.
  `}

function BuildLayoutConvXlat(const FN: string): Boolean;
  {` Builds LayoutConvXlat for codepage FN. FN may be either
  a number (then it is a codepage number) or an
  xlt file name. If the file name has no path (detected by '\'),
  the file is sought in the standard XLT directory.
  If FN='', LayoutConvXlat is the identity conversion.
  Result is success.
  `}

procedure XLatStr(var S: String; const XLat: TXLat);

procedure XLatBuf(var B; Len: Integer; const XTable: TXLat);

procedure FreeCodetables;
  {`Destroy all tables except ASCII. When building tables
  the call order must be: FreeCodetables,
  BuildWinCodeTable, InitCodeTables. Only with this order
  will MaxKeyMap be correct, no garbage left
  on the heap, and no nil addressing`}

function BuildWinCodeTable(S: string): Boolean;
  {` Handle a Windows codepage. S must look like
  837 'win866r.xlt'. See also FreeCodetables`}

function InitCodeTables(CodeTables: string): Boolean;
  {` Handle the CodeTables ini variable. Consists of space-separated
  items of the form KOI:837 or KOI:koi8-r.xlt `}

procedure OemToCharSt(var OemS: String); {JO}
  {` Convert from DOS to WIN `}
procedure CharToOemSt(var CharS: String); {JO}
  {` Convert from WIN to DOS `}
function OemToCharStr(const OemS: String): String;
  {` Convert from DOS to WIN `}
function CharToOemStr(const CharS: String): String;
  {` Convert from WIN to DOS `}

implementation
  uses
    country, basics, Streams;

procedure XLatBuf(var B; Len: Integer; const XTable: TXLat);
  var
    I: Integer;
    P: PByte;
  begin
  P := @B;
  for I := 1 to Len do
    begin
    P^ := Byte(XTable[Char(P^)]);
    Inc(P);
    end;
  end;

const
  WinSetA = [#224, #229, #232, #238, #243];
  KoiSetA = [#193, #197, #201, #207, #213];

procedure TCodePageDetector.CheckString(P1: PChar; len: Integer);
  var
    C: Char;
    P2: PChar;
  begin
  P2 := P1+len;
  while P1 < P2 do
    begin
    C := P1^;
    Inc(P1);
    if C >= #$C0 then
      if C <= #$DF then
        begin
        Inc(Koi);
        if C in KoiSetA then
          Inc(KoiA);
        end
      else
        begin
        Inc(Win);
        if C in WinSetA then
          Inc(WinA);
        if C >= #$F0 then
          Inc(Win2);
        end;
    end;
  end { TCodePageDetector.CheckString };

function TCodePageDetector.DetectedCodePage: TKeyMap;
  begin
  DetectedCodePage := kmAscii;
  if  (Koi <> 0) and (KoiA <> 0) and (Win <> 0) and
      (Win >= Koi div 500) and (Win <= Koi div 5) and
      (KoiA >= Koi div 5)
  then
    begin
    if KeyMapDescr[kmKoi8r].Tag = 'KOI' then
      DetectedCodePage := kmKoi8r;
    end
  else if (Win <> 0) and (WinA <> 0) and (Koi <> 0) and
      (Koi >= Win div 500) and (Koi <= Win div 5) and
      (WinA >= Win div 5) and (Win2 >= Win div 5)
  then
    DetectedCodePage := kmAnsi;
  end;
{(c) SeYKo}

function ProcessDefCodepage(DefCodepageS: String): TKeyMap;
  var
    i: Integer;
    k: TKeyMap;
  begin
{ Tempting to write UpStr(DefCodepageS), but better not to, since
that creates a nasty circular dependency between modules via strutil.
and, more importantly, it uses some UpCaseArray that is unknown in advance.
Since all dn.ini parameters are English, we simply do:}
  for i := 1 to Length(DefCodepageS) do
    DefCodepageS[i] := System.UpCase(DefCodepageS[i]);

  if DefCodepageS = 'AUTO' then
    Result := kmNone
  else
    begin
    Result := kmAscii; // in case of an invalid value
    for k := Succ(kmAscii) to MaxKeyMap do
      if DefCodepageS = KeyMapDescr[k].Tag then
        begin
        Result := k;
        Exit;
        end;
    end;
  end;

procedure NullXLAT(var X: TXlat);
  var
    C: Char;
  begin
  for C := #0 to #255 do
    X[C] := C;
  end;

procedure XLatLongStr(const InStr: LongString; var OutStr: LongString;
   const XLat: TXLat);
  var
    i: Longint;
  begin
  SetLength(OutStr, Length(InStr));
  for i := 1 to Length(InStr) do
    OutStr[i] := XLat[InStr[i]];
  end;

function Ascii_Ansi(const S: LongString): LongString;
  begin
  XLatLongStr(S, Result, KeyMapDescr[kmAnsi].XlatCP^[FromAscii]);
  end;

function Ansi_Ascii(const S: LongString): LongString;
  begin
  XLatLongStr(S, Result, KeyMapDescr[kmAnsi].XlatCP^[ToAscii]);
  end;

procedure AcceptToAscii(var XLatCP: TXLatCP);
  var
    C: Char;
  begin
{ The ToAscii table is not always uniquely invertible. For example,
under WinNT building the mapping via Unicode leads to
remapping into "similar" characters like copyright into 'C'.
But the "correct" codes are always less than the "similar" ones, so
the table must be inverted from #$FF down to #00, not the other way. }
  FillChar(XLatCP[FromAscii], SizeOf(TXLat), '?');
  for C := High(TXLat) downto Low(TXLat) do
    begin
    XLatCP[ToUpAscii][C] := Upcase(XLatCP[ToAscii][C]);
    XLatCP[FromAscii][XLatCP[ToAscii][C]] := C;
    end;
  end;

function ReadXlt(FN: string; var N: Integer): PCodeConv;
  var
    S: TDOSStream;
    I, J: Integer;
  begin
  Result := nil;
  N := 0;
  if FN <> '' then
    begin
    if Pos('\', FN) = 0 then
      FN := SourceDir+'xlt\' + FN;
    S := TDosStream.Create(FN, stOpenRead);
    if  (S.GetSize >= 2) and (S.GetSize <= 256*4) then
      begin
      N := i32(S.GetSize);
      GetMem(Result, N);
      S.Read(Result^, N);
      end;
    S.Free;
    end;
  end;

function BuildLayoutConvXlat(const FN: string): Boolean;
  var
    Conv, Conv0: PCodeConv;
    I, J: Integer;
  begin
  Result := True;
  NullXlat(LayoutConvXlat);
  if FN = '' then
    Exit;
  Conv0 := ReadXlt(FN, J);
  if Conv0 <> nil then
    begin
    Conv := Conv0;
    for I := 1 to J div 2 do
      begin
      if not (Conv^.A in [#$0D, #$0A]) then
        begin
        LayoutConvXlat[Conv^.A] := Conv^.B;
        LayoutConvXlat[Conv^.B] := Conv^.A;
        end;
      inc(Conv);
      end;
    FreeMem(Conv0);
    end
  else
    Result := False;
  end;

function BuildABCSortXlat(const FN: string): Boolean;
  var
    L: Integer;
    Conv: PCodeConv;
  begin
  Result := True;
  NullXlat(ABCSortXlat);
  if FN = '' then
    Exit;
  NullXlat(ABCSortXlat);
  Conv := ReadXlt(FN, L);
  if Conv = nil then
    begin
    Result := False;
    Exit;
    end;
  ConvToXlat(Conv, L, ABCSortXlat);
  end;

procedure XLatStr(var S: String; const XLat: TXLat);
  var
    i: Longint;
  begin
  for i := 1 to Length(S) do
    S[i] := XLat[S[i]];
  end;

procedure InitUpcase;
  var
    C, L, U: Char;
  begin
  QueryUpcaseTable;
  NullXLAT(LowCaseArray);
{see the comment on AcceptToAscii}
  for C := High(TXlat) downto Low(TXlat) do
    if UpCaseArray[C] <> C then
      LowCaseArray[UpCaseArray[C]] := C;
  for C := High(TXlat) downto Low(TXlat) do
    begin
    L := LowCaseArray[C];
    U := UpCaseArray[C];
    ToggleCaseArray[L] := U;
    ToggleCaseArray[U] := L;
    end;
  end { InitUpcase };

procedure ConvToXlat(Conv: PCodeConv; L: Integer; var Xlat: TXLat);
  var
    I: Integer;
    Conv0: PCodeConv;
  begin
  Conv0 := Conv;
  for I := 1 to L div 2 do
    begin
    if not (Conv^.A in [#$0D, #$0A]) then
      Xlat[Conv^.A] := Conv^.B;
    Inc(Conv);
    end;
  FreeMem(Conv0);
  end;

function BuildCodeTable(const S: string; var XlatCP: TXLatCP): Boolean;
  var
    CP: Integer;
    Err: Integer;
    I, L: Integer;
    Conv: PCodeConv;
    C: Char;
  begin
  Result := False;
  Val(S, CP, Err);
  if Err = 0 then
    Result := QueryToAscii(CP, XlatCP[ToAscii])
  else
    begin { must be an xlt file name}
    NullXLAT(XlatCP[ToAscii]);
    Conv := ReadXlt(S, L);
    if Conv <> nil then
      begin
      ConvToXlat(Conv, L, XlatCP[ToAscii]);
      Result := True;
      end;
    end;
  if Result then
    AcceptToAscii(XlatCP);
  end;

procedure FreeCodetables;
  var
    km: TKeyMap;
    i: Integer;
  begin
  for km := Succ(kmAnsi) to MaxKeyMap do
    FreeMem(KeyMapDescr[km].XlatCP);
  MaxKeyMap := kmAscii;
  for km := Low(km) to kmAscii do
    RollKeyMap[km] := kmAnsi;
  for i := Low(TXLatCP) to High(TXLatCP) do
    WinXlatCP[i] := NullXlatTable;
  end;

function BuildWinCodeTable(S: string): Boolean;
  var
    km: TKeyMap;
  begin
  Result := BuildCodeTable(S, WinXlatCP);
  if Result then
    begin
    AcceptToAscii(WinXlatCP);
    MaxKeyMap := kmAnsi;
    for km := Low(km) to kmAscii do
      RollKeyMap[km] := kmAnsi;
    end;
  end;

function InitCodeTables(CodeTables: string): Boolean;
  var
    l1, l2: Integer;
    CP: Word;
    Err: Integer;
    I, J: Integer;
    S: String;
    km: TKeyMap;
    GoodTable: Boolean;
    C: Char;
    b: Boolean;
  begin
  Result := False;
  CodeTables := CodeTables + ' '; // For Pos(' ');
  while CodeTables <> '' do
    begin
    l1 := Pos(':', CodeTables);
    if l1 = 0 then
      Break;
    l2 := Pos(' ', CodeTables);
    if l2 = 0 then
      Break;
    Inc(MaxKeyMap);
    GoodTable := False;
    with KeyMapDescr[MaxKeyMap] do
      begin
      GetMem(XlatCP, SizeOf(TXlatCP));
      Tag := DelSpaces(Copy(CodeTables, 1, l1-1));
      end;
    S := DelSpaces(Copy(CodeTables, l1+1, l2-l1));
    System.Delete(CodeTables, 1, l2);
    GoodTable := BuildCodeTable(S, KeyMapDescr[MaxKeyMap].XlatCP^);
    with KeyMapDescr[MaxKeyMap] do
      if not GoodTable then
        begin
        FreeMem(XlatCP);
        Dec(MaxKeyMap);
        Exit;
        end
      else
        begin
        RollKeyMap[Pred(MaxKeyMap)] := MaxKeyMap;
        RollKeyMap[MaxKeyMap] := kmAscii;
        end;
    end;
  DelSpace(CodeTables);
  Result := CodeTables = '';
  end;

{JO}
procedure OemToCharSt(var OemS: String);
  begin
  XLatBuf(OemS[1], Length(OemS), WinXlatCP[FromAscii]);
  end;

procedure CharToOemSt(var CharS: String);
  begin
  XLatBuf(CharS[1], Length(CharS), WinXlatCP[ToAscii]);
  end;

function OemToCharStr(const OemS: String): String;
  var
    I: Byte;
  begin
  SetLength(Result, Length(OemS));
  for I := 1 to Length(OemS) do
    Result[I] := WinXlatCP[FromAscii][OemS[I]];
  end;

function CharToOemStr(const CharS: String): String;
  var
    I: Byte;
  begin
  SetLength(Result, Length(CharS));
  for I := 1 to Length(CharS) do
    Result[I] := WinXlatCP[ToAscii][CharS[I]];
  end;
{/JO}

begin
NullXLAT(NullXlatTable);
NullXlatTable1 := NullXlatTable;
FreeCodetables; {This is safe because MaxKeyMap is currently zero }
GetSysCountryInfo; InitUpcase;
end.
