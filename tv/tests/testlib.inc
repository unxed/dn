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

procedure Finish;
begin
  if TestFailed = 0 then
    WriteLn('ALL OK (', TestCount, ' checks)')
  else
  begin
    WriteLn(TestFailed, ' of ', TestCount, ' checks FAILED');
    Halt(1);
  end;
end;
