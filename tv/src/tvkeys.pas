{ TvKeys: key codes, key modifiers and TKey (normalized key combinations).

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/tkeys.h  (kb* constants, converted mechanically)
    source/tvision/tkey.cpp  (TKey constructor)
  Borland disclaimer and MIT notice: tv/COPYRIGHT.magiblot.

  Key codes are BIOS-style: the scan code in the high byte and the character in
  the low byte (kbF1 = $3B00, kbEnter = $1C0D). The modifier masks are the DOS
  BIOS ones (the non-"flat" set of the original); kbEnhanced is an addition of
  this port. TKey makes equal the combinations that can be written in several
  ways: kbCtrlA = TKey('A', kbCtrlShift); kbCtrlTab with kbShift = kbTab with
  kbShift or kbCtrlShift; kbAltDel with kbCtrlShift = kbCtrlDel with kbAltShift. }
unit TvKeys;

{$I tvdefs.inc}

interface

const
  { key codes }
  kbCtrlA = $0001; kbCtrlB = $0002; kbCtrlC = $0003;
  kbCtrlD = $0004; kbCtrlE = $0005; kbCtrlF = $0006;
  kbCtrlG = $0007; kbCtrlH = $0008; kbCtrlI = $0009;
  kbCtrlJ = $000A; kbCtrlK = $000B; kbCtrlL = $000C;
  kbCtrlM = $000D; kbCtrlN = $000E; kbCtrlO = $000F;
  kbCtrlP = $0010; kbCtrlQ = $0011; kbCtrlR = $0012;
  kbCtrlS = $0013; kbCtrlT = $0014; kbCtrlU = $0015;
  kbCtrlV = $0016; kbCtrlW = $0017; kbCtrlX = $0018;
  kbCtrlY = $0019; kbCtrlZ = $001A; kbEsc = $011B;
  kbAltSpace = $0200; kbCtrlIns = $0400; kbShiftIns = $0500;
  kbCtrlDel = $0600; kbShiftDel = $0700; kbBack = $0E08;
  kbCtrlBack = $0E7F; kbShiftTab = $0F00; kbTab = $0F09;
  kbAltQ = $1000; kbAltW = $1100; kbAltE = $1200;
  kbAltR = $1300; kbAltT = $1400; kbAltY = $1500;
  kbAltU = $1600; kbAltI = $1700; kbAltO = $1800;
  kbAltP = $1900; kbCtrlEnter = $1C0A; kbEnter = $1C0D;
  kbAltA = $1E00; kbAltS = $1F00; kbAltD = $2000;
  kbAltF = $2100; kbAltG = $2200; kbAltH = $2300;
  kbAltJ = $2400; kbAltK = $2500; kbAltL = $2600;
  kbAltZ = $2C00; kbAltX = $2D00; kbAltC = $2E00;
  kbAltV = $2F00; kbAltB = $3000; kbAltN = $3100;
  kbAltM = $3200; kbF1 = $3B00; kbF2 = $3C00;
  kbF3 = $3D00; kbF4 = $3E00; kbF5 = $3F00;
  kbF6 = $4000; kbF7 = $4100; kbF8 = $4200;
  kbF9 = $4300; kbF10 = $4400; kbHome = $4700;
  kbUp = $4800; kbPgUp = $4900; kbGrayMinus = $4A2D;
  kbLeft = $4B00; kbRight = $4D00; kbGrayPlus = $4E2B;
  kbEnd = $4F00; kbDown = $5000; kbPgDn = $5100;
  kbIns = $5200; kbDel = $5300; kbShiftF1 = $5400;
  kbShiftF2 = $5500; kbShiftF3 = $5600; kbShiftF4 = $5700;
  kbShiftF5 = $5800; kbShiftF6 = $5900; kbShiftF7 = $5A00;
  kbShiftF8 = $5B00; kbShiftF9 = $5C00; kbShiftF10 = $5D00;
  kbCtrlF1 = $5E00; kbCtrlF2 = $5F00; kbCtrlF3 = $6000;
  kbCtrlF4 = $6100; kbCtrlF5 = $6200; kbCtrlF6 = $6300;
  kbCtrlF7 = $6400; kbCtrlF8 = $6500; kbCtrlF9 = $6600;
  kbCtrlF10 = $6700; kbAltF1 = $6800; kbAltF2 = $6900;
  kbAltF3 = $6A00; kbAltF4 = $6B00; kbAltF5 = $6C00;
  kbAltF6 = $6D00; kbAltF7 = $6E00; kbAltF8 = $6F00;
  kbAltF9 = $7000; kbAltF10 = $7100; kbCtrlPrtSc = $7200;
  kbCtrlLeft = $7300; kbCtrlRight = $7400; kbCtrlEnd = $7500;
  kbCtrlPgDn = $7600; kbCtrlHome = $7700; kbAlt1 = $7800;
  kbAlt2 = $7900; kbAlt3 = $7A00; kbAlt4 = $7B00;
  kbAlt5 = $7C00; kbAlt6 = $7D00; kbAlt7 = $7E00;
  kbAlt8 = $7F00; kbAlt9 = $8000; kbAlt0 = $8100;
  kbAltMinus = $8200; kbAltEqual = $8300; kbCtrlPgUp = $8400;
  kbNoKey = $0000; kbAltEsc = $0100; kbAltBack = $0E00;
  kbF11 = $8500; kbF12 = $8600; kbShiftF11 = $8700;
  kbShiftF12 = $8800; kbCtrlF11 = $8900; kbCtrlF12 = $8A00;
  kbAltF11 = $8B00; kbAltF12 = $8C00; kbCtrlUp = $8D00;
  kbCtrlDown = $9100; kbCtrlTab = $9400; kbAltHome = $9700;
  kbAltUp = $9800; kbAltPgUp = $9900; kbAltLeft = $9B00;
  kbAltRight = $9D00; kbAltEnd = $9F00; kbAltDown = $A000;
  kbAltPgDn = $A100; kbAltIns = $A200; kbAltDel = $A300;
  kbAltTab = $A500; kbAltEnter = $A600;

  { key modifiers: the 'ControlKeyState' of keyboard and mouse events }
  kbLeftShift   = $0001;
  kbRightShift  = $0002;
  kbShift       = kbLeftShift or kbRightShift;
  kbLeftCtrl    = $0004;
  kbRightCtrl   = $0004;
  kbCtrlShift   = kbLeftCtrl or kbRightCtrl;
  kbLeftAlt     = $0008;
  kbRightAlt    = $0008;
  kbAltShift    = kbLeftAlt or kbRightAlt;
  kbScrollState = $0010;
  kbNumState    = $0020;
  kbCapsState   = $0040;
  kbInsState    = $0080;
  kbPaste       = $0100;
  kbEnhanced    = $0200;    { original: the key is an "enhanced" (extended) key }

