{ TvColors: colors, color attributes and conversions between color models.

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/colors.h        (TColorRGB, TColorBIOS, TColorXTerm, TColor,
                                     TColorAttr, TAttrPair, style flags)
    source/platform/colors.cpp      (RGB -> 16/256 colors, quantization to BIOS)
  Borland disclaimer and MIT notice: tv/COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/DESIGN.md):
    - plain value types and functions instead of classes with operators;
    - the lookup tables are built at unit initialization.

  A TColor holds a 24-bit value and a 3-bit type (the 27 bits used by
  TColorAttr). A zero TColor is the terminal default color; a zero
  TColorAttr is default colors without style. }
unit TvColors;

{$I tvdefs.inc}

interface

type
  TColorRGB = LongWord;     { 0x00RRGGBB; the top byte is ignored }
  TColorBIOS = Byte;        { low 4 bits: bit0 blue, bit1 green, bit2 red, bit3 intensity }
  TColorXTerm = Byte;       { xterm palette index }
  TColor = LongWord;        { 24-bit value | type shl 24 }

  TColorAttr = record       { 27-bit fg, 27-bit bg, 10-bit style }
    Data: QWord;
  end;

  TAttrPair = record
    Lo, Hi: TColorAttr;
  end;

const
  { TColor types }
  ctDefault = 0;
  ctBIOS    = 1;
  ctRGB     = 2;
  ctXTerm   = 3;

  { text styles }
  slBold      = $001;
  slItalic    = $002;
  slUnderline = $004;
  slBlink     = $008;
  slReverse   = $010;       { prefer AttrReversed }
  slStrike    = $020;

{ --- TColorRGB ------------------------------------------------------------ }
function RGB(R, G, B: Byte): TColorRGB; inline;
function RGBRed(C: TColorRGB): Byte; inline;
function RGBGreen(C: TColorRGB): Byte; inline;
function RGBBlue(C: TColorRGB): Byte; inline;

{ --- TColorBIOS ------------------------------------------------------------ }
function BIOSRed(C: TColorBIOS): Boolean; inline;
function BIOSGreen(C: TColorBIOS): Boolean; inline;
function BIOSBlue(C: TColorBIOS): Boolean; inline;
function BIOSIntensity(C: TColorBIOS): Boolean; inline;

{ --- conversions between the color models ----------------------------------- }
function BIOSToXTerm16(C: TColorBIOS): TColorXTerm;       { swaps red and blue }
function XTerm16ToBIOS(Idx: TColorXTerm): TColorBIOS;
function XTerm256ToXTerm16(Idx: TColorXTerm): TColorXTerm; { for indices 16..255 }
function XTerm256ToRGB(Idx: TColorXTerm): TColorRGB;       { for indices 16..255 }
function RGBToXTerm16(C: TColorRGB): TColorXTerm;          { indices 0..15 }
function RGBToXTerm256(C: TColorRGB): TColorXTerm;         { indices 16..255 }

{ --- TColor ------------------------------------------------------------------ }
function ColorDefault: TColor; inline;
function ColorBIOS(Bios: Byte): TColor; inline;
function ColorRGB(Rgb: TColorRGB): TColor; inline;
function ColorXTerm(Idx: Byte): TColor; inline;
function ColorType(C: TColor): Byte; inline;
function ColorIsDefault(C: TColor): Boolean; inline;
function ColorIsBIOS(C: TColor): Boolean; inline;
function ColorIsRGB(C: TColor): Boolean; inline;
function ColorIsXTerm(C: TColor): Boolean; inline;
{ The getters do no conversion: check the type first. }
function ColorAsBIOS(C: TColor): TColorBIOS; inline;
function ColorAsRGB(C: TColor): TColorRGB; inline;
function ColorAsXTerm(C: TColor): TColorXTerm; inline;
{ Quantization to BIOS; the default color maps to 7 (foreground) or 0. }
function ColorToBIOS(C: TColor; IsForeground: Boolean): TColorBIOS;

