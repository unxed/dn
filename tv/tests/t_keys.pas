program t_keys;
{$I ../src/tvdefs.inc}
uses TvKeys;
{$I testlib.inc}

function Same(const A, B: TKey): Boolean;
begin
  Result := KeyEq(A, B);
end;

var
  K: TKey;
begin
  { constants are BIOS codes }
  Check(kbEnter = $1C0D, 'kbEnter');
  Check(kbF1 = $3B00, 'kbF1');
  Check(kbAltQ = $1000, 'kbAltQ');
  Check(kbNoKey = 0, 'kbNoKey');
  Check(kbShift = 3, 'kbShift');
  Check((kbCtrlShift = 4) and (kbAltShift = 8), 'kbCtrlShift, kbAltShift');

  { the examples in the original header }
  Check(Same(KeyMake(kbCtrlA), KeyMake(Ord('A'), kbCtrlShift)), 'kbCtrlA = TKey(A, ctrl)');
  Check(Same(KeyMake(kbCtrlTab, kbShift), KeyMake(kbTab, kbShift or kbCtrlShift)),
    'Ctrl+Tab with shift = Tab with shift and ctrl');
  Check(Same(KeyMake(kbAltDel, kbCtrlShift), KeyMake(kbCtrlDel, kbAltShift)),
    'Alt+Del with ctrl = Ctrl+Del with alt');

  { the result of the normalization }
  K := KeyMake(kbCtrlA);
  Check((K.Code = Ord('A')) and (K.Mods = kbCtrlShift), 'Ctrl+A -> A, ctrl');
  K := KeyMake(kbAltQ);
  Check((K.Code = Ord('Q')) and (K.Mods = kbAltShift), 'Alt+Q -> Q, alt');
  K := KeyMake(kbShiftF1);
  Check((K.Code = kbF1) and (K.Mods = kbShift), 'Shift+F1 -> F1, shift');
  K := KeyMake(kbCtrlF10);
  Check((K.Code = kbF10) and (K.Mods = kbCtrlShift), 'Ctrl+F10 -> F10, ctrl');
  K := KeyMake(kbAltF3);
  Check((K.Code = kbF3) and (K.Mods = kbAltShift), 'Alt+F3 -> F3, alt');
  K := KeyMake(kbCtrlLeft);
  Check((K.Code = kbLeft) and (K.Mods = kbCtrlShift), 'Ctrl+Left -> Left, ctrl');
  K := KeyMake(kbCtrlBack);
  Check((K.Code = kbBack) and (K.Mods = kbCtrlShift), 'Ctrl+Backspace');
  K := KeyMake(kbCtrlEnter);
  Check((K.Code = kbEnter) and (K.Mods = kbCtrlShift), 'Ctrl+Enter');
  K := KeyMake(kbAlt5);
  Check((K.Code = Ord('5')) and (K.Mods = kbAltShift), 'Alt+5 -> 5, alt');
  K := KeyMake(kbShiftTab);
  Check((K.Code = kbTab) and (K.Mods = kbShift), 'Shift+Tab -> Tab, shift');
  K := KeyMake(kbAltEnter);
  Check((K.Code = kbEnter) and (K.Mods = kbAltShift), 'Alt+Enter');
  K := KeyMake(kbF11);
  Check((K.Code = kbF11) and (K.Mods = 0), 'F11');
  K := KeyMake(kbCtrlPrtSc);
  Check((K.Code = kbCtrlPrtSc) and (K.Mods = kbCtrlShift), 'Ctrl+PrtSc');

  { keys that stay as they are }
  K := KeyMake(kbEnter);
  Check((K.Code = kbEnter) and (K.Mods = 0), 'Enter is unchanged');
  K := KeyMake(kbEsc);
  Check((K.Code = kbEsc) and (K.Mods = 0), 'Esc is unchanged');
  K := KeyMake(kbHome);
  Check((K.Code = kbHome) and (K.Mods = 0), 'Home is unchanged');

  { printable characters }
  K := KeyMake(Ord('a'));
  Check((K.Code = Ord('A')) and (K.Mods = 0), 'lowercase letters become uppercase');
  K := KeyMake(Ord('a'), kbShift);
  Check((K.Code = Ord('A')) and (K.Mods = kbShift), 'shift is kept');
  K := KeyMake($1E61);
  Check((K.Code = Ord('A')) and (K.Mods = 0), 'letter with its scan code');
  K := KeyMake($0231);
  Check(K.Code = Ord('1'), 'digit loses its scan code');
  K := KeyMake($372A);
  Check(K.Code = $372A, 'keypad * keeps its scan code');
  K := KeyMake($4E2B);
  Check(K.Code = $4E2B, 'keypad + keeps its scan code');

  { Ctrl+letter delivered as scan code and control character }
  K := KeyMake($1E01);
  Check((K.Code = Ord('A')) and (K.Mods = kbCtrlShift), 'raw Ctrl+A');
  K := KeyMake($320D);
  Check((K.Code = Ord('M')) and (K.Mods = kbCtrlShift), 'raw Ctrl+M (scan code of M, character 13)');
  K := KeyMake($3201);
  Check((K.Code = $3201) and (K.Mods = 0), 'scan code of M with character 1 is not a raw ctrl key');

  { only shift, ctrl and alt count }
  K := KeyMake(kbF2, kbScrollState or kbNumState or kbCapsState or kbInsState or kbPaste);
  Check((K.Code = kbF2) and (K.Mods = 0), 'lock states are ignored');
  K := KeyMake(kbF2, kbLeftShift);
  Check(K.Mods = kbShift, 'left shift is shift');
  K := KeyMake(kbF2, kbRightShift);
  Check(K.Mods = kbShift, 'right shift is shift');

  { no key }
  K := KeyMake(kbNoKey, kbShift or kbAltShift);
  Check((K.Code = 0) and (K.Mods = 0), 'no key has no modifiers');

  Check(not Same(KeyMake(kbF1), KeyMake(kbF2)), 'different keys differ');
  Check(not Same(KeyMake(kbF1), KeyMake(kbF1, kbShift)), 'different modifiers differ');

  Finish;
end.
