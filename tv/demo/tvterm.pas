program tvterm;
{ Demo of the terminal view (TvVtView): a window with a shell in it. tvterm [program [arguments]]; the default is $SHELL, else /bin/sh.
  Alt-X quits (also when the program of the window ends). Linux only. }
{$I ../src/tvdefs.inc}
uses SysUtils, TvGeom, TvEvents, TvKeys, TvViews, TvWindow, TvMenus, TvApp, TvUnix, TvVtView;

type
  TTermApp = object(TApplication)
    procedure InitMenuBar; virtual;
    procedure InitStatusLine; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure NewTerminal;
  end;

procedure TTermApp.InitMenuBar;
var
  R: TRect;
begin
  R := GetExtent;
  R.B.Y := R.A.Y + 1;
  New(MenuBar, Init(R, NewMenu(
    NewSubMenu('~F~ile', hcNoContext, NewMenu(
      NewItem('E~x~it', 'Alt-X', kbAltX, cmQuit, hcNoContext, nil)), nil))));
end;

procedure TTermApp.InitStatusLine;
var
  R: TRect;
begin
  R := GetExtent;
  R.A.Y := R.B.Y - 1;
  New(StatusLine, Init(R, NewStatusDef(0, $FFFF,
    NewStatusKey('~Alt-X~ Exit', kbAltX, cmQuit,
    NewStatusKey('~Shift-PgUp~ History', kbNoKey, 0, nil)), nil)));
end;

{ the keys that are not for the terminal }
function OwnKey(const Event: TEvent): Boolean;
begin
  Result := (Event.KeyCode = kbAltX) or (Event.KeyCode = kbAltF3);
end;

procedure TTermApp.NewTerminal;
var
  W: PWindow;
  V: PVtView;
  R: TRect;
  Prog: AnsiString;
  Args: array of AnsiString;
  I: Integer;
begin
  R := DeskTop^.GetExtent;
  New(W, Init(R, 'Terminal', 1));
  R := W^.GetExtent;
  R.Grow(-1, -1);
  if ParamCount >= 1 then
  begin
    Prog := ParamStr(1);
    SetLength(Args, ParamCount);
    for I := 1 to ParamCount do
      Args[I - 1] := ParamStr(I);
  end
  else
  begin
    Prog := GetEnvironmentVariable('SHELL');
    if Prog = '' then
      Prog := '/bin/sh';
    SetLength(Args, 1);
    Args[0] := Prog;
  end;
  New(V, Init(R, Prog, Args, ''));
  V^.KeyFilter := @OwnKey;
  W^.Insert(V);
  InsertWindow(W);
  V^.Select;
end;

procedure TTermApp.HandleEvent(var Event: TEvent);
begin
  inherited HandleEvent(Event);
  if (Event.What = evBroadcast) and (Event.Command = cmVtEnded) then
  begin
    Message(@Self, evCommand, cmQuit, nil);
    ClearEvent(Event);
  end;
end;

var
  App: TTermApp;
begin
  if not UnixInit then
  begin
    Writeln('tvterm needs a terminal');
    Halt(1);
  end;
  App.Init;
  App.NewTerminal;
  App.Run;
  App.Done;
  UnixDone;
end.
