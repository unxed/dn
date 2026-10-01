program t_colors;
{$I ../src/tvdefs.inc}
uses TvColors;
{$I testlib.inc}

var
  A, B: TColorAttr;
begin
  { RGB packing }
  Check(RGB($7F, $00, $BB) = $7F00BB, 'RGB packs 0xRRGGBB');
  Check((RGBRed($7F00BB) = $7F) and (RGBGreen($7F00BB) = 0) and (RGBBlue($7F00BB) = $BB), 'RGB unpack');
  Check((RGBRed($AA7F00BB) = $7F) and (RGBGreen($AA7F00BB) = $00) and (RGBBlue($AA7F00BB) = $BB), 'RGB ignores the top byte');

  { BIOS <-> XTerm16 swaps red and blue }
  Check(BIOSToXTerm16(1) = 4, 'BIOS blue -> xterm 4');
  Check(BIOSToXTerm16(4) = 1, 'BIOS red -> xterm 1');
  Check(BIOSToXTerm16(2) = 2, 'BIOS green -> xterm 2');
  Check(BIOSToXTerm16(6) = 3, 'BIOS red+green -> xterm 3 (yellow)');
  Check(BIOSToXTerm16($F) = $F, 'BIOS white');
  Check(XTerm16ToBIOS(BIOSToXTerm16($B)) = $B, 'BIOS/xterm roundtrip');

  { RGB -> 16 colors }
  Check(RGBToXTerm16(RGB(0, 0, 0)) = 0, 'black -> 0');
  Check(RGBToXTerm16(RGB(255, 255, 255)) = 15, 'white -> 15');
  Check(RGBToXTerm16(RGB(255, 0, 0)) = 9, 'red -> 9');
  Check(RGBToXTerm16(RGB(128, 0, 0)) = 1, 'dark red -> 1');
  Check(RGBToXTerm16(RGB(0, 255, 0)) = 10, 'green -> 10');
  Check(RGBToXTerm16(RGB(0, 0, 255)) = 12, 'blue -> 12');
  Check(RGBToXTerm16(RGB(255, 255, 0)) = 11, 'yellow -> 11');
  Check(RGBToXTerm16(RGB(128, 128, 128)) = 8, 'mid gray -> 8');
  Check(RGBToXTerm16(RGB(192, 192, 192)) = 7, 'light gray -> 7');
  Check(RGBToXTerm16(RGB(10, 10, 10)) = 0, 'near black -> 0');

  { RGB -> 256 colors and back }
  Check(RGBToXTerm256(RGB(0, 0, 0)) = 16, '256: black');
  Check(RGBToXTerm256(RGB(255, 255, 255)) = 231, '256: white');
  Check(RGBToXTerm256(RGB(255, 0, 0)) = 196, '256: red');
  Check(XTerm256ToRGB(196) = RGB(255, 0, 0), '256 -> RGB red');
  Check(XTerm256ToRGB(232) = RGB(8, 8, 8), '256 -> RGB first gray');
  Check(XTerm256ToRGB(255) = RGB(238, 238, 238), '256 -> RGB last gray');
  Check(XTerm256ToXTerm16(196) = 9, '256 -> 16: red');

  { TColor }
  Check(ColorIsDefault(ColorDefault), 'default color');
  Check(ColorIsBIOS(ColorBIOS($1F)) and (ColorAsBIOS(ColorBIOS($1F)) = $F), 'BIOS color keeps 4 bits');
  Check(ColorIsRGB(ColorRGB($7F00BB)) and (ColorAsRGB(ColorRGB($7F00BB)) = $7F00BB), 'RGB color');
  Check(ColorIsXTerm(ColorXTerm(200)) and (ColorAsXTerm(ColorXTerm(200)) = 200), 'xterm color');
  Check(ColorToBIOS(ColorDefault, True) = 7, 'default fg -> 7');
  Check(ColorToBIOS(ColorDefault, False) = 0, 'default bg -> 0');
  Check(ColorToBIOS(ColorRGB($FF0000), True) = 12, 'RGB red -> BIOS 12');
  Check(ColorToBIOS(ColorXTerm(196), True) = 12, 'xterm 196 -> BIOS 12');
  Check(ColorToBIOS(ColorXTerm(4), True) = 1, 'xterm 4 (blue) -> BIOS 1');

  { TColorAttr }
  A := AttrFromBIOS($1F);
  Check(ColorAsBIOS(AttrFg(A)) = $F, 'attr fg from BIOS byte');
  Check(ColorAsBIOS(AttrBg(A)) = $1, 'attr bg from BIOS byte');
  Check(AttrAsBIOSByte(A) = $1F, 'attr -> BIOS byte');
  Check(AttrToBIOS(A) = $1F, 'attr quantized to BIOS');

  A := AttrMake(ColorRGB($7F00BB), ColorBIOS(3), slBold or slItalic);
  Check(AttrStyle(A) = slBold or slItalic, 'attr style');
  Check(ColorAsRGB(AttrFg(A)) = $7F00BB, 'attr fg RGB survives');
  Check(AttrAsBIOSByte(A) = $5F, 'non-BIOS attr gives 0x5F');

  AttrSetStyle(A, slUnderline);
  AttrSetFg(A, ColorBIOS(5));
  AttrSetBg(A, ColorXTerm(100));
  Check((AttrStyle(A) = slUnderline) and (ColorAsBIOS(AttrFg(A)) = 5)
    and (ColorAsXTerm(AttrBg(A)) = 100), 'attr setters');

  B.Data := 0;
  Check(ColorIsDefault(AttrFg(B)) and ColorIsDefault(AttrBg(B)) and (AttrStyle(B) = 0),
    'zero attr is default/default/no style');

  A := AttrFromBIOS($1F);
  B := AttrReversed(A);
  Check(AttrAsBIOSByte(B) = $F1, 'reversed swaps BIOS colors');
  B := AttrReversed(AttrMake(ColorDefault, ColorBIOS(2)));
  Check(AttrStyle(B) = slReverse, 'reversed with default color toggles slReverse');
  Check(AttrEq(AttrReversed(AttrReversed(A)), A), 'reversed twice is identity');

  Check(AttrEq(AttrPair(A, B).Lo, A) and AttrEq(AttrPair(A, B).Hi, B), 'attr pair');

  Finish;
end.
