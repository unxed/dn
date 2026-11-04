program t_cancel;
{$mode objfpc}{$H-}
uses Cancel;
{$I dntest.inc}
var
  Token: TCancelToken;
begin
  Token.Cancelled := True;
  Token.Reason := 'stale';
  Reset(Token);
  Check(not Token.Cancelled, 'Reset clears cancellation');
  Check(Token.Reason = '', 'Reset clears the reason');
  Token.Cancelled := True;
  Token.Reason := 'Esc';
  Check(PollCancel(Token), 'PollCancel reports an already cancelled token');
  Check(Token.Reason = 'Esc', 'PollCancel preserves the cancellation reason');
  Finish;
end.
