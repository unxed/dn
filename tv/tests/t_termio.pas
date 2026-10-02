program t_termio;
{$I ../src/tvdefs.inc}
uses SysUtils, TvEvents, TvKeys, TvCodePg, TvTermIO;
{$I testlib.inc}

var
  Bytes: string;
  BytePos: Integer;
  Input: TTermInput;
  State: TInputState;

function Reader(TimeoutMs: Integer): Integer;
begin
  if BytePos <= Length(Bytes) then
  begin
    Result := Ord(Bytes[BytePos]);
    Inc(BytePos);
  end
  else
    Result := -1;
end;

{ feeds the bytes and parses one event }
function Parse(const S: string; var Ev: TEvent): Boolean;
begin
  Bytes := S;
  BytePos := 1;
  Input.Init(@Reader, 1);
  Result := ParseEvent(Input, Ev, State);
end;

function Key(const S: string): Word;
var
  Ev: TEvent;
begin
  if Parse(S, Ev) and (Ev.What = evKeyDown) then
    Result := Ev.KeyCode
  else
    Result := $FFFF;
end;

function Mods(const S: string): Word;
var
  Ev: TEvent;
begin
  if Parse(S, Ev) then
    Result := Ev.ControlKeyState
  else
    Result := $FFFF;
end;

const
  E = #27;

var
  Ev: TEvent;