type
  { a normalized key combination: Code is a key code, Mods only has the
    kbShift, kbCtrlShift and kbAltShift bits }
  TKey = record
    Code: Word;
    Mods: Word;
  end;

function KeyMake(KeyCode: Word; ShiftState: Word = 0): TKey;
function KeyEq(const A, B: TKey): Boolean; inline;

implementation

type
  TLookupEntry = record
    Normal: Word;           { 0: keep the key code }
    Mods: Byte;
  end;

var
  CtrlLookup: array[0..$1A] of TLookupEntry;
  ExtLookup: array[0..$A6] of TLookupEntry;     { indexed by the scan code }
  CtrlBackEntry, CtrlEnterEntry: TLookupEntry;

procedure Ext(Scan: Byte; Normal: Word; Mods: Byte);
begin
  ExtLookup[Scan].Normal := Normal;
  ExtLookup[Scan].Mods := Mods;
end;

procedure InitLookups;
var
  I: Integer;
begin
  FillChar(CtrlLookup, SizeOf(CtrlLookup), 0);
  FillChar(ExtLookup, SizeOf(ExtLookup), 0);
  for I := 1 to $1A do
  begin
    CtrlLookup[I].Normal := Ord('A') + I - 1;
    CtrlLookup[I].Mods := kbCtrlShift;
  end;

  Ext($01, kbEsc, kbAltShift);   Ext($02, Ord(' '), kbAltShift);
  Ext($04, kbIns, kbCtrlShift);  Ext($05, kbIns, kbShift);
  Ext($06, kbDel, kbCtrlShift);  Ext($07, kbDel, kbShift);
  Ext($0E, kbBack, kbAltShift);  Ext($0F, kbTab, kbShift);
  for I := 0 to 9 do
    Ext($10 + I, Ord('QWERTYUIOP'[I + 1]), kbAltShift);
  for I := 0 to 8 do
    Ext($1E + I, Ord('ASDFGHJKL'[I + 1]), kbAltShift);
  for I := 0 to 6 do
    Ext($2C + I, Ord('ZXCVBNM'[I + 1]), kbAltShift);
  Ext($35, Ord('/'), kbCtrlShift);  Ext($37, Ord('*'), kbCtrlShift);
  for I := 0 to 9 do
  begin
    Ext($3B + I, kbF1 + I * $100, 0);
    Ext($54 + I, kbF1 + I * $100, kbShift);
    Ext($5E + I, kbF1 + I * $100, kbCtrlShift);
    Ext($68 + I, kbF1 + I * $100, kbAltShift);
  end;
  Ext($47, kbHome, 0);   Ext($48, kbUp, 0);    Ext($49, kbPgUp, 0);
  Ext($4A, Ord('-'), kbCtrlShift);
  Ext($4B, kbLeft, 0);   Ext($4D, kbRight, 0);
  Ext($4E, Ord('+'), kbCtrlShift);
  Ext($4F, kbEnd, 0);    Ext($50, kbDown, 0);  Ext($51, kbPgDn, 0);
  Ext($52, kbIns, 0);    Ext($53, kbDel, 0);
  Ext($72, kbCtrlPrtSc, kbCtrlShift);
  Ext($73, kbLeft, kbCtrlShift);   Ext($74, kbRight, kbCtrlShift);
  Ext($75, kbEnd, kbCtrlShift);    Ext($76, kbPgDn, kbCtrlShift);
  Ext($77, kbHome, kbCtrlShift);
  for I := 0 to 8 do
    Ext($78 + I, Ord('1') + I, kbAltShift);
  Ext($81, Ord('0'), kbAltShift);
  Ext($82, Ord('-'), kbAltShift);  Ext($83, Ord('='), kbAltShift);
  Ext($84, kbPgUp, kbCtrlShift);
  Ext($85, kbF11, 0);          Ext($86, kbF12, 0);
  Ext($87, kbF11, kbShift);    Ext($88, kbF12, kbShift);
  Ext($89, kbF11, kbCtrlShift); Ext($8A, kbF12, kbCtrlShift);
  Ext($8B, kbF11, kbAltShift);  Ext($8C, kbF12, kbAltShift);
  Ext($8D, kbUp, kbCtrlShift);    Ext($91, kbDown, kbCtrlShift);
  Ext($94, kbTab, kbCtrlShift);
  Ext($97, kbHome, kbAltShift);   Ext($98, kbUp, kbAltShift);
  Ext($99, kbPgUp, kbAltShift);   Ext($9B, kbLeft, kbAltShift);
  Ext($9D, kbRight, kbAltShift);  Ext($9F, kbEnd, kbAltShift);
  Ext($A0, kbDown, kbAltShift);   Ext($A1, kbPgDn, kbAltShift);
  Ext($A2, kbIns, kbAltShift);    Ext($A3, kbDel, kbAltShift);
  Ext($A5, kbTab, kbAltShift);    Ext($A6, kbEnter, kbAltShift);

  CtrlBackEntry.Normal := kbBack;   CtrlBackEntry.Mods := kbCtrlShift;
  CtrlEnterEntry.Normal := kbEnter; CtrlEnterEntry.Mods := kbCtrlShift;