{ --- TColorAttr -------------------------------------------------------------- }
function AttrMake(Fg, Bg: TColor; Style: Word = 0): TColorAttr; inline;
function AttrFromBIOS(Bios: Byte): TColorAttr; inline;
function AttrFg(const A: TColorAttr): TColor; inline;
function AttrBg(const A: TColorAttr): TColor; inline;
function AttrStyle(const A: TColorAttr): Word; inline;
procedure AttrSetFg(var A: TColorAttr; Fg: TColor); inline;
procedure AttrSetBg(var A: TColorAttr; Bg: TColor); inline;
procedure AttrSetStyle(var A: TColorAttr; Style: Word); inline;
function AttrReversed(const A: TColorAttr): TColorAttr;
function AttrToBIOS(const A: TColorAttr): Byte;
{ The BIOS byte if both colors are BIOS and there is no style, else $5F. }
function AttrAsBIOSByte(const A: TColorAttr): Byte;
function AttrEq(const A, B: TColorAttr): Boolean; inline;

{ --- TAttrPair --------------------------------------------------------------- }
function AttrPair(const Lo, Hi: TColorAttr): TAttrPair; inline;

implementation

const
  FgMask: QWord = (QWord(1) shl 27) - 1;
  BgMask: QWord = (QWord(1) shl 27) - 1;
  StyleMask: QWord = (QWord(1) shl 10) - 1;

var
  XTerm256ToXTerm16LUT: array[0..255] of TColorXTerm;
  XTerm256ToRGBLUT: array[0..255] of TColorRGB;

{ --- TColorRGB ------------------------------------------------------------ }

function RGB(R, G, B: Byte): TColorRGB;
begin
  Result := (LongWord(R) shl 16) or (LongWord(G) shl 8) or LongWord(B);
end;

function RGBRed(C: TColorRGB): Byte;
begin
  Result := Byte((C shr 16) and $FF);
end;

function RGBGreen(C: TColorRGB): Byte;
begin
  Result := Byte((C shr 8) and $FF);
end;

function RGBBlue(C: TColorRGB): Byte;
begin
  Result := Byte(C and $FF);
end;

{ --- TColorBIOS ------------------------------------------------------------ }

function BIOSRed(C: TColorBIOS): Boolean;
begin
  Result := (C and $04) <> 0;
end;

function BIOSGreen(C: TColorBIOS): Boolean;
begin
  Result := (C and $02) <> 0;
end;

function BIOSBlue(C: TColorBIOS): Boolean;
begin
  Result := (C and $01) <> 0;
end;

function BIOSIntensity(C: TColorBIOS): Boolean;
begin
  Result := (C and $08) <> 0;
end;

{ --- conversions ------------------------------------------------------------ }

function BIOSToXTerm16(C: TColorBIOS): TColorXTerm;
var
  Bits: Byte;
begin
  Bits := C and $0F;
  { swap the red (bit 2) and blue (bit 0) bits }
  Result := (Bits and $0A) or ((Bits and $01) shl 2) or ((Bits and $04) shr 2);
end;

function XTerm16ToBIOS(Idx: TColorXTerm): TColorBIOS;
begin
  Result := BIOSToXTerm16(Idx);
end;

function XTerm256ToXTerm16(Idx: TColorXTerm): TColorXTerm;
begin
  Result := XTerm256ToXTerm16LUT[Idx];
end;

function XTerm256ToRGB(Idx: TColorXTerm): TColorRGB;
begin
  Result := XTerm256ToRGBLUT[Idx];
end;

const
  HuePrecision = 32;
  HueMax = 6 * HuePrecision;
  HueToXTerm: array[0..5] of Byte = (1, 3, 2, 6, 4, 5);

{ RGB -> XTerm16 through an HSL-like intermediate (hue, chroma, lightness):
  chroma < 12 is grayscale (4 levels), otherwise dark/bright/white variant of
  the color picked by hue. Integer arithmetic only. }
function RGBToXTerm16Impl(R, G, B: Byte): TColorXTerm;
var
  Xmin, Xmax, L, C, Hue: Byte;
  H: Integer;
