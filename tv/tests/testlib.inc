{ Tiny test harness shared by tv/tests/test_*.pas: Check(), Done(). }
var
  TestFailed: Integer = 0;
  TestCount: Integer = 0;

procedure Check(Cond: Boolean; const Name: ShortString);
begin
  Inc(TestCount);
  if Cond then
    begin WriteLn('PASS ', Name); Flush(Output); end
  else
  begin
    WriteLn('FAIL ', Name);
    Inc(TestFailed);
  end;
end;

{ Heap marks to locate a leak: HeapMark(N) stores the heap in use since the baseline (set by
  HeapBase); Finish prints them when there are failed checks. }
var
  MarkVals: array[0..63] of Int64;
  MarkIds: array[0..63] of Integer;
  MarkCount: Integer = 0;
  MarkBase: Int64 = 0;

procedure HeapBase;
begin
  MarkBase := GetFPCHeapStatus.CurrHeapUsed;
end;

procedure HeapMark(Id: Integer);
begin
  if MarkCount <= High(MarkVals) then
  begin
    MarkVals[MarkCount] := Int64(GetFPCHeapStatus.CurrHeapUsed) - MarkBase;
    MarkIds[MarkCount] := Id;
    Inc(MarkCount);
  end;
end;

procedure Finish;
var
  I: Integer;
begin
  if (TestFailed > 0) and (MarkCount > 0) then
  begin
    Write('heap since the start:');
    for I := 0 to MarkCount - 1 do
      Write(' ', MarkIds[I], '=', MarkVals[I]);
    WriteLn;
  end;
  if TestFailed = 0 then
    WriteLn('ALL OK (', TestCount, ' checks)')
  else
  begin
    WriteLn(TestFailed, ' of ', TestCount, ' checks FAILED');
    Halt(1);
  end;
end;
