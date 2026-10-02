program t_menus;
{$I ../src/tvdefs.inc}
uses TvCodePg, TvGeom, TvColors, TvCell, TvEvents, TvKeys, TvDrawBuf, TvScreen, TvViews,
  TvUtil, TvMenus;
{$I testlib.inc}

const
  W = 40;
  H = 12;

type
  { the top view of the tests: a queue of events, the event put back (as the
    pending event of the application) and Esc when the queue is empty, so that
    a menu always ends }
  TTop = object(TGroup)
    Queue: array[0..15] of TEvent;
    QCount, QPos, Calls: Integer;
    Pending, LastPut: TEvent;
    procedure GetEvent(var Event: TEvent); virtual;
    procedure PutEvent(var Event: TEvent); virtual;
    procedure Reset;
    procedure Key(KeyCode: Word);
    procedure Mouse(What: Word; X, Y: Integer);
  end;

var
  Desk: TTop;

procedure TTop.GetEvent(var Event: TEvent);
begin
  Inc(Calls);
  if Calls > 200 then
  begin
    WriteLn('FAIL a menu does not end');
    Halt(2);
  end;
  if Pending.What <> evNothing then
  begin
    Event := Pending;
    Pending.What := evNothing;
  end
  else if QPos < QCount then
  begin
    Event := Queue[QPos];
    Inc(QPos);
  end
  else
    MakeKeyEvent(Event, kbEsc, 0);
end;

procedure TTop.PutEvent(var Event: TEvent);
begin
  Pending := Event;
  LastPut := Event;
end;

procedure TTop.Reset;
begin
  QCount := 0;
  QPos := 0;
  Calls := 0;
  Pending.What := evNothing;
  LastPut.What := evNothing;
end;

procedure TTop.Key(KeyCode: Word);
begin
  MakeKeyEvent(Queue[QCount], KeyCode, 0);
  Inc(QCount);
end;

procedure TTop.Mouse(What: Word; X, Y: Integer);
begin
  ClearEvent(Queue[QCount]);
  Queue[QCount].What := What;
  Queue[QCount].Where.X := X;
  Queue[QCount].Where.Y := Y;
  Queue[QCount].Buttons := mbLeftButton;
  Inc(QCount);
end;

function Cell(X, Y: Integer): PScreenCell;
begin
  Result := ScreenBuffer + (Y * ScreenWidth + X);
end;

function CellText(X, Y: Integer): ShortString;
var
  Buf: array[0..7] of Byte;
  N: Integer;
begin
  Result := ScText(Cell(X, Y)^.Character);
  if Result = #0 then
    Result := '_'
  else if (Length(Result) = 1) and ((Byte(Result[1]) >= $80) or (Byte(Result[1]) < $20)) then
  begin
    N := CpToUtf8(Byte(Result[1]), @Buf[0]);
    SetLength(Result, N);
    Move(Buf[0], Result[1], N);
  end;
end;

function Row(Y, X0, X1: Integer): ShortString;
var
  X: Integer;
begin
  Result := '';
  for X := X0 to X1 do
    Result := Result + CellText(X, Y);
end;

function AttrAt(X, Y: Integer): Byte;
begin
  Result := AttrAsBIOSByte(Cell(X, Y)^.Attribute);
end;

function R(A, B, C, D: Integer): TRect;
begin
  Result.Assign(A, B, C, D);
end;

function FileMenu: PMenu;
begin
  FileMenu := NewMenu(
    NewItem('~O~pen', 'F3', kbF3, cmOpen, hcNoContext,
    NewItem('~S~ave', 'F2', kbF2, cmSave, hcNoContext,
    NewLine(
    NewItem('E~x~it', 'Alt-X', kbAltX, cmQuit, hcNoContext, nil)))));
end;

