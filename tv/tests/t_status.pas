program t_status;
{$I ../src/tvdefs.inc}
uses TvCodePg, TvGeom, TvColors, TvCell, TvEvents, TvKeys, TvDrawBuf, TvScreen, TvViews,
  TvUtil, TvMenus;
{$I testlib.inc}

const
  W = 40;
  H = 12;
  Y = H - 1;

type
  { the top view: a queue of events for the mouse loop of the status line, and the
    event put back }
  TTop = object(TGroup)
    Queue: array[0..7] of TEvent;
    QCount, QPos: Integer;
    LastPut: TEvent;
    procedure GetEvent(var Event: TEvent); virtual;
    procedure PutEvent(var Event: TEvent); virtual;
  end;

  { a status line with a hint }
  PHintLine = ^THintLine;
  THintLine = object(TStatusLine)
    function Hint(AHelpCtx: Word): ShortString; virtual;
  end;

  { a view that has a help context }
  PHelpView = ^THelpView;
  THelpView = object(TView)
    constructor Init(const Bounds: TRect; ACtx: Word);
  end;

var
  Desk: TTop;

procedure TTop.GetEvent(var Event: TEvent);
begin
  if QPos < QCount then
  begin
    Event := Queue[QPos];
    Inc(QPos);
  end
  else
  begin
    ClearEvent(Event);
    Event.What := evMouseUp;
  end;
end;

procedure TTop.PutEvent(var Event: TEvent);
begin
  LastPut := Event;
end;

function THintLine.Hint(AHelpCtx: Word): ShortString;
begin
  if AHelpCtx = 0 then
    Result := 'Help text'
  else
    Result := '';
end;

constructor THelpView.Init(const Bounds: TRect; ACtx: Word);
begin
  inherited Init(Bounds);
  HelpCtx := ACtx;
  Options := Options or ofSelectable;
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

function Row(Yy, X0, X1: Integer): ShortString;
var
  X: Integer;
begin
  Result := '';
  for X := X0 to X1 do
    Result := Result + CellText(X, Yy);
end;

function AttrAt(X, Yy: Integer): Byte;
begin
  Result := AttrAsBIOSByte(Cell(X, Yy)^.Attribute);
end;

function R(A, B, C, D: Integer): TRect;
begin
  Result.Assign(A, B, C, D);
end;

function Defs: PStatusDef;
begin
  Defs := NewStatusDef(0, 99,
    NewStatusKey('~F1~ Help', kbF1, cmHelp,
    NewStatusKey('~Alt-X~ Exit', kbAltX, cmQuit, nil)),
    NewStatusDef(100, 199,
      NewStatusKey('~F2~ Save', kbF2, cmSave, nil), nil));
end;

var
  Line: PHintLine;
  Plain: PStatusLine;
  HV: PHelpView;
  Ev: TEvent;
  Used0: PtrUInt;

