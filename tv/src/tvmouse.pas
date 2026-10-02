{ TvMouse: turns the state of the mouse (position, buttons, wheel), polled by a backend,
  into mouse events: down, up, move, auto-repeat, wheel, double and triple click.

  Translated from magiblot/tvision @ b4831e2:
    source/tvision/tevent.cpp (TEventQueue::getMouseEvent and its variables)
  Borland disclaimer and MIT notice: tv/COPYRIGHT.magiblot.

  Differences from the C++ original: times are milliseconds (the original counts BIOS
  ticks of 55 ms: the delays are 8 ticks = 440 ms for a double click and for the first
  repeat, then 1 tick), and they can be changed through the variables below. }
unit TvMouse;

{$I tvdefs.inc}

interface

uses
  TvGeom, TvEvents;

type
  TMouseState = record
    Where: TPoint;
    Buttons: Byte;
    Wheel: Byte;           { an event, not a state: reported once }
    ControlKeyState: Word;
  end;

var
  DoubleDelayMs: Integer = 440;   { two presses closer than this are a double click }
  RepeatDelayMs: Integer = 440;   { before the first evMouseAuto }
  AutoDelayMs: Integer = 55;      { between evMouseAuto events }
  { swap the left and right buttons }
  MouseReverse: Boolean = False;

{ Forgets the previous state (the buttons are up). }
procedure MouseQueueReset;
{ Compares State (read at Now) with the previous one and gives the event it means
  (Event.What = evNothing if none). Call it again after an evMouseMove that left
  a mouse up pending: the up comes next. }
procedure MouseStep(const State: TMouseState; Now: Int64; var Event: TEvent);

implementation

type
  TMouseRec = record
    Where: TPoint;
    Buttons: Byte;
    EventFlags: Word;
    Wheel: Byte;
  end;

var
  LastMouse, DownMouse: TMouseRec;
  PendingMouseUp: Boolean = False;
  DownTicks, AutoTicks: Int64;
  AutoDelay: Integer;

procedure MouseQueueReset;
begin
  FillChar(LastMouse, SizeOf(LastMouse), 0);
  FillChar(DownMouse, SizeOf(DownMouse), 0);
  PendingMouseUp := False;
  DownTicks := 0;
  AutoTicks := 0;
  AutoDelay := 0;
end;

procedure SetEvent(var Event: TEvent; What: Word; const M: TMouseRec; Keys: Word);
begin
  ClearEvent(Event);
  Event.What := What;
  Event.ControlKeyState := Keys;
  Event.Where := M.Where;
  Event.EventFlags := M.EventFlags;
  Event.Buttons := M.Buttons;
  Event.Wheel := M.Wheel;
end;

procedure MouseStep(const State: TMouseState; Now: Int64; var Event: TEvent);
var
  Cur, Up: TMouseRec;
  Btn: Byte;
  Keys: Word;
begin
  Keys := State.ControlKeyState;
  if PendingMouseUp then
  begin
    SetEvent(Event, evMouseUp, LastMouse, Keys);
    LastMouse.Buttons := 0;
    PendingMouseUp := False;
    Exit;
  end;
  Cur.Where := State.Where;
  Cur.Buttons := State.Buttons;
  Cur.Wheel := State.Wheel;
  Cur.EventFlags := 0;
  if MouseReverse and (Cur.Buttons <> 0) and (Cur.Buttons <> 3) then
    Cur.Buttons := Cur.Buttons xor 3;

  { the buttons went up }
  if (Cur.Buttons = 0) and (LastMouse.Buttons <> 0) then
  begin
    if PointEq(Cur.Where, LastMouse.Where) then
    begin
      Btn := LastMouse.Buttons;
      LastMouse := Cur;
      Cur.Buttons := Btn;
      SetEvent(Event, evMouseUp, Cur, Keys);
    end
    else
    begin
      { moved and released at once: the move comes first, the up next }
      Up := Cur;
      Cur := LastMouse;
      Cur.Where := Up.Where;
      Cur.EventFlags := Cur.EventFlags or meMouseMoved;
      Up.Buttons := LastMouse.Buttons;
      LastMouse := Up;
      PendingMouseUp := True;
      SetEvent(Event, evMouseMove, Cur, Keys);
    end;
    Exit;
  end;

  { a button went down }
  if (Cur.Buttons <> 0) and (LastMouse.Buttons = 0) then
  begin
    if (Cur.Buttons = DownMouse.Buttons) and PointEq(Cur.Where, DownMouse.Where) and
      (Now - DownTicks <= DoubleDelayMs) then
    begin
      if (DownMouse.EventFlags and (meDoubleClick or meTripleClick)) = 0 then
        Cur.EventFlags := Cur.EventFlags or meDoubleClick
      else if (DownMouse.EventFlags and meDoubleClick) <> 0 then
      begin
        Cur.EventFlags := Cur.EventFlags and not meDoubleClick;
        Cur.EventFlags := Cur.EventFlags or meTripleClick;
      end;
    end;
    DownMouse := Cur;
    DownTicks := Now;
    AutoTicks := Now;
    AutoDelay := RepeatDelayMs;
    LastMouse := Cur;
    SetEvent(Event, evMouseDown, Cur, Keys);
    Exit;
  end;

  Cur.Buttons := LastMouse.Buttons;

  if Cur.Wheel <> 0 then
  begin
    LastMouse := Cur;
    SetEvent(Event, evMouseWheel, Cur, Keys);
    Exit;
  end;

  if not PointEq(Cur.Where, LastMouse.Where) then
  begin
    Cur.EventFlags := Cur.EventFlags or meMouseMoved;
    LastMouse := Cur;
    SetEvent(Event, evMouseMove, Cur, Keys);
    Exit;
  end;

  if (Cur.Buttons <> 0) and (Now - AutoTicks > AutoDelay) then
  begin
    AutoTicks := Now;
    AutoDelay := AutoDelayMs;
    LastMouse := Cur;
    SetEvent(Event, evMouseAuto, Cur, Keys);
    Exit;
  end;

  ClearEvent(Event);
end;

initialization
  MouseQueueReset;
end.
