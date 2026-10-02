program t_app;
{$I ../src/tvdefs.inc}
uses TvGeom, TvColors, TvCell, TvEvents, TvKeys, TvScreen, TvViews, TvWindow, TvMenus,
  TvSys, TvTimer, TvMem, TvApp;
{$I testlib.inc}

var
  Save: ShortString;

{ the main block keeps the temporaries (dynamic arrays) until its end: measure in a function }
function PalLen(A: PApplication): Integer;
begin
  Result := PaletteSize(A^.GetPalette);
end;

type
  PTestApp = ^TTestApp;
  TTestApp = object(TApplication)
    Idles: Integer;
    procedure InitMenuBar; virtual;
    procedure Idle; virtual;
  end;

  { records the broadcasts it gets }
  PWatch = ^TWatch;
  TWatch = object(TView)
    SetChanged, TimerFired: Integer;
    LastTimer: Pointer;
    procedure HandleEvent(var Event: TEvent); virtual;
  end;

  { a dialog: Execute returns cmOK at once; its data is a Word }
  PDlg = ^TDlg;
  TDlg = object(TView)
    Value: Word;
    function Execute: Word; virtual;
    function DataSize: Integer; virtual;
    procedure GetData(var Rec); virtual;
    procedure SetData(var Rec); virtual;
  end;

procedure TTestApp.InitMenuBar;
var
  R: TRect;
begin
  R := GetExtent;
  R.B.Y := R.A.Y + 1;
  New(MenuBar, Init(R, NewMenu(
    NewSubMenu('~F~ile', hcNoContext, NewMenu(
      NewItem('E~x~it', 'Alt-X', kbAltX, cmQuit, hcNoContext, nil)), nil))));
end;

procedure TTestApp.Idle;
begin
  Inc(Idles);
  inherited Idle;
end;

procedure TWatch.HandleEvent(var Event: TEvent);
begin
  inherited HandleEvent(Event);
  if Event.What = evBroadcast then
    case Event.Command of
      cmCommandSetChanged: Inc(SetChanged);
      cmTimerExpired:
        begin
          Inc(TimerFired);
          LastTimer := Event.InfoPtr;
        end;
    end;
end;

function TDlg.Execute: Word;
begin
  Value := 99;
  Result := cmOK;
end;

function TDlg.DataSize: Integer;
begin
  Result := SizeOf(Word);
end;

procedure TDlg.GetData(var Rec);
begin
  Word(Rec) := Value;
end;

procedure TDlg.SetData(var Rec);
begin
  Value := Word(Rec);
end;

function R(A, B, C, D: Integer): TRect;
begin
  Result.Assign(A, B, C, D);
end;

{ handles the queued events, as the loop of Run does }
procedure Pump(App: PTestApp);
var
  E: TEvent;
begin
  while MemPending > 0 do
  begin
    App^.GetEvent(E);
    if E.What <> evNothing then
      App^.HandleEvent(E);
  end;
end;

procedure Resize(Mode: Word);
begin
  ScreenCreate(80, 30);
end;

function NewWin(Num: Integer; X, Y: Integer): PWindow;
var
  W: PWindow;
begin
  New(W, Init(R(X, Y, X + 20, Y + 8), 'Win', Num));
  W^.Options := W^.Options or ofTileable;
  NewWin := W;
end;

var
  App: PTestApp;
  Used0: PtrUInt;
  W1, W2, W3: PWindow;
  Watch: PWatch;
  Dlg: PDlg;
  Ev: TEvent;
  Id: TTimerId;
  I, D: Integer;
  Rc: TRect;
  Res: Word;
  Ys: array[0..2] of Integer;

