program t_util;
{$I ../src/tvdefs.inc}
uses TvCodePg, TvKeys, TvEvents, TvUtil;
{$I testlib.inc}

var
  Ev: TEvent;
  P: PStr;
  Used0: PtrUInt;
begin
  { hot key strings }
  Check(HotKeyStr('~F~ile') = 'F', 'HotKeyStr: one letter');
  Check(HotKeyStr('Save ~a~s...') = 'a', 'HotKeyStr: in the middle');
  Check(HotKeyStr('No hot key') = '', 'HotKeyStr: none');
  Check(HotKeyStr('Unclosed ~tilde') = 'tilde', 'HotKeyStr: an unclosed ~ runs to the end');
  Check(HotKey('~f~ile') = 'F', 'HotKey: upper case');
  Check(HotKey('file') = #0, 'HotKey: none');
  Check(CStrLen('~F~ile') = 4, 'CStrLen ignores ~');
  Check(CStrLen('') = 0, 'CStrLen of an empty string');

  { Alt keys }
  Check(GetAltCode('F') = kbAltF, 'GetAltCode: Alt+F');
  Check(GetAltCode('f') = kbAltF, 'GetAltCode: lower case');
  Check(GetAltCode('1') = kbAlt1, 'GetAltCode: Alt+1');
  Check(GetAltCode('=') = kbAltEqual, 'GetAltCode: Alt+=');
  Check(GetAltCode(#$F0) = kbAltSpace, 'GetAltCode: Alt+Space');
  Check(GetAltCode(#0) = 0, 'GetAltCode: none');
  Check(GetAltCode('!') = 0, 'GetAltCode: no key');
  Check(GetAltChar(kbAltX) = 'X', 'GetAltChar: Alt+X');
  Check(GetAltChar(kbAlt3) = '3', 'GetAltChar: Alt+3');
  Check(GetAltChar(kbF1) = #0, 'GetAltChar: not an Alt key');
  Check(GetAltChar(kbAltSpace) = #$F0, 'GetAltChar: Alt+Space');
  MakeKeyEvent(Ev, kbAltF, kbAltShift);
  Check(GetAltCharStr(Ev) = 'F', 'GetAltCharStr from the scan code');
  { an Alt key with text (a character the scan code does not tell) }
  MakeKeyEvent(Ev, $0000, kbAltShift);
  Ev.Text[0] := #$D0; Ev.Text[1] := #$A4; Ev.TextLength := 2;
  Check(GetAltCharStr(Ev) = #$D0#$A4, 'GetAltCharStr: the text of the event');
  { Ctrl keys }
  Check(GetCtrlChar(kbCtrlB) = 'B', 'GetCtrlChar: Ctrl+B');
  Check(GetCtrlChar(kbCtrlZ) = 'Z', 'GetCtrlChar: Ctrl+Z');
  Check(GetCtrlChar($0041) = #0, 'GetCtrlChar: a letter is not a control key');
  Check(GetCtrlCode('b') = (GetAltCode('B') or 2), 'GetCtrlCode: Ctrl+B');

  { comparing ignoring case }
  Check(EqualsIgnoreCase('File', 'fILE'), 'EqualsIgnoreCase: ASCII');
  Check(not EqualsIgnoreCase('File', 'Fil'), 'EqualsIgnoreCase: different lengths');
  Check(not EqualsIgnoreCase('a', 'b'), 'EqualsIgnoreCase: different letters');
  Check(EqualsIgnoreCase('Ф', 'ф'), 'EqualsIgnoreCase: Cyrillic');
  Check(EqualsIgnoreCase('Ё', 'ё'), 'EqualsIgnoreCase: Cyrillic YO');
  Check(EqualsIgnoreCase('É', 'é'), 'EqualsIgnoreCase: Latin-1');
  Check(EqualsIgnoreCase('Ω', 'ω'), 'EqualsIgnoreCase: Greek');
  Check(not EqualsIgnoreCase('×', 'ö'), 'EqualsIgnoreCase: the multiplication sign has no case');
  CpSelect(866);
  Check(EqualsIgnoreCase(#$84, 'д'), 'EqualsIgnoreCase: a code page byte (CP866 "Д") equals UTF-8');
  Check(EqualsIgnoreCase('', ''), 'EqualsIgnoreCase: two empty strings');

  { copies of strings }
  P := NewStr('hello');
  Check((P <> nil) and (P^ = 'hello'), 'NewStr');
  DisposeStr(P);
  DisposeStr(nil);
  Check(True, 'DisposeStr accepts nil');
  Finish;
end.
