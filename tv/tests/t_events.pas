program t_events;
{$I ../src/tvdefs.inc}
uses TvGeom, TvKeys, TvEvents;
{$I testlib.inc}

var
  E: TEvent;
  K: TKey;
begin
  Check(evMouse = (evMouseDown or evMouseUp or evMouseMove or evMouseAuto or evMouseWheel),
    'evMouse is the union of the mouse events');
  Check((evMessage and evCommand <> 0) and (evMessage and evBroadcast <> 0), 'evMessage covers commands');
  Check(evMessage and evKeyDown = 0, 'evMessage does not cover keys');

  ClearEvent(E);
  Check((E.What = evNothing) and (E.ControlKeyState = 0), 'ClearEvent');

  { key code aliases its character and scan code }
  E.KeyCode := $1C0D;
  Check((E.CharCode = $0D) and (E.ScanCode = $1C), 'KeyCode = ScanCode shl 8 + CharCode');
  E.CharCode := $41;
  E.ScanCode := $1E;
  Check(E.KeyCode = $1E41, 'CharCode and ScanCode make the KeyCode');

  { message information aliases }
  E.InfoLong := $12345678;
  Check(E.InfoWord = $5678, 'InfoWord is the low word of InfoLong');
  Check(E.InfoByte = $78, 'InfoByte is the low byte');
  E.InfoPtr := nil;
  Check(E.InfoLong = 0, 'InfoPtr and InfoLong overlay');
  E.InfoInt := -2;
  Check(E.InfoWord = $FFFE, 'InfoInt is a signed InfoWord');

  { mouse part }
  ClearEvent(E);
  E.What := evMouseDown;
  E.Where.X := 12;
  E.Where.Y := 5;
  E.Buttons := mbLeftButton or mbRightButton;
  E.EventFlags := meDoubleClick;
  Check((E.Where.X = 12) and (E.Where.Y = 5) and (E.Buttons = 3) and (E.EventFlags = meDoubleClick), 'mouse fields');

  { key events }
  MakeKeyEvent(E, Ord('x'), kbShift);
  Check((E.What = evKeyDown) and (E.ControlKeyState = kbShift), 'MakeKeyEvent');
  Check(EventText(E) = 'x', 'text of a printable key');
  K := EventKey(E);
  Check((K.Code = Ord('X')) and (K.Mods = kbShift), 'EventKey normalizes');
  MakeKeyEvent(E, kbF1, 0);
  Check(EventText(E) = '', 'no text for a function key');
  Check(EventKey(E).Code = kbF1, 'EventKey of F1');

  { UTF-8 text }
  ClearEvent(E);
  E.What := evKeyDown;
  E.Text[0] := #$C3;
  E.Text[1] := #$A9;
  E.TextLength := 2;
  Check(EventText(E) = #$C3#$A9, 'UTF-8 text of a key event');
  E.TextLength := 9;
  Check(Length(EventText(E)) = 4, 'text length is capped');

  Finish;
end.