begin
  Used0 := GetFPCHeapStatus.CurrHeapUsed;
  MemInit(60, 25);
  Check(Application = nil, 'no application yet');
  New(App, Init);
  Check(Application = PProgram(App), 'Application is set');
  Check((DeskTop <> nil) and (MenuBar <> nil) and (StatusLine <> nil), 'desktop, menu bar and status line exist');
  Check((App^.State and (sfVisible or sfSelected or sfFocused or sfModal or sfExposed)) =
    (sfVisible or sfSelected or sfFocused or sfModal or sfExposed), 'the program is the modal top view');
  Check(App^.Buffer = ScreenBuffer, 'the program draws into the screen buffer');
  Check((DeskTop^.Origin.Y = 1) and (DeskTop^.Size.Y = 23) and (DeskTop^.Size.X = 60), 'desktop bounds');
  Check((MenuBar^.Origin.Y = 0) and (MenuBar^.Size.Y = 1), 'menu bar bounds');
  Check((StatusLine^.Origin.Y = 24) and (StatusLine^.Size.Y = 1), 'status line bounds');
  Check(DeskTop^.Background <> nil, 'the desktop has a background');
  Check(MemText(0, 0, 5) = '  File', 'menu bar text');
  Check(MemText(24, 0, 11) = ' Alt-X Exit ', 'status line text');
  Check(MemChar(0, 1) = '░', 'background pattern');
  { what a locked program lost is drawn again at Unlock (the buffer of the program is the screen: Draw of the group repaints
    the subviews, not the buffer onto itself) }
  FillChar(ScreenBuffer^, ScreenWidth * ScreenHeight * SizeOf(TScreenCell), 0);
  App^.Lock;
  App^.Unlock;
  Check((MemText(0, 0, 5) = '  File') and (MemChar(0, 1) = '░'), 'Unlock of the program repaints it');
  Check(MemChar(59, 23) = '░', 'background fills the desktop');
  Check(MemAttr(0, 1) = $71, 'application palette: background');
  Check(MemAttr(0, 0) = $70, 'application palette: menu bar');
  Check(MemAttr(1, 24) = $74, 'application palette: status line hot key');
  Check(AppPalette = apColor, 'color palette');

  { windows }
  W1 := App^.InsertWindow(NewWin(1, 2, 2));
  Check(W1 <> nil, 'InsertWindow returns the window');
  Check((DeskTop^.First = PView(W1)) and ((W1^.State and sfActive) <> 0), 'the window is in front and active');
  Check(MemText(3, 2, 6) = '╔═[■]', 'the frame of the window is drawn');
  Check(MemAttr(2, 3) = $1F, 'active frame color');
  Check(MemIsShadow(22, 5) and MemIsShadow(23, 11) and not MemIsShadow(21, 5) and not MemIsShadow(22, 3), 'the shadow of the window');
  W2 := App^.InsertWindow(NewWin(2, 10, 6));
  Check(DeskTop^.First = PView(W2), 'the second window is in front');
  MemKey(kbAlt1, kbAltShift);
  Pump(App);
  Check(DeskTop^.First = PView(W1), 'Alt+1 selects window 1');
  MemKey(kbAlt2, kbAltShift);
  Pump(App);
  Check(DeskTop^.First = PView(W2), 'Alt+2 selects window 2');
  MemKey(kbAlt9, kbAltShift);
  Pump(App);
  Check(DeskTop^.First = PView(W2), 'Alt+9: no such window');
  Check(App^.InsertWindow(nil) = nil, 'InsertWindow(nil) is nil');

  { next and previous window }
  Ev.What := evCommand; Ev.Command := cmNext; Ev.InfoPtr := nil;
  App^.HandleEvent(Ev);
  Check((DeskTop^.First = PView(W1)) and (Ev.What = evNothing), 'cmNext selects the next window');
  Ev.What := evCommand; Ev.Command := cmPrev; Ev.InfoPtr := nil;
  App^.HandleEvent(Ev);
  Check(DeskTop^.First = PView(W2), 'cmPrev puts the front window behind the others');

  { tile and cascade }
  W3 := App^.InsertWindow(NewWin(3, 20, 10));
  Ev.What := evCommand; Ev.Command := cmTile; Ev.InfoPtr := nil;
  App^.HandleEvent(Ev);
  Check(Ev.What = evNothing, 'cmTile is handled');
  Ys[0] := W1^.Origin.Y; Ys[1] := W2^.Origin.Y; Ys[2] := W3^.Origin.Y;
  for I := 0 to 1 do
    for D := I + 1 to 2 do
      if Ys[D] < Ys[I] then begin Res := Ys[I]; Ys[I] := Ys[D]; Ys[D] := Res; end;
  Check((Ys[0] = 0) and (Ys[1] = 7) and (Ys[2] = 15), 'tiled in three rows');
  Check((W1^.Size.X = 60) and (W2^.Size.X = 60) and (W3^.Size.X = 60), 'tiled windows are as wide as the desktop');
  Check(W1^.Size.Y + W2^.Size.Y + W3^.Size.Y = 23, 'and fill its height');
  Ev.What := evCommand; Ev.Command := cmCascade; Ev.InfoPtr := nil;
  App^.HandleEvent(Ev);
  Check(Ev.What = evNothing, 'cmCascade is handled');
  Check((W3^.Origin.X = W3^.Origin.Y) and (W1^.Origin.X = W1^.Origin.Y) and
    (W2^.Origin.X = W2^.Origin.Y), 'cascaded windows are on the diagonal');
  Check(((W1^.Origin.X = 0) or (W2^.Origin.X = 0) or (W3^.Origin.X = 0)) and
    ((W1^.Origin.X = 1) or (W2^.Origin.X = 1) or (W3^.Origin.X = 1)) and
    ((W1^.Origin.X = 2) or (W2^.Origin.X = 2) or (W3^.Origin.X = 2)), 'offsets 0, 1 and 2');
  Rc := W1^.GetBounds;
  Check((Rc.B.X = 60) and (Rc.B.Y = 23), 'a cascaded window reaches the corner of the desktop');
  Dispose(W3, Done);

  { idle, commands, timers }
  New(Watch, Init(R(0, 0, 1, 1)));
  Watch^.EventMask := evBroadcast;
  DeskTop^.Insert(Watch);
  App^.Idles := 0;
  CommandSetChanged := False;
  DisableCommand(cmClose);
  Check(CommandSetChanged, 'disabling a command sets CommandSetChanged');
  App^.Idle;
  Check((Watch^.SetChanged = 1) and not CommandSetChanged, 'Idle broadcasts cmCommandSetChanged once');
  App^.Idle;
  Check(Watch^.SetChanged = 1, 'and not again');
  EnableCommand(cmClose);
  { idle is called when there is no event }
  MemClear;
  App^.Idles := 0;
  App^.GetEvent(Ev);
  Check((Ev.What = evNothing) and (App^.Idles = 1), 'no event: Idle is called');
  Check(MemClock = 20, 'the program waited EventTimeoutMs');
  MemKey(kbF9);
  App^.Idles := 0;
  App^.GetEvent(Ev);
  Check((Ev.What = evKeyDown) and (App^.Idles = 0), 'an event: no Idle');
  { the pending event (PutEvent) comes first }
  MemKey(kbF8);
  Ev.What := evCommand; Ev.Command := cmOK; Ev.InfoPtr := nil;
  App^.PutEvent(Ev);
  App^.GetEvent(Ev);
  Check((Ev.What = evCommand) and (Ev.Command = cmOK), 'PutEvent: the pending event comes first');
  App^.GetEvent(Ev);
  Check((Ev.What = evKeyDown) and (Ev.KeyCode = kbF8), 'then the queue');

  EventTimeoutMs := 20;
  MemClear;
  MemClock := 1000;
  Id := App^.SetTimer(100);
  I := 0;
  while (Watch^.TimerFired = 0) and (I < 20) do
  begin
    App^.GetEvent(Ev);
    Inc(I);
  end;
  Check(Watch^.TimerFired = 1, 'a timer sends cmTimerExpired');
  Check(Watch^.LastTimer = Id, 'with its id');
  Check((MemClock >= 1100) and (I = 5), 'after its time, noticed at the next Idle');
  App^.GetEvent(Ev);
  Check(Watch^.TimerFired = 1, 'a one-shot timer fires once');
  { with no event timeout the program sleeps exactly until the timer }
  EventTimeoutMs := -1;
  MemClock := 5000;
  Watch^.TimerFired := 0;
  Id := App^.SetTimer(250);
  App^.GetEvent(Ev);
  Check((MemClock = 5250) and (Watch^.TimerFired = 1), 'EventTimeoutMs = -1: wait until the timer');
  Id := App^.SetTimer(1000, 1000);
  App^.KillTimer(Id);
  Check(True, 'KillTimer');
  EventTimeoutMs := 20;
  Dispose(Watch, Done);

  { the status line gets keys and clicks before the others }
  MemClear;
  MemKey(kbAltX, kbAltShift);
  App^.GetEvent(Ev);
  Check((Ev.What = evCommand) and (Ev.Command = cmQuit), 'a key of the status line becomes its command');
  MemClear;
  MemMouse(evMouseDown, 3, 24);
  MemMouse(evMouseUp, 3, 24);
  App^.GetEvent(Ev);
  Check(Ev.What = evNothing, 'a click on the status line is handled by it');
  App^.GetEvent(Ev);
  Check((Ev.What = evCommand) and (Ev.Command = cmQuit), 'and its command comes next');

  { dialogs }
  New(Dlg, Init(R(0, 0, 10, 5)));
  D := 55;
  Dlg^.Value := 0;
  Res := App^.ExecuteDialog(Dlg, @D);
  Check(Res = cmOK, 'ExecuteDialog returns the result of the dialog');
  Check(D = 99, 'and the data of the dialog (set before, read after)');
  Check(DeskTop^.First = PView(W2), 'the dialog is gone');

  { the screen changes }
  OnSetVideoMode := @Resize;
  FillChar(Ev, SizeOf(Ev), 0);
  Ev.What := evCommand; Ev.Command := cmScreenChanged;
  App^.PutEvent(Ev);
  App^.GetEvent(Ev);
  Check(Ev.What = evNothing, 'cmScreenChanged is handled');
  Check((ScreenWidth = 80) and (ScreenHeight = 30), 'the screen was resized');
  Check((App^.Size.X = 80) and (App^.Size.Y = 30), 'the program has the new size');
  Check((StatusLine^.Origin.Y = 29) and (StatusLine^.Size.X = 80), 'the status line moved to the bottom');
  Check(MemText(29, 0, 11) = ' Alt-X Exit ', 'and is drawn there');
  Check((DeskTop^.Size.X = 80) and (DeskTop^.Size.Y = 28), 'the desktop grew');
  Check(W2^.Size.X > 60, 'the windows grow with the desktop (relative grow mode)');
  OnSetVideoMode := nil;

  { Run ends with cmQuit }
  MemClear;
  MemKey(kbAltX, kbAltShift);
  App^.Run;
  Check(App^.EndState = cmQuit, 'Run: Alt-X quits');

  { DN: SystemColors are the palettes of the program and can be changed }
  Check(Length(SystemColors[apColor]) = PalLen(App), 'DN extensions: GetPalette is made of SystemColors');
  Save := SystemColors[apColor];
  SystemColors[apColor] := #1#2#3;
  AppPalette := apColor;
  Check(PalLen(App) = 3, 'DN extensions: a changed SystemColors is the palette');
  SystemColors[apColor] := Save;

  Dispose(App, Done);
  Check((Application = nil) and (DeskTop = nil) and (StatusLine = nil) and (MenuBar = nil), 'Done clears the variables');
  MemDone;
  Check(GetFPCHeapStatus.CurrHeapUsed = Used0, 'no memory is left behind');
  Finish;
end.