begin
  Xmin := R;
  if G < Xmin then Xmin := G;
  if B < Xmin then Xmin := B;
  Xmax := R;
  if G > Xmax then Xmax := G;
  if B > Xmax then Xmax := B;
  L := (Integer(Xmax) + Integer(Xmin)) div 2;
  C := Xmax - Xmin;
  H := 0;
  if C <> 0 then
  begin
    if Xmax = R then
      H := (HuePrecision * (Integer(G) - Integer(B))) div C
    else if Xmax = G then
      H := (HuePrecision * (Integer(B) - Integer(R))) div C + 2 * HuePrecision
    else
      H := (HuePrecision * (Integer(R) - Integer(G))) div C + 4 * HuePrecision;
    if H < 0 then
      Inc(H, HueMax)
    else if H >= HueMax then
      Dec(H, HueMax);
  end;
  if C >= 12 then
  begin
    if H < HueMax - HuePrecision div 2 then
      Hue := (H + HuePrecision div 2) div HuePrecision
    else
      Hue := (H - (HueMax - HuePrecision div 2)) div HuePrecision;
    if L < 127 then                 { 0.5 * 255 }
      Exit(HueToXTerm[Hue]);
    if L < 235 then                 { 0.925 * 255 }
      Exit(HueToXTerm[Hue] + 8);
    Exit(15);
  end
  else
  begin
    if L < 63 then                  { 0.25 * 255 }
      Exit(0);
    if L < 159 then                 { 0.625 * 255 }
      Exit(8);
    if L < 223 then                 { 0.875 * 255 }
      Exit(7);
    Exit(15);
  end;
end;

function RGBToXTerm16(C: TColorRGB): TColorXTerm;
begin
  Result := RGBToXTerm16Impl(RGBRed(C), RGBGreen(C), RGBBlue(C));
end;

function RGBToXTerm256(C: TColorRGB): TColorXTerm;

  function Scale(V: Byte): Integer;
  begin
    if V < 75 then
      Inc(V, 20);               { compensate for underrepresented dark colors }
    if V < 35 then
      V := 35;
    Result := (V - 35) div 40;
  end;

  function CnvGray(L: Byte): Integer;
  begin
    if L < 8 - 5 then
      Exit(16);                 { totally black }
    if L >= 238 + 5 then
      Exit(231);                { totally white }
    if L < 3 then
      L := 3;
    Result := 232 + (L - 3) div 10;
  end;

var
  Idx: Integer;
  R, G, B, Xmin, Xmax, Chroma, L: Byte;
begin
  R := RGBRed(C);
  G := RGBGreen(C);
  B := RGBBlue(C);
  Idx := 16 + (Scale(R) * 6 + Scale(G)) * 6 + Scale(B);
  if (C and $FFFFFF) <> XTerm256ToRGB(Idx) then
  begin
    Xmin := R;
    if G < Xmin then Xmin := G;
    if B < Xmin then Xmin := B;
    Xmax := R;
    if G > Xmax then Xmax := G;
    if B > Xmax then Xmax := B;
    Chroma := Xmax - Xmin;
    if (Chroma < 12) or (Idx = 16) then
    begin
      L := (Integer(Xmax) + Integer(Xmin)) div 2;
      Idx := CnvGray(L);
    end;
  end;
  Result := Idx;
end;

procedure InitLUTs;
var
  I, J, K: Integer;
  R, G, B, L: Byte;
begin
  for I := 0 to 255 do
  begin
    XTerm256ToXTerm16LUT[I] := 0;
    XTerm256ToRGBLUT[I] := 0;
  end;
  for I := 0 to 15 do
    XTerm256ToXTerm16LUT[I] := I;
  for I := 0 to 5 do
  begin
    if I <> 0 then R := 55 + I * 40 else R := 0;
    for J := 0 to 5 do
    begin
      if J <> 0 then G := 55 + J * 40 else G := 0;
      for K := 0 to 5 do
      begin
        if K <> 0 then B := 55 + K * 40 else B := 0;
        XTerm256ToXTerm16LUT[16 + (I * 6 + J) * 6 + K] := RGBToXTerm16Impl(R, G, B);
        XTerm256ToRGBLUT[16 + (I * 6 + J) * 6 + K] := RGB(R, G, B);
      end;
    end;
  end;
  for I := 0 to 23 do
  begin
    L := I * 10 + 8;
    XTerm256ToXTerm16LUT[232 + I] := RGBToXTerm16Impl(L, L, L);
    XTerm256ToRGBLUT[232 + I] := RGB(L, L, L);
  end;
end;

{ --- TColor ------------------------------------------------------------------ }

function ColorDefault: TColor;
begin
  Result := 0;
end;

function ColorBIOS(Bios: Byte): TColor;
begin
  Result := LongWord(Bios and $0F) or (ctBIOS shl 24);
end;

function ColorRGB(Rgb: TColorRGB): TColor;
begin
  Result := (Rgb and $FFFFFF) or (ctRGB shl 24);
end;

function ColorXTerm(Idx: Byte): TColor;
begin
  Result := LongWord(Idx) or (ctXTerm shl 24);
end;

