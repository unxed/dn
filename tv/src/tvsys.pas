{ TvSys: what the program needs from the system, as hooks set by a backend.

  Written for this port (the original has THardwareInfo, TEventQueue and TScreen for
  this); see tv/DESIGN.md. A backend (memory for tests, DOS, terminal) sets the hooks
  before the application is created. Without a backend there are no events and the
  clock is the system tick counter. }
unit TvSys;

{$I tvdefs.inc}

interface

uses
  SysUtils, TvEvents;

const
  { screen modes (BIOS numbers; smFont8x8 is a flag) }
  smBW80    = 2;
  smCO80    = 3;
  smMono    = 7;
  smFont8x8 = $100;
  smUpdate  = $FFFF;    { "the screen has changed: read its size again" }

type
  { Waits at most TimeoutMs milliseconds (-1: for ever) for an event and returns it in
    Event, or Event.What = evNothing. Mouse events have priority over key events. }
  TPollEventProc = procedure(TimeoutMs: Integer; var Event: TEvent);
  TClockProc = function: Int64;
  TVideoModeProc = procedure(Mode: Word);
  TNoArgProc = procedure;

var
  OnPollEvent: TPollEventProc = nil;
  { milliseconds since some moment; only differences matter }
  GetClockMs: TClockProc = nil;
  OnSetVideoMode: TVideoModeProc = nil;
  { the program is stopped (shell, ^Z) and continued }
  OnSuspend: TNoArgProc = nil;
  OnResume: TNoArgProc = nil;
  ScreenMode: Word = smCO80;

procedure PollEvent(TimeoutMs: Integer; var Event: TEvent);
function ClockMs: Int64;

implementation

procedure PollEvent(TimeoutMs: Integer; var Event: TEvent);
begin
  ClearEvent(Event);
  if Assigned(OnPollEvent) then
    OnPollEvent(TimeoutMs, Event);
end;

function ClockMs: Int64;
begin
  if Assigned(GetClockMs) then
    Result := GetClockMs()
  else
    Result := GetTickCount64;
end;

end.
