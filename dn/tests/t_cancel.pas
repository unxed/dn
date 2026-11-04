program t_cancel;
{$mode objfpc}{$H-}
uses Commands, Cancel, MainApp, TvMem;
{$I dntest.inc}
var
  App: TProgram;
  Token: TCancelToken;
begin
  MemInit(80, 25);
  App := TProgram.Create;
  try
    Token.Cancelled := True;
    Token.Reason := 'stale';
    Reset(Token);
    Check(not Token.Cancelled, 'Reset clears cancellation');
    Check(Token.Reason = '', 'Reset clears the reason');
    MemKey(Ord('x'));
    Check(not PollCancel(Token), 'a non-Esc key does not cancel');
    Check(MemPending = 0, 'PollCancel consumes the non-Esc key as before');
    Reset(Token);
    MemKey(kbESC);
    Check(PollCancel(Token), 'PollCancel reports Esc');
    Check(Token.Cancelled, 'Esc sets the cancellation state');
    Check(Token.Reason = 'Esc', 'Esc records the cancellation reason');
  finally
    App.Free;
    MemDone;
  end;
  Finish;
end.