begin
  FillChar(State, SizeOf(State), 0);
  CpSelect(cpIdCp866);

  { plain keys }
  Check(Key('a') = Ord('a'), 'a');
  Check(Parse('a', Ev) and (Ev.TextLength = 1) and (Ev.Text[0] = 'a'), 'a has its text');
  Check(Key(#1) = kbCtrlA, 'Ctrl+A');
  Check(Mods(#1) = kbLeftCtrl, 'Ctrl+A: the Ctrl bit');
  Check(Key(#13) = kbEnter, 'Enter (CR)');
  Check(Key(#10) = kbEnter, 'Enter (LF)');
  Check(Key(#9) = kbTab, 'Tab');
  Check(Key(#127) = kbBack, 'Backspace (DEL)');
  Check(Key(#8) = kbBack, 'Backspace (BS)');
  Check(Key(E) = kbEsc, 'Esc alone');
  Check(Key(E + 'x') = kbAltX, 'Alt+X (Esc, x)');
  Check(Mods(E + 'x') = kbLeftAlt, 'Alt+X: the Alt bit');
  Check(Key(E + '5') = kbAlt5, 'Alt+5');
  Check(Key(E + #127) = kbAltBack, 'Alt+Backspace');
  Check(Key(E + E) = kbAltEsc, 'Alt+Esc (Esc Esc)');

  { UTF-8 text: the character code is that of the code page 866 }
  Check(Parse(#$D1#$8F, Ev) and (Ev.TextLength = 2) and (Ev.CharCode = $EF), 'UTF-8 "ya": 2 bytes, CP866 code $EF');
  Check(Parse(#$E2#$82#$AC, Ev) and (Ev.TextLength = 3) and (Ev.CharCode = 0), 'the euro sign: 3 bytes, no code in CP866');

  { arrows and others: xterm, with and without modifiers }
  Check(Key(E + '[A') = kbUp, 'Up');
  Check(Key(E + '[D') = kbLeft, 'Left');
  Check(Key(E + '[H') = kbHome, 'Home (CSI H)');
  Check(Key(E + '[F') = kbEnd, 'End (CSI F)');
  Check(Key(E + '[1~') = kbHome, 'Home (CSI 1 ~)');
  Check(Key(E + '[3~') = kbDel, 'Del');
  Check(Key(E + '[2~') = kbIns, 'Ins');
  Check(Key(E + '[5~') = kbPgUp, 'PgUp');
  Check(Key(E + '[6~') = kbPgDn, 'PgDn');
  Check(Key(E + '[Z') = kbShiftTab, 'Shift+Tab (CSI Z)');
  Check(Key(E + '[1;2A') = kbUp, 'Shift+Up: the key is Up');
  Check(Mods(E + '[1;2A') = kbShift, 'Shift+Up: the Shift bit');
  Check(Key(E + '[1;5C') = kbCtrlRight, 'Ctrl+Right');
  Check(Key(E + '[1;3D') = kbAltLeft, 'Alt+Left');
  Check(Key(E + '[3;2~') = kbShiftDel, 'Shift+Del');
  Check(Key(E + '[3;5~') = kbCtrlDel, 'Ctrl+Del');

  { function keys }
  Check(Key(E + 'OP') = kbF1, 'F1 (SS3 P)');
  Check(Key(E + 'OS') = kbF4, 'F4 (SS3 S)');
  Check(Key(E + 'O2P') = kbShiftF1, 'Shift+F1 (SS3 2 P)');
  Check(Key(E + '[15~') = kbF5, 'F5');
  Check(Key(E + '[21~') = kbF10, 'F10');
  Check(Key(E + '[23~') = kbShiftF1, 'F11 of xterm is Shift+F1 (as Putty and the Linux console)');
  Check(Key(E + '[15;5~') = kbCtrlF5, 'Ctrl+F5');
  Check(Key(E + '[24;3~') = kbAltF12, 'Alt+F12');
  Check(Key(E + '[[A') = kbF1, 'F1 of the Linux console (CSI [ A)');
  Check(Key(E + '[[E') = kbF5, 'F5 of the Linux console');

  { the protocols for modifiers }
  Check(Key(E + '[97;5u') = kbCtrlA, 'kitty: Ctrl+A');
  Check(Key(E + '[27;5;97~') = kbCtrlA, 'modifyOtherKeys: Ctrl+A');
  Check(Key(E + '[13;5u') = kbCtrlEnter, 'kitty: Ctrl+Enter');
  Check(Parse(E + '[1;5:3u', Ev) = False, 'kitty: a release is ignored');
  Check(Parse(E + '[1080u', Ev) and (Ev.TextLength = 2) and (Ev.CharCode = $A8), 'kitty: a Cyrillic letter (U+0438 = CP866 $A8)');

  { mouse }
  FillChar(State, SizeOf(State), 0);
  Check(Parse(E + '[<0;10;5M', Ev) and (Ev.What = evMouse) and (Ev.Where.X = 9) and (Ev.Where.Y = 4) and
    (Ev.Buttons = mbLeftButton), 'SGR mouse: the left button down at 9,4 (zero based)');
  Check(Parse(E + '[<32;11;5M', Ev) and (Ev.Buttons = mbLeftButton) and (Ev.Where.X = 10), 'SGR mouse: a drag keeps the button');
  Check(Parse(E + '[<0;11;5m', Ev) and (Ev.Buttons = 0), 'SGR mouse: release');
  Check(Parse(E + '[<2;1;1M', Ev) and (Ev.Buttons = mbRightButton), 'SGR mouse: the right button');
  Check(Parse(E + '[<2;1;1m', Ev) and (Ev.Buttons = 0), '... and up');
  Check(Parse(E + '[<64;3;3M', Ev) and (Ev.Wheel = mwUp), 'SGR mouse: wheel up');
  Check(Parse(E + '[<65;3;3M', Ev) and (Ev.Wheel = mwDown), 'SGR mouse: wheel down');
  Check(Parse(E + '[<16;3;3M', Ev) and ((Ev.ControlKeyState and kbLeftCtrl) <> 0), 'SGR mouse: Ctrl held');
  Check(Parse(E + '[M' + #32 + #43 + #37, Ev) and (Ev.Where.X = 10) and (Ev.Where.Y = 4) and (Ev.Buttons = mbLeftButton),
    'X10 mouse: the left button at 10,4');
  Check(Parse(E + '[M' + #35 + #43 + #37, Ev) and (Ev.Buttons = 0), 'X10 mouse: release');

  { what is not a key }
  Check(Parse(E + '[200~', Ev) = False, 'the start of a paste is not a key');
  Check(State.BracketedPaste, '... it is remembered');
  Check(Parse('v', Ev) and ((Ev.ControlKeyState and kbPaste) <> 0), 'a key of the paste has kbPaste');
  Check(Parse(E + '[201~', Ev) = False, 'the end of a paste');
  Check(not State.BracketedPaste, '... it is remembered');
  Check(Parse(E + ']52;c;AAAA' + #7 + 'x', Ev) = False, 'an OSC answer is skipped to the BEL');
  Check(BytePos = Length(Bytes), '... and the next byte is left');
  Check(Parse(E + '[12;34R', Ev) = False, 'the answer with the position of the cursor is skipped');
  Check(Parse('', Ev) = False, 'no input, no event');

  { a sequence that the program does not know is not lost as keys: Esc and Alt+key }
  Check(Key(E + '[99;99;99;99;99;99;99X') <> kbEsc, 'a too long sequence is not an Esc');

  Finish;
end.
