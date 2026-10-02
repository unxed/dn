program tvdemo;
{ Demo of the Turbo Vision port: windows with scrollers, menus, a status line.
  With /auto it types a few keys itself, writes the screen to SCR.DAT and quits (CI). }
{$I ../src/tvdefs.inc}
uses TvGeom, TvColors, TvCell, TvEvents, TvKeys, TvDrawBuf, TvScreen, TvViews, TvWindow,
  TvMenus, TvSys, TvApp, TvDos;

const
  cmNewWin = 100;
  Lines: array[0..17] of string[72] = (
    'Turbo Vision для DOS на Free Pascal',
    '',
    'Эта программа собрана компилятором FPC для go32v2 и работает',
    'на оригинальной библиотеке, переведённой с magiblot/tvision.',
    '',
    'Строки хранятся в UTF-8, а на экран попадают через кодовую',
    'страницу видеошрифта (сейчас CP866 или CP437).',
    '',
    'Hotkeys:',
    '  F4         new window',
    '  F5         zoom      F6  next window',
    '  F7         tile      F8  cascade',
    '  Alt-F3     close     Alt-X  exit',
    '',
    'Меню: Alt-F, Alt-W или F10, мышь тоже работает.',
    '',
    'The scroll bar and the keys Up, Down, PgUp, PgDn work in',
    'every window.');

type
  PLinesView = ^TLinesView;
  TLinesView = object(TScroller)
    constructor Init(const Bounds: TRect; AH, AV: PScrollBar);
    procedure Draw; virtual;
  end;

  TDemoApp = object(TApplication)
    Auto: Boolean;
    Quiet, Count: Integer;
    constructor Init(AAuto: Boolean);
    procedure InitMenuBar; virtual;
    procedure InitStatusLine; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure Idle; virtual;
    procedure NewWindow;
  end;

constructor TLinesView.Init(const Bounds: TRect; AH, AV: PScrollBar);
begin
  inherited Init(Bounds, AH, AV);
  GrowMode := gfGrowHiX or gfGrowHiY;
  SetLimit(80, Length(Lines));
end;

procedure TLinesView.Draw;
var
  B: TDrawBuffer;
  Y, I: Integer;
  Color: TColorAttr;
begin
  Color := GetColor(1).Lo;
  B.Init(Size.X);
  for Y := 0 to Size.Y - 1 do
  begin
    B.MoveChar(0, Ord(' '), Color, Size.X);
    I := Delta.Y + Y;
    if (I >= 0) and (I <= High(Lines)) then
      B.MoveStrS(0, Lines[I], Color, Size.X, Delta.X);
    WriteLineD(0, Y, Size.X, 1, B);
  end;
  B.Done;
end;

constructor TDemoApp.Init(AAuto: Boolean);
begin
  Auto := AAuto;
  Quiet := 0;
  Count := 0;
  inherited Init;
end;

procedure TDemoApp.InitMenuBar;
var
  R: TRect;
begin
  R := GetExtent;
  R.B.Y := R.A.Y + 1;
  New(MenuBar, Init(R, NewMenu(
    NewSubMenu('~F~ile', hcNoContext, NewMenu(
      NewItem('~N~ew window', 'F4', kbF4, cmNewWin, hcNoContext,
      NewItem('~C~lose', 'Alt-F3', kbAltF3, cmClose, hcNoContext,
      NewLine(
      NewItem('E~x~it', 'Alt-X', kbAltX, cmQuit, hcNoContext, nil))))),
    NewSubMenu('~W~indow', hcNoContext, NewMenu(
      NewItem('~T~ile', 'F7', kbF7, cmTile, hcNoContext,
      NewItem('C~a~scade', 'F8', kbF8, cmCascade, hcNoContext,
      NewItem('~N~ext', 'F6', kbF6, cmNext, hcNoContext,
      NewItem('~Z~oom', 'F5', kbF5, cmZoom, hcNoContext, nil))))), nil)))));
end;

procedure TDemoApp.InitStatusLine;
var
  R: TRect;
begin
  R := GetExtent;
  R.A.Y := R.B.Y - 1;
  New(StatusLine, Init(R,
    NewStatusDef(0, $FFFF,
      NewStatusKey('~F4~ New', kbF4, cmNewWin,
      NewStatusKey('~F5~ Zoom', kbF5, cmZoom,
      NewStatusKey('~F6~ Next', kbF6, cmNext,
      NewStatusKey('~Alt-F3~ Close', kbAltF3, cmClose,
      NewStatusKey('~Alt-X~ Exit', kbAltX, cmQuit,
      NewStatusKey('', kbF10, cmMenu,
      NewStatusKey('', kbF7, cmTile,
      NewStatusKey('', kbF8, cmCascade, nil)))))))),
    nil)));
end;

procedure TDemoApp.NewWindow;
var
  W: PWindow;
  R: TRect;
  H, V: PScrollBar;
  S: PLinesView;
begin
  Inc(Count);
  R.Assign(2 + Count * 3, 1 + Count, 44 + Count * 3, 14 + Count);
  New(W, Init(R, 'Window', Count));
  W^.Options := W^.Options or ofTileable;
  H := W^.StandardScrollBar(sbHorizontal or sbHandleKeyboard);
  V := W^.StandardScrollBar(sbVertical or sbHandleKeyboard);
  R := W^.GetExtent;
  R.Grow(-1, -1);
  New(S, Init(R, H, V));
  W^.Insert(S);
  InsertWindow(W);
end;

procedure TDemoApp.HandleEvent(var Event: TEvent);
begin
  inherited HandleEvent(Event);
  if (Event.What = evCommand) and (Event.Command = cmNewWin) then
  begin
    NewWindow;
    ClearEvent(Event);
  end;
end;

procedure TDemoApp.Idle;
var
  Ev: TEvent;
begin
  inherited Idle;
  if Auto and DosKeyBufferEmpty then
  begin
    Inc(Quiet);
    if Quiet = 4 then
    begin
      DosDumpScreen('SCR.DAT');
      ClearEvent(Ev);
      Ev.What := evCommand;
      Ev.Command := cmQuit;
      PutEvent(Ev);
    end;
  end;
end;

var
  App: TDemoApp;
  Auto: Boolean;
begin
  Auto := (ParamCount > 0) and (ParamStr(1) = '/auto');
  DosInit;
  App.Init(Auto);
  if Auto then
  begin
    { F4 x3: three windows; F7: tile; Alt-F: the File menu stays open }
    DosStuffKey(kbF4); DosStuffKey(kbF4); DosStuffKey(kbF4);
    DosStuffKey(kbF7);
    DosStuffKey(kbAltF);
  end
  else
    App.NewWindow;
  App.Run;
  App.Done;
  DosDone;
end.