begin
  ScreenCreate(W, H);
  Desk.Init(R(0, 0, W, H));
  Desk.Options := 0;
  Desk.Buffer := ScreenBuffer;
  Desk.State := sfVisible or sfSelected or sfFocused or sfModal or sfExposed;
  EnableCommands([cmHelp, cmQuit, cmSave]);
  Used0 := GetFPCHeapStatus.CurrHeapUsed;

  New(Line, Init(R(0, Y, W, H), Defs));
  Desk.Insert(Line);
  Check(Line^.Items <> nil, 'the items for the help context 0');
  Check(Line^.Items^.Text^ = '~F1~ Help', 'the first item');
  Check((Line^.Options and ofPreProcess) <> 0, 'the status line sees keys first');
  Check(Line^.GrowMode = (gfGrowLoY or gfGrowHiX or gfGrowHiY), 'grow mode');
  Check(Row(Y, 0, 20) = ' F1 Help  Alt-X Exit ', 'the items are drawn');
  Check(AttrAt(0, Y) = $02, 'normal color');
  Check(AttrAt(1, Y) = $04, 'hot key color');
  Check(AttrAt(4, Y) = $02, 'text after the hot key');
  Check(Row(Y, 21, 31) = '│ Help text', 'the hint follows the items after a separator');
  Check(AttrAt(25, Y) = $02, 'the hint has the normal color');

  { keys }
  MakeKeyEvent(Ev, kbF1, 0);
  Line^.HandleEvent(Ev);
  Check((Ev.What = evCommand) and (Ev.Command = cmHelp), 'a key of an item becomes its command');
  MakeKeyEvent(Ev, kbAltX, kbAltShift);
  Line^.HandleEvent(Ev);
  Check((Ev.What = evCommand) and (Ev.Command = cmQuit), 'Alt-X becomes cmQuit');
  MakeKeyEvent(Ev, kbF2, 0);
  Line^.HandleEvent(Ev);
  Check(Ev.What = evKeyDown, 'a key of another help context is not handled');
  { disabled commands }
  DisableCommand(cmQuit);
  ClearEvent(Ev);
  Ev.What := evBroadcast;
  Ev.Command := cmCommandSetChanged;
  Line^.HandleEvent(Ev);
  Check(AttrAt(10, Y) = $03, 'a disabled item has the disabled color');
  Check(AttrAt(1, Y) = $04, 'the other items stay normal');
  MakeKeyEvent(Ev, kbAltX, kbAltShift);
  Line^.HandleEvent(Ev);
  Check(Ev.What = evKeyDown, 'the key of a disabled item is not handled');
  EnableCommand(cmQuit);

  { mouse: press and release on an item }
  Desk.QCount := 1; Desk.QPos := 0;
  ClearEvent(Desk.Queue[0]);
  Desk.Queue[0].What := evMouseUp;
  Desk.Queue[0].Where.X := 3; Desk.Queue[0].Where.Y := Y;
  Desk.LastPut.What := evNothing;
  ClearEvent(Ev);
  Ev.What := evMouseDown; Ev.Where.X := 3; Ev.Where.Y := Y; Ev.Buttons := mbLeftButton;
  Line^.HandleEvent(Ev);
  Check((Desk.LastPut.What = evCommand) and (Desk.LastPut.Command = cmHelp), 'a click on an item puts its command');
  Check(Ev.What = evNothing, 'the click is handled');
  { press on an item, move away, release: nothing }
  Desk.QCount := 2; Desk.QPos := 0;
  ClearEvent(Desk.Queue[0]);
  Desk.Queue[0].What := evMouseMove;
  Desk.Queue[0].Where.X := 30; Desk.Queue[0].Where.Y := Y;
  ClearEvent(Desk.Queue[1]);
  Desk.Queue[1].What := evMouseUp;
  Desk.Queue[1].Where.X := 30; Desk.Queue[1].Where.Y := Y;
  Desk.LastPut.What := evNothing;
  ClearEvent(Ev);
  Ev.What := evMouseDown; Ev.Where.X := 3; Ev.Where.Y := Y; Ev.Buttons := mbLeftButton;
  Line^.HandleEvent(Ev);
  Check(Desk.LastPut.What = evNothing, 'released away from the item: no command');
  { release on another item chooses that one }
  Desk.QCount := 2; Desk.QPos := 0;
  ClearEvent(Desk.Queue[0]);
  Desk.Queue[0].What := evMouseMove;
  Desk.Queue[0].Where.X := 12; Desk.Queue[0].Where.Y := Y;
  ClearEvent(Desk.Queue[1]);
  Desk.Queue[1].What := evMouseUp;
  Desk.Queue[1].Where.X := 12; Desk.Queue[1].Where.Y := Y;
  ClearEvent(Ev);
  Ev.What := evMouseDown; Ev.Where.X := 3; Ev.Where.Y := Y; Ev.Buttons := mbLeftButton;
  Line^.HandleEvent(Ev);
  Check((Desk.LastPut.What = evCommand) and (Desk.LastPut.Command = cmQuit),
    'dragging to another item chooses that one');

  { the help context of the top view selects the items }
  New(HV, Init(R(0, 0, 10, 5), 150));
  Desk.Insert(HV);
  Line^.Update;
  Check(Line^.HelpCtx = 150, 'Update takes the help context of the top view');
  Check(Line^.Items^.Text^ = '~F2~ Save', 'and its items');
  Check(Row(Y, 0, 10) = ' F2 Save   ', 'the other items are drawn');
  Check(Row(Y, 21, 23) = '   ', 'and no hint');
  MakeKeyEvent(Ev, kbF2, 0);
  Line^.HandleEvent(Ev);
  Check((Ev.What = evCommand) and (Ev.Command = cmSave), 'keys of the new items');
  Dispose(HV, Done);
  Line^.Update;
  Check((Line^.HelpCtx = 0) and (Line^.Items^.Text^ = '~F1~ Help'), 'the items return with the help context');

  Dispose(Line, Done);
  Check(GetFPCHeapStatus.CurrHeapUsed = Used0, 'the status line frees its definitions');

  { the base class has no hint }
  New(Plain, Init(R(0, Y, W, H), Defs));
  Desk.Insert(Plain);
  Check(Row(Y, 21, 23) = '   ', 'the base status line has no hint');
  New(HV, Init(R(0, 0, 10, 5), 1000));
  Desk.Insert(HV);
  Plain^.Update;
  Check((Plain^.HelpCtx = 1000) and (Plain^.Items = nil),
    'a help context outside all definitions: no items');
  Check(Row(Y, 0, 10) = '           ', 'and nothing is drawn but blanks');
  Dispose(HV, Done);
  Dispose(Plain, Done);
  Desk.Done;
  Finish;
end.
