program t_timer;
{$I ../src/tvdefs.inc}
uses TvSys, TvTimer;
{$I testlib.inc}

var
  Now: Int64 = 1000;
  Q: TTimerQueue;
  Fired: array[0..15] of Pointer;
  FiredCount: Integer = 0;
  A, B, C: TTimerId;
  Used0: PtrUInt;

function FakeClock: Int64;
begin
  Result := Now;
end;

procedure Record_(Id: TTimerId; Args: Pointer);
begin
  Fired[FiredCount] := Id;
  Inc(FiredCount);
end;

{ kills another timer while the timers are processed }
procedure KillOther(Id: TTimerId; Args: Pointer);
begin
  Fired[FiredCount] := Id;
  Inc(FiredCount);
  Q.KillTimer(Args);
end;

function Collect: Integer;
begin
  FiredCount := 0;
  Q.CollectExpiredTimers(@Record_, nil);
  Result := FiredCount;
end;

begin
  Used0 := GetFPCHeapStatus.CurrHeapUsed;
  Q.Init(@FakeClock);
  Check(Q.TimeUntilNextTimeout = -1, 'no timers: -1');
  Check(Collect = 0, 'nothing to collect');

  A := Q.SetTimer(100);
  Check(Q.TimeUntilNextTimeout = 100, 'time until the timer');
  Now := 1040;
  Check(Q.TimeUntilNextTimeout = 60, 'it shrinks with the clock');
  Check(Collect = 0, 'not yet expired');
  Now := 1100;
  Check(Q.TimeUntilNextTimeout = 0, 'expired: 0');
  Check((Collect = 1) and (Fired[0] = A), 'a one-shot timer fires');
  Check(Collect = 0, 'and only once');
  Check(Q.First = nil, 'a one-shot timer is removed');

  { several timers, the nearest counts }
  A := Q.SetTimer(500);
  B := Q.SetTimer(200);
  Check(Q.TimeUntilNextTimeout = 200, 'the nearest timer counts');
  Now := Now + 250;
  Check((Collect = 1) and (Fired[0] = B), 'only the expired one fires');
  Check(Q.TimeUntilNextTimeout = 250, 'then the next');
  Q.KillTimer(A);
  Check(Q.TimeUntilNextTimeout = -1, 'KillTimer removes a timer');
  Q.KillTimer(A);
  Check(True, 'killing a timer that is gone does nothing');

  { periodic timers fire once per collection, however late, and keep their phase }
  A := Q.SetTimer(100, 100);
  Now := Now + 100;
  Check((Collect = 1) and (Fired[0] = A), 'a periodic timer fires');
  Check(Q.First <> nil, 'and stays');
  Check(Q.TimeUntilNextTimeout = 100, 'next in one period');
  Now := Now + 450;
  Check(Collect = 1, 'a late periodic timer fires once');
  Check(Q.TimeUntilNextTimeout = 50, 'and keeps its phase (the next tick at +500)');
  Q.KillTimer(A);

  { period 0 timers (fire at every collection) }
  A := Q.SetTimer(0, 0);
  Check(Collect = 1, 'a timer with period 0 fires');
  Check(Collect = 1, 'and fires again at the next collection');
  Q.KillTimer(A);

  { a handler that kills another timer that is also expired }
  A := Q.SetTimer(10);
  B := Q.SetTimer(10);
  Now := Now + 20;
  FiredCount := 0;
  Q.CollectExpiredTimers(@KillOther, B);
  Check((FiredCount = 1) and (Fired[0] = A) and (Q.First = nil), 'a handler may kill other timers');

  Q.Done;
  Check(GetFPCHeapStatus.CurrHeapUsed = Used0, 'no memory is left behind');

  { the default clock moves forward }
  Check(ClockMs >= 0, 'the system clock');
  Finish;
end.
