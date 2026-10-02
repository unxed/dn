program t_mouse;
{$I ../src/tvdefs.inc}
uses TvGeom, TvEvents, TvKeys, TvMouse;
{$I testlib.inc}

var
  S: TMouseState;
  Ev: TEvent;
  Now: Int64 = 10000;

function St(X, Y: Integer; Btn: Byte; Wheel: Byte = 0): TMouseState;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Where.X := X;
  Result.Where.Y := Y;
  Result.Buttons := Btn;
  Result.Wheel := Wheel;
end;

procedure Step(const S: TMouseState);
begin
  MouseStep(S, Now, Ev);
end;

begin
  MouseQueueReset;
  Step(St(5, 5, 0));
  Check(Ev.What = evMouseMove, 'the first position differs from (0,0): a move');
  Step(St(5, 5, 0));
  Check(Ev.What = evNothing, 'nothing happens: no event');
  Step(St(6, 5, 0));
  Check((Ev.What = evMouseMove) and (Ev.Where.X = 6) and (Ev.Buttons = 0) and
    ((Ev.EventFlags and meMouseMoved) <> 0), 'the mouse moves: evMouseMove');
  Step(St(6, 5, 0));
  Check(Ev.What = evNothing, 'the same state again: no event');

  { press, release }
  Step(St(6, 5, 1));
  Check((Ev.What = evMouseDown) and (Ev.Buttons = 1) and (Ev.Where.X = 6), 'a button goes down');
  Check(Ev.EventFlags = 0, 'a first click is a single click');
  Step(St(6, 5, 1));
  Check(Ev.What = evNothing, 'held: nothing at once');
  Inc(Now, 300);
  Step(St(6, 5, 1));
  Check(Ev.What = evNothing, 'not held long enough for the first repeat');
  Inc(Now, 200);
  Step(St(6, 5, 1));
  Check((Ev.What = evMouseAuto) and (Ev.Buttons = 1), 'held: evMouseAuto after the repeat delay');
  Step(St(6, 5, 1));
  Check(Ev.What = evNothing, 'and not at once again');
  Inc(Now, 60);
  Step(St(6, 5, 1));
  Check(Ev.What = evMouseAuto, 'then every auto delay');
  Step(St(7, 5, 1));
  Check((Ev.What = evMouseMove) and (Ev.Buttons = 1), 'dragging: evMouseMove with the button');
  Step(St(7, 5, 0));
  Check((Ev.What = evMouseUp) and (Ev.Buttons = 1) and (Ev.Where.X = 7), 'release: evMouseUp tells which button');
  Step(St(7, 5, 0));
  Check(Ev.What = evNothing, 'and then nothing');

  { release away from the press: move first, then up }
  Inc(Now, 1000);
  Step(St(7, 5, 2));
  Check((Ev.What = evMouseDown) and (Ev.Buttons = 2), 'right button down');
  Step(St(20, 9, 0));
  Check((Ev.What = evMouseMove) and (Ev.Where.X = 20) and (Ev.Buttons = 2), 'moved and released at once: the move first');
  Step(St(20, 9, 0));
  Check((Ev.What = evMouseUp) and (Ev.Buttons = 2) and (Ev.Where.X = 20), 'the up next');
  Step(St(20, 9, 0));
  Check(Ev.What = evNothing, 'and then nothing');

  { double and triple clicks }
  Inc(Now, 2000);
  Step(St(3, 3, 1));
  Check(Ev.EventFlags = 0, 'click 1');
  Step(St(3, 3, 0));
  Inc(Now, 100);
  Step(St(3, 3, 1));
  Check((Ev.What = evMouseDown) and (Ev.EventFlags = meDoubleClick), 'click 2: double click');
  Step(St(3, 3, 0));
  Inc(Now, 100);
  Step(St(3, 3, 1));
  Check(Ev.EventFlags = meTripleClick, 'click 3: triple click');
  Step(St(3, 3, 0));
  Inc(Now, 100);
  Step(St(3, 3, 1));
  Check(Ev.EventFlags = 0, 'click 4: single again');
  Step(St(3, 3, 0));
  Inc(Now, 600);
  Step(St(3, 3, 1));
  Check(Ev.EventFlags = 0, 'too slow: single click');
  Step(St(3, 3, 0));
  Inc(Now, 100);
  Step(St(4, 3, 1));
  Check(Ev.EventFlags = 0, 'another place: single click');
  Step(St(4, 3, 0));
  Inc(Now, 100);
  Step(St(4, 3, 2));
  Check(Ev.EventFlags = 0, 'another button: single click');
  Step(St(4, 3, 0));

  { wheel }
  Step(St(4, 3, 0, mwDown));
  Check((Ev.What = evMouseWheel) and (Ev.Wheel = mwDown), 'wheel');
  Step(St(4, 3, 0));
  Check(Ev.What = evNothing, 'the wheel is an event, not a state');

  { reversed buttons }
  MouseReverse := True;
  Step(St(4, 3, 1));
  Check((Ev.What = evMouseDown) and (Ev.Buttons = 2), 'reversed: left is right');
  Step(St(4, 3, 0));
  Step(St(4, 3, 3));
  Check((Ev.What = evMouseDown) and (Ev.Buttons = 3), 'both buttons stay both');
  MouseReverse := False;
  Step(St(4, 3, 0));

  { the control keys of the state go to the event }
  MouseQueueReset;
  S := St(1, 1, 1);
  S.ControlKeyState := kbShift;
  MouseStep(S, 0, Ev);
  Check((Ev.What = evMouseDown) and (Ev.ControlKeyState = kbShift), 'ControlKeyState is passed on');
  Finish;
end.
