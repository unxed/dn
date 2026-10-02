{ TvTimer: queue of timers.

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/system.h (TTimerQueue), source/tvision/ttimerqu.cpp
  Borland disclaimer and MIT notice: tv/COPYRIGHT.magiblot.

  Differences from the C++ original: the clock is TvSys.ClockMs unless a clock
  function is given to Init (tests use a fake one); times are Int64 milliseconds,
  so they do not wrap. }
unit TvTimer;

{$I tvdefs.inc}

interface

uses
  TvSys;

type
  TTimerId = Pointer;
  TTimerProc = procedure(Id: TTimerId; Args: Pointer);

  PTimer = ^TTimer;
  TTimer = record
    ExpiresAt: Int64;
    Period: Integer;
    Next: PTimer;
    CollectId: Pointer;
  end;

  TTimerQueue = object
    First: PTimer;
    Clock: TClockProc;
    constructor Init(AClock: TClockProc = nil);
    destructor Done;
    { A one-shot timer (PeriodMs < 0) or a periodic one. }
    function SetTimer(TimeoutMs: LongWord; PeriodMs: Integer = -1): TTimerId;
    procedure KillTimer(Id: TTimerId);
    { Calls Func for every timer that has expired (once each, however late). }
    procedure CollectExpiredTimers(Func: TTimerProc; Args: Pointer);
    { Milliseconds until the first timer expires, 0 if one has, -1 if there are none. }
    function TimeUntilNextTimeout: Integer;
  private
    function Now: Int64;
  end;

implementation

constructor TTimerQueue.Init(AClock: TClockProc);
begin
  First := nil;
  Clock := AClock;
end;

destructor TTimerQueue.Done;
var
  T, N: PTimer;
begin
  T := First;
  while T <> nil do
  begin
    N := T^.Next;
    Dispose(T);
    T := N;
  end;
  First := nil;
end;

function TTimerQueue.Now: Int64;
begin
  if Assigned(Clock) then
    Result := Clock()
  else
    Result := ClockMs;
end;

function TTimerQueue.SetTimer(TimeoutMs: LongWord; PeriodMs: Integer): TTimerId;
var
  T: PTimer;
  P: ^PTimer;
begin
  New(T);
  FillChar(T^, SizeOf(TTimer), 0);
  T^.ExpiresAt := Now + TimeoutMs;
  T^.Period := PeriodMs;
  P := @First;
  while P^ <> nil do
    P := @P^^.Next;
  P^ := T;
  Result := T;
end;

procedure TTimerQueue.KillTimer(Id: TTimerId);
var
  P: ^PTimer;
begin
  P := @First;
  while P^ <> nil do
  begin
    if P^ = PTimer(Id) then
    begin
      P^ := PTimer(Id)^.Next;
      Dispose(PTimer(Id));
      Exit;
    end;
    P := @P^^.Next;
  end;
end;

{ Pre: ExpiresAt <= Now and Period > 0. }
function CalcNextExpiresAt(ExpiresAt, Now: Int64; Period: Integer): Int64;
begin
  Result := (1 + (Now - ExpiresAt + Period) div Period) * Period + ExpiresAt - Period;
end;

procedure TTimerQueue.CollectExpiredTimers(Func: TTimerProc; Args: Pointer);
var
  CollectId: Pointer;
  Cur: Int64;
  P: ^PTimer;
  Id: TTimerId;
  Nx, T: PTimer;
  Marker: Byte;
begin
  if First = nil then
    Exit;
  { The timer list may change while the timers are processed, so it is searched from
    the start every time; the timers already processed are marked with the id of this
    call. }
  CollectId := @Marker;
  Cur := Now;
  while True do
  begin
    P := @First;
    while (P^ <> nil) and ((P^^.CollectId <> nil) or (Cur < P^^.ExpiresAt)) do
      P := @P^^.Next;
    if P^ = nil then
      Break;
    Id := P^;
    if P^^.Period >= 0 then
    begin
      P^^.CollectId := CollectId;
      if P^^.Period > 0 then
        P^^.ExpiresAt := CalcNextExpiresAt(P^^.ExpiresAt, Cur, P^^.Period);
    end
    else
    begin
      { one-shot timer }
      Nx := P^^.Next;
      Dispose(P^);
      P^ := Nx;
    end;
    Func(Id, Args);   { may change the list }
  end;
  T := First;
  while T <> nil do
  begin
    if T^.CollectId = CollectId then
      T^.CollectId := nil;
    T := T^.Next;
  end;
end;

function TTimerQueue.TimeUntilNextTimeout: Integer;
var
  T: PTimer;
  Cur, Left: Int64;
begin
  if First = nil then
    Exit(-1);
  Cur := Now;
  Result := High(Integer);
  T := First;
  while T <> nil do
  begin
    if T^.ExpiresAt <= Cur then
      Exit(0);
    Left := T^.ExpiresAt - Cur;
    if Left < Result then
      Result := Integer(Left);
    T := T^.Next;
  end;
end;

end.