function MainMenu: PMenu;
begin
  MainMenu := NewMenu(
    NewSubMenu('~F~ile', hcNoContext, FileMenu,
    NewSubMenu('~E~dit', hcNoContext, NewMenu(
      NewItem('~U~ndo', '', kbNoKey, cmUndo, hcNoContext, nil)),
    nil)));
end;

{ the menus remember the entry chosen last: start every run from the first one }
procedure ResetDefaults(M: PMenu);
var
  P: PMenuItem;
begin
  M^.Default := M^.Items;
  P := M^.Items;
  while P <> nil do
  begin
    if (P^.Name <> nil) and (P^.Command = 0) then
      ResetDefaults(P^.SubMenu);
    P := P^.Next;
  end;
end;

function Run(Bar: PMenuView): Word;
begin
  ResetDefaults(Bar^.Menu);
  Result := Bar^.Execute;
end;

var
  Bar: PMenuBar;
  Box: PMenuBox;
  Popup: PMenuPopup;
  M: PMenu;
  Ev: TEvent;
  Rc: TRect;
  Used0: PtrUInt;
  Res: Word;
  Item: PMenuItem;
  BM: PMenu;

begin
  ScreenCreate(W, H);
  Desk.Init(R(0, 0, W, H));
  Desk.Options := 0;
  Desk.Buffer := ScreenBuffer;
  Desk.State := sfVisible or sfSelected or sfFocused or sfModal or sfExposed;
  Desk.Reset;
  EnableCommands([cmOpen, cmSave, cmQuit, cmUndo]);
  Used0 := GetFPCHeapStatus.CurrHeapUsed;

  { --- menu data ----------------------------------------------------------------- }
  M := MainMenu;
  Check(M^.Items^.Name^ = '~F~ile', 'the first entry of a menu');
  Check(M^.Items^.Next^.Name^ = '~E~dit', 'the entries are linked');
  Check(M^.Items^.Next^.Next = nil, 'the list ends');
  Check(M^.Default = M^.Items, 'NewMenu: the default is the first entry');
  Check(M^.Items^.Command = 0, 'a submenu entry has command 0');
  Check(M^.Items^.SubMenu^.Items^.Command = cmOpen, 'the first entry of a submenu');
  Item := M^.Items^.SubMenu^.Items;
  Check(Item^.Param^ = 'F3', 'the parameter text');
  Check(KeyEq(Item^.Key, KeyMake(kbF3)), 'the key is a normalized TKey');
  Check(not Item^.Disabled, 'an item of an enabled command is enabled');
  Check(Item^.Next^.Next^.Name = nil, 'NewLine: a separator has no name');
  Check(Item^.Next^.Next^.Next^.Param^ = 'Alt-X', 'the last entry');
  Check(M^.Items^.Next^.SubMenu^.Items^.Param = nil, 'an empty parameter is nil');
  DisposeMenu(M);
  Check(GetFPCHeapStatus.CurrHeapUsed = Used0, 'DisposeMenu frees everything');
  DisableCommand(cmSave);
  M := FileMenu;
  Check(M^.Items^.Next^.Disabled and not M^.Items^.Disabled, 'an item of a disabled command is disabled');
  DisposeMenu(M);
  EnableCommand(cmSave);

  { --- the menu bar ---------------------------------------------------------------- }
  New(Bar, Init(R(0, 0, W, 1), MainMenu));
  Desk.Insert(Bar);
  Check(Row(0, 0, 12) = '  File  Edit ', 'the bar draws the names');
  Check(AttrAt(0, 0) = $02, 'normal color');
  Check(AttrAt(3, 0) = $02, 'normal letter');
  Check(CellText(2, 0) = 'F', 'the hot letter');
  Check(AttrAt(2, 0) = $04, 'the hot letter has its own color');
  Check(Row(0, 30, 39) = '          ', 'the rest of the bar is blank');
  Check((Bar^.Options and ofPreProcess) <> 0, 'the bar sees keys before the focused view');
  Check(Bar^.GrowMode = gfGrowHiX, 'the bar grows with the width');
  Rc := Bar^.GetItemRect(Bar^.Menu^.Items);
  Check((Rc.A.X = 1) and (Rc.B.X = 7) and (Rc.A.Y = 0) and (Rc.B.Y = 1), 'item rectangle: File');
  Rc := Bar^.GetItemRect(Bar^.Menu^.Items^.Next);
  Check((Rc.A.X = 7) and (Rc.B.X = 13), 'item rectangle: Edit');

  { --- a menu box ------------------------------------------------------------------ }
  BM := FileMenu;
  New(Box, Init(R(0, 1, W, H), BM, nil));
  Check((Box^.Size.X = 17) and (Box^.Size.Y = 6), 'the box fits its entries');
  Check((Box^.Origin.X = 0) and (Box^.Origin.Y = 1), 'the box is placed at the top left of the bounds');
  Check((Box^.State and sfShadow) <> 0, 'a menu box has a shadow');
  Desk.Insert(Box);
  Check(Row(1, 0, 16) = ' ┌─────────────┐ ', 'box: top line');
  Check(Row(2, 0, 16) = ' │ Open     F3 │ ', 'box: an entry with its parameter');
  Check(Row(3, 0, 16) = ' │ Save     F2 │ ', 'box: another entry');
  Check(Row(4, 0, 16) = ' ├─────────────┤ ', 'box: a separator');
  Check(Row(5, 0, 16) = ' │ Exit  Alt-X │ ', 'box: the last entry');
  Check(Row(6, 0, 16) = ' └─────────────┘ ', 'box: bottom line');
  Check(AttrAt(3, 2) = $04, 'box: hot letter color');
  Rc := Box^.GetItemRect(Box^.Menu^.Items^.Next);
  Check((Rc.A.X = 2) and (Rc.B.X = 15) and (Rc.A.Y = 2) and (Rc.B.Y = 3), 'box: item rectangle');
  Dispose(Box, Done);
  DisposeMenu(BM);
  Check(Desk.First = PView(Bar), 'the box is removed from the desk');
  { a box with submenus shows an arrow; disabled entries have their own color }
  DisableCommand(cmSave);
  BM := FileMenu;
  New(Box, Init(R(0, 1, W, H), BM, nil));
  Desk.Insert(Box);
  Check(AttrAt(4, 3) = $03, 'box: disabled entry color');
  Dispose(Box, Done);
  DisposeMenu(BM);
  EnableCommand(cmSave);
  New(Box, Init(R(0, 1, W, H), Bar^.Menu, nil));
  Desk.Insert(Box);
  Check((Box^.Size.X = 13) and (Box^.Size.Y = 4), 'box with submenu entries');
  Check(CellText(9, 2) = '►', 'box: the arrow of a submenu entry');
  Dispose(Box, Done);

  { --- keys ------------------------------------------------------------------------- }
  { Down opens the menu, Down moves, Enter chooses }
  Desk.Reset;
  Desk.Key(kbDown); Desk.Key(kbDown); Desk.Key(kbEnter);
  Check(Run(Bar) = cmSave, 'Down, Down, Enter chooses the second entry');
  { Esc closes }
  Desk.Reset;
  Desk.Key(kbDown); Desk.Key(kbEsc);
  Check(Run(Bar) = 0, 'Esc closes the menu');
  { a letter chooses the entry with that hot letter }
  Desk.Reset;
  Desk.Key(kbDown); Desk.Key(Ord('x'));
  Check(Run(Bar) = cmQuit, 'a hot letter chooses an entry');
  Desk.Reset;
  Desk.Key(kbDown); Desk.Key(Ord('S'));
  Check(Run(Bar) = cmSave, 'the hot letter is case insensitive');
  { Right moves to the next menu, Enter opens it and chooses }
  Desk.Reset;
  Desk.Key(kbRight); Desk.Key(kbEnter); Desk.Key(kbEnter);
  Check(Run(Bar) = cmUndo, 'Right, Enter, Enter chooses in the second menu');
  { Up from the first entry goes to the last one }
  Desk.Reset;
  Desk.Key(kbDown); Desk.Key(kbUp); Desk.Key(kbEnter);
  Check(Run(Bar) = cmQuit, 'Up from the first entry wraps to the last (skipping the separator)');
  { Home and End }
  Desk.Reset;
  Desk.Key(kbDown); Desk.Key(kbEnd); Desk.Key(kbEnter);
  Check(Run(Bar) = cmQuit, 'End goes to the last entry');
  Desk.Reset;
  Desk.Key(kbDown); Desk.Key(kbEnd); Desk.Key(kbHome); Desk.Key(kbEnter);
  Check(Run(Bar) = cmOpen, 'Home goes to the first entry');
  { a hot key chooses an entry without opening the menu }
  Desk.Reset;
  Desk.Key(kbF2);
  Check(Run(Bar) = cmSave, 'a hot key chooses an entry');
  { Left in a submenu closes it and moves in the bar }
  Desk.Reset;
  Desk.Key(kbDown); Desk.Key(kbRight); Desk.Key(kbEnter);
  Check(Run(Bar) = cmUndo, 'Right in a menu box moves to the next menu of the bar');

  { --- commands the application sends -------------------------------------------------- }
  Desk.Reset;
  Desk.Key(kbEnter);
  MakeKeyEvent(Ev, kbAltF, kbAltShift);
  Bar^.HandleEvent(Ev);
  Check((Desk.LastPut.What = evCommand) and (Desk.LastPut.Command = cmOpen),
    'Alt+hot letter opens the menu and the chosen command is put back');
  Check(Ev.What = evNothing, 'the key event is handled');
  Desk.Reset;
  MakeKeyEvent(Ev, kbF3, 0);
  Bar^.HandleEvent(Ev);
  Check((Desk.LastPut.What = evCommand) and (Desk.LastPut.Command = cmOpen) and
    (Ev.What = evNothing), 'a hot key becomes a command');
  Desk.Reset;
  MakeKeyEvent(Ev, kbAltX, kbAltShift);
  Bar^.HandleEvent(Ev);
  Check((Desk.LastPut.What = evCommand) and (Desk.LastPut.Command = cmQuit),
    'a hot key found in a submenu');
  Desk.Reset;
  MakeKeyEvent(Ev, kbF9, 0);
  Bar^.HandleEvent(Ev);
  Check((Desk.LastPut.What = evNothing) and (Ev.What = evKeyDown), 'other keys are not handled');
  { F10-like command: cmMenu opens the menu }
  Desk.Reset;
  Desk.Key(kbEsc);
  ClearEvent(Ev);
  Ev.What := evCommand;
  Ev.Command := cmMenu;
  Bar^.HandleEvent(Ev);
  Check(Ev.What = evNothing, 'cmMenu is handled');

  { --- disabled commands ----------------------------------------------------------------- }
  DisableCommand(cmSave);
  ClearEvent(Ev);
  Ev.What := evBroadcast;
  Ev.Command := cmCommandSetChanged;
  Bar^.HandleEvent(Ev);
  Check(Bar^.Menu^.Items^.SubMenu^.Items^.Next^.Disabled, 'cmCommandSetChanged updates the entries');
  Desk.Reset;
  MakeKeyEvent(Ev, kbF2, 0);
  Bar^.HandleEvent(Ev);
  Check(Desk.LastPut.What = evNothing, 'the hot key of a disabled entry does nothing');
  Check(Bar^.HotKey(KeyMake(kbF2)) = nil, 'HotKey does not find a disabled entry');
  Check(Bar^.HotKey(KeyMake(kbF3)) <> nil, 'HotKey finds the entry of an enabled command');
  Check(Bar^.FindItem('x') = nil, 'FindItem looks at the bar entries only (File, Edit)');
  Check(Bar^.FindItem('e') = Bar^.Menu^.Items^.Next, 'FindItem finds an entry by its hot letter');
  EnableCommand(cmSave);
  ClearEvent(Ev);
  Ev.What := evBroadcast;
  Ev.Command := cmCommandSetChanged;
  Bar^.HandleEvent(Ev);
  Check(not Bar^.Menu^.Items^.SubMenu^.Items^.Next^.Disabled, 'and enables them again');
  { a disabled command is not chosen by Enter }
  DisableCommand(cmQuit);
  Desk.Reset;
  Desk.Key(kbDown); Desk.Key(kbEnd); Desk.Key(kbEnter);
  Check(Run(Bar) = 0, 'a disabled command is not returned');
  EnableCommand(cmQuit);

  { --- the mouse --------------------------------------------------------------------------- }
  { press on "Edit", release over its first entry }
  Desk.Reset;
  Desk.Mouse(evMouseUp, 8, 2);
  ClearEvent(Ev);
  Ev.What := evMouseDown;
  Ev.Where.X := 8; Ev.Where.Y := 0;
  Ev.Buttons := mbLeftButton;
  Bar^.HandleEvent(Ev);
  Check((Desk.LastPut.What = evCommand) and (Desk.LastPut.Command = cmUndo),
    'press on a name, release on an entry chooses it');
  { a click outside closes the menu and the click is put back }
  Desk.Reset;
  Desk.Mouse(evMouseDown, 30, 8);
  ClearEvent(Ev);
  Ev.What := evMouseDown;
  Ev.Where.X := 3; Ev.Where.Y := 0;
  Ev.Buttons := mbLeftButton;
  Bar^.HandleEvent(Ev);
  Check((Desk.LastPut.What = evMouseDown) and (Desk.LastPut.Where.X = 30), 'a click outside closes the menu and is put back');

  { --- help context ---------------------------------------------------------------------------- }
  Bar^.HelpCtx := 77;
  Check(Bar^.GetHelpCtx = 77, 'the help context of the bar when nothing is chosen');
  Bar^.Current := Bar^.Menu^.Items;
  Bar^.Menu^.Items^.HelpCtx := 12;
  Check(Bar^.GetHelpCtx = 12, 'the help context of the chosen entry');
  Bar^.Current := nil;

  { --- popup menu ------------------------------------------------------------------------------- }
  New(Popup, Init(R(10, 3, W, H),
    NewMenu(NewItem('~A~lpha', '', 0, cmOpen, hcNoContext,
            NewItem('~B~eta', '', 0, cmSave, hcNoContext, nil))), nil));
  Check(not Popup^.PutClickEventOnExit, 'a popup does not put the click back');
  Desk.Reset;
  Desk.Key(kbDown); Desk.Key(kbEnter);
  Res := Desk.ExecView(Popup);
  Check(Res = cmOpen, 'a popup starts without a highlighted entry: Down chooses the first');
  Desk.Reset;
  Desk.Key(kbDown); Desk.Key(kbDown); Desk.Key(kbEnter);
  Check(Desk.ExecView(Popup) = cmSave, 'a popup: Down, Down, Enter');
  Desk.Insert(Popup);   { to put events back it must belong to a group }
  Desk.Reset;
  MakeKeyEvent(Ev, kbCtrlB, kbCtrlShift);
  Popup^.HandleEvent(Ev);
  Check((Desk.LastPut.What = evCommand) and (Desk.LastPut.Command = cmSave) and
    (Ev.What = evNothing), 'Ctrl+hot letter chooses an entry of a popup');
  Desk.Reset;
  MakeKeyEvent(Ev, kbAltQ, kbAltShift);
  Popup^.HandleEvent(Ev);
  Check(Ev.What = evNothing, 'a popup swallows Alt keys');
  Dispose(Popup, Done);

  Dispose(Bar, Done);
  Desk.Done;
  Check(GetFPCHeapStatus.CurrHeapUsed = Used0, 'no memory is left behind');
  Finish;
end.