end;

{ Ctrl+letter delivered as scan code of the letter and character 1..26 }
function IsRawCtrlKey(ScanCode, CharCode: Byte): Boolean;
const
  ScanKeys: array[0..34] of Char = 'QWERTYUIOP'#0#0#0#0'ASDFGHJKL'#0#0#0#0#0'ZXCVBNM';
begin
  Result := (ScanCode >= 16) and (ScanCode < 16 + 35)
    and (Ord(ScanKeys[ScanCode - 16]) = CharCode - 1 + Ord('A'));
end;

function IsPrintableCharacter(CharCode: Byte): Boolean;
begin
  Result := (CharCode >= Ord(' ')) and (CharCode <> $7F) and (CharCode <> $FF);
end;

function IsKeypadCharacter(ScanCode: Byte): Boolean;
begin
  Result := (ScanCode = $35) or (ScanCode = $37) or (ScanCode = $4A) or (ScanCode = $4E);
end;

function KeyMake(KeyCode: Word; ShiftState: Word): TKey;
var
  Code, Mods: Word;
  ScanCode, CharCode: Byte;
  Entry: ^TLookupEntry;
begin
  Code := KeyCode;
  Mods := 0;
  if (ShiftState and kbShift) <> 0 then Mods := Mods or kbShift;
  if (ShiftState and kbCtrlShift) <> 0 then Mods := Mods or kbCtrlShift;
  if (ShiftState and kbAltShift) <> 0 then Mods := Mods or kbAltShift;
  ScanCode := KeyCode shr 8;
  CharCode := KeyCode and $FF;
  Entry := nil;
  if (KeyCode <= kbCtrlZ) or IsRawCtrlKey(ScanCode, CharCode) then
    Entry := @CtrlLookup[CharCode]
  else if CharCode = 0 then
  begin
    if ScanCode <= High(ExtLookup) then
      Entry := @ExtLookup[ScanCode];
  end
  else if IsPrintableCharacter(CharCode) then
  begin
    if (CharCode >= Ord('a')) and (CharCode <= Ord('z')) then
      Code := CharCode - Ord('a') + Ord('A')
    else if not IsKeypadCharacter(ScanCode) then
      Code := Code and $FF;
  end
  else if KeyCode = kbCtrlBack then
    Entry := @CtrlBackEntry
  else if KeyCode = kbCtrlEnter then
    Entry := @CtrlEnterEntry;
  if Entry <> nil then
  begin
    Mods := Mods or Entry^.Mods;
    if Entry^.Normal <> 0 then
      Code := Entry^.Normal;
  end;
  Result.Code := Code;
  if Code <> kbNoKey then
    Result.Mods := Mods
  else
    Result.Mods := 0;
end;

function KeyEq(const A, B: TKey): Boolean;
begin
  Result := (A.Code = B.Code) and (A.Mods = B.Mods);
end;

initialization
  InitLookups;
end.
