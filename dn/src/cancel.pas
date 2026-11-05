{ MIT, see LICENSE }
unit Cancel;

interface

uses
  Drivers, Commands;

type
  TCancelToken = record
    Cancelled: Boolean;
    Reason: String;
  end;

procedure Reset(var Token: TCancelToken);
function PollCancel(var Token: TCancelToken): Boolean;

implementation

uses
  MainApp;

procedure Reset(var Token: TCancelToken);
  begin
  Token.Cancelled := False;
  Token.Reason := '';
  end;

function PollCancel(var Token: TCancelToken): Boolean;
  var
    E: TEvent;
  begin
  if not Token.Cancelled then
    begin
    Application.Idle;
    GetKeyEvent(E);
    if (E.What = evKeyDown) and (DNKeyCode(E) = kbESC) then
      begin
      Token.Cancelled := True;
      Token.Reason := 'Esc';
      end;
    end;
  PollCancel := Token.Cancelled;
  end;

end.