function ColorType(C: TColor): Byte;
begin
  Result := Byte((C shr 24) and $FF);
end;

function ColorIsDefault(C: TColor): Boolean;
begin
  Result := ColorType(C) = ctDefault;
end;

function ColorIsBIOS(C: TColor): Boolean;
begin
  Result := ColorType(C) = ctBIOS;
end;

function ColorIsRGB(C: TColor): Boolean;
begin
  Result := ColorType(C) = ctRGB;
end;

function ColorIsXTerm(C: TColor): Boolean;
begin
  Result := ColorType(C) = ctXTerm;
end;

function ColorAsBIOS(C: TColor): TColorBIOS;
begin
  Result := Byte(C and $FF);
end;

function ColorAsRGB(C: TColor): TColorRGB;
begin
  Result := C and $FFFFFF;
end;

function ColorAsXTerm(C: TColor): TColorXTerm;
begin
  Result := Byte(C and $FF);
end;

function ColorToBIOS(C: TColor; IsForeground: Boolean): TColorBIOS;
var
  Idx: Byte;
begin
  case ColorType(C) of
    ctBIOS:
      Result := ColorAsBIOS(C);
    ctRGB:
      Result := XTerm16ToBIOS(RGBToXTerm16(ColorAsRGB(C)));
    ctXTerm:
    begin
      Idx := ColorAsXTerm(C);
      if Idx >= 16 then
        Idx := XTerm256ToXTerm16(Idx);
      Result := XTerm16ToBIOS(Idx);
    end;
  else
    if IsForeground then Result := $7 else Result := $0;
  end;
end;

{ --- TColorAttr -------------------------------------------------------------- }

function AttrMake(Fg, Bg: TColor; Style: Word): TColorAttr;
begin
  Result.Data := (QWord(Fg) and FgMask)
    or ((QWord(Bg) and BgMask) shl 27)
    or (QWord(Style) shl 54);
end;

function AttrFromBIOS(Bios: Byte): TColorAttr;
begin
  Result := AttrMake(ColorBIOS(Bios), ColorBIOS(Bios shr 4));
end;

function AttrFg(const A: TColorAttr): TColor;
begin
  Result := TColor(A.Data and FgMask);
end;

function AttrBg(const A: TColorAttr): TColor;
begin
  Result := TColor((A.Data shr 27) and BgMask);
end;

function AttrStyle(const A: TColorAttr): Word;
begin
  Result := Word(A.Data shr 54);
end;

procedure AttrSetFg(var A: TColorAttr; Fg: TColor);
begin
  A.Data := (A.Data and not FgMask) or (QWord(Fg) and FgMask);
end;

procedure AttrSetBg(var A: TColorAttr; Bg: TColor);
begin
  A.Data := (A.Data and not (BgMask shl 27)) or ((QWord(Bg) and BgMask) shl 27);
end;

procedure AttrSetStyle(var A: TColorAttr; Style: Word);
begin
  A.Data := (A.Data and not (StyleMask shl 54)) or (QWord(Style) shl 54);
end;

function AttrReversed(const A: TColorAttr): TColorAttr;
var
  Fg, Bg: TColor;
begin
  Fg := AttrFg(A);
  Bg := AttrBg(A);
  { slReverse may look different in different terminals, so the colors are
    swapped by hand unless one of them is the default color }
  if ColorIsDefault(Fg) or ColorIsDefault(Bg) then
    Result := AttrMake(Fg, Bg, AttrStyle(A) xor slReverse)
  else
    Result := AttrMake(Bg, Fg, AttrStyle(A));
end;

function AttrToBIOS(const A: TColorAttr): Byte;
begin
  Result := ColorToBIOS(AttrFg(A), True) or (ColorToBIOS(AttrBg(A), False) shl 4);
end;

function AttrAsBIOSByte(const A: TColorAttr): Byte;
begin
  if ColorIsBIOS(AttrFg(A)) and ColorIsBIOS(AttrBg(A)) and (AttrStyle(A) = 0) then
    Result := ColorAsBIOS(AttrFg(A)) or (ColorAsBIOS(AttrBg(A)) shl 4)
  else
    Result := $5F;
end;

function AttrEq(const A, B: TColorAttr): Boolean;
begin
  Result := A.Data = B.Data;
end;

function AttrPair(const Lo, Hi: TColorAttr): TAttrPair;
begin
  Result.Lo := Lo;
  Result.Hi := Hi;
end;

initialization
  InitLUTs;
end.
