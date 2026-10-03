program t_vtkeys;
{$I ../src/tvdefs.inc}
uses TvEvents, TvKeys, TvVtKeys;
{$I testlib.inc}

function Key(Code: Word; Mods: Word): TEvent;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.What := evKeyDown;
  Result.KeyCode := Code;
  Result.ControlKeyState := Mods;
end;

function TextKey(const S: AnsiString; Mods: Word): TEvent;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.What := evKeyDown;
  Result.ControlKeyState := Mods;
  Result.TextLength := Length(S);
  Move(S[1], Result.Text[0], Length(S));
  if (Length(S) = 1) then
    Result.KeyCode := Ord(S[1]);
end;

begin
  Check(VtKeyBytes(TextKey('a', 0), False) = 'a', 'text: a');
  Check(VtKeyBytes(TextKey('п', 0), False) = 'п', 'text: UTF-8 goes as it is');
  Check(VtKeyBytes(TextKey('a', kbLeftAlt), False) = #27'a', 'Alt and a letter: ESC and the letter');
  Check(VtKeyBytes(TextKey('c', kbLeftCtrl), False) = #3, 'Ctrl-C');
  Check(VtKeyBytes(TextKey('[', kbLeftCtrl), False) = #27, 'Ctrl-[ is ESC');
  Check(VtKeyBytes(TextKey(' ', kbLeftCtrl), False) = #0, 'Ctrl-Space is NUL');
  Check(VtKeyBytes(Key(3, kbLeftCtrl), False) = #3, 'Ctrl-C by the key code (no text)');
  Check(VtKeyBytes(Key(kbEnter, 0), False) = #13, 'Enter');
  Check(VtKeyBytes(Key(kbEsc, 0), False) = #27, 'Esc');
  Check(VtKeyBytes(Key(kbBack, 0), False) = #127, 'Backspace is DEL');
  Check(VtKeyBytes(Key(kbTab, 0), False) = #9, 'Tab');
  Check(VtKeyBytes(Key(kbShiftTab, 0), False) = #27'[Z', 'Shift-Tab');
  Check(VtKeyBytes(Key(kbUp, 0), False) = #27'[A', 'Up');
  Check(VtKeyBytes(Key(kbUp, 0), True) = #27'OA', 'Up, application cursor keys');
  Check(VtKeyBytes(Key(kbLeft, kbLeftCtrl), True) = #27'[1;5D', 'Ctrl-Left has the modifier even in the application mode');
  Check(VtKeyBytes(Key(kbRight, kbLeftShift or kbLeftAlt), False) = #27'[1;4C', 'Shift-Alt-Right');
  Check(VtKeyBytes(Key(kbHome, 0), False) = #27'[H', 'Home');
  Check(VtKeyBytes(Key(kbEnd, 0), True) = #27'OF', 'End, application mode');
  Check(VtKeyBytes(Key(kbPgUp, 0), False) = #27'[5~', 'PgUp');
  Check(VtKeyBytes(Key(kbPgDn, kbLeftCtrl), False) = #27'[6;5~', 'Ctrl-PgDn');
  Check(VtKeyBytes(Key(kbIns, 0), False) = #27'[2~', 'Ins');
  Check(VtKeyBytes(Key(kbDel, 0), False) = #27'[3~', 'Del');
  Check(VtKeyBytes(Key(kbF1, 0), False) = #27'OP', 'F1');
  Check(VtKeyBytes(Key(kbF4, kbLeftShift), False) = #27'[1;2S', 'Shift-F4');
  Check(VtKeyBytes(Key(kbF5, 0), False) = #27'[15~', 'F5');
  Check(VtKeyBytes(Key(kbF6, 0), False) = #27'[17~', 'F6');
  Check(VtKeyBytes(Key(kbF9, 0), False) = #27'[20~', 'F9');
  Check(VtKeyBytes(Key(kbF10, 0), False) = #27'[21~', 'F10');
  Check(VtKeyBytes(Key(kbF11, 0), False) = #27'[23~', 'F11');
  Check(VtKeyBytes(Key(kbF12, kbLeftAlt), False) = #27'[24;3~', 'Alt-F12');
  Check(VtKeyBytes(Key(0, kbLeftShift), False) = '', 'a modifier alone has no bytes');

  Check(VtMouseBytes(1000, 1006, 4, 9, 0, True, False, 0, 0) = #27'[<0;5;10M', 'SGR: left press at (4, 9)');
  Check(VtMouseBytes(1000, 1006, 4, 9, 0, False, False, 0, 0) = #27'[<0;5;10m', 'SGR: left release');
  Check(VtMouseBytes(1000, 1006, 0, 0, 2, True, False, 0, kbLeftCtrl) = #27'[<18;1;1M', 'SGR: right press with Ctrl');
  Check(VtMouseBytes(1000, 1006, 0, 0, 0, True, False, 1, 0) = #27'[<64;1;1M', 'SGR: wheel up');
  Check(VtMouseBytes(1000, 1006, 0, 0, 0, True, False, 2, 0) = #27'[<65;1;1M', 'SGR: wheel down');
  Check(VtMouseBytes(1000, 0, 4, 9, 0, True, False, 0, 0) = #27'[M' + #32 + #37 + #42, 'X10 bytes: press');
  Check(VtMouseBytes(1000, 0, 4, 9, 0, False, False, 0, 0) = #27'[M' + #35 + #37 + #42, 'X10 bytes: release has the code 3');
  Check(VtMouseBytes(1000, 0, 300, 9, 0, True, False, 0, 0) = '', 'X10 bytes: a column that does not fit');
  Check(VtMouseBytes(1000, 1015, 4, 9, 0, True, False, 0, 0) = #27'[32;5;10M', 'urxvt: press');
  Check(VtMouseBytes(1000, 1006, 4, 9, 0, False, True, 0, 0) = '', '1000 does not report moves');
  Check(VtMouseBytes(1002, 1006, 4, 9, 0, False, True, 0, 0) = #27'[<32;5;10M', '1002: a move with the left button down');
  Check(VtMouseBytes(1002, 1006, 4, 9, -1, False, True, 0, 0) = '', '1002: a move with no button is not reported');
  Check(VtMouseBytes(1003, 1006, 4, 9, -1, False, True, 0, 0) = #27'[<35;5;10M', '1003: any move');
  Check(VtMouseBytes(0, 1006, 4, 9, 0, True, False, 0, 0) = '', 'no mouse mode: nothing');
  Check(VtMouseBytes(9, 0, 4, 9, 0, False, False, 0, 0) = '', 'mode 9: no releases');

  Check(VtPasteBytes('abc', False) = 'abc', 'paste: plain');
  Check(VtPasteBytes('abc', True) = #27'[200~abc'#27'[201~', 'paste: bracketed');
  Finish;
end.
