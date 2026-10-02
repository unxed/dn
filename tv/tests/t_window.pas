program t_window;
{$I ../src/tvdefs.inc}
uses TvCodePg, TvGeom, TvColors, TvCell, TvEvents, TvKeys, TvDrawBuf, TvScreen, TvObjs, TvViews,
  TvWindow;
{$I testlib.inc}

const
  W = 40;
  H = 12;

type
  { the top view of the tests: gives the events of a queue to the views that ask
    for them (the mouse loops of the frame and of the scroll bar) and keeps the
    last event put back }
  TTop = object(TGroup)
    Queue: array[0..7] of TEvent;
    QCount, QPos: Integer;
    Pending: TEvent;
    procedure GetEvent(var Event: TEvent); virtual;
    procedure PutEvent(var Event: TEvent); virtual;
    procedure Enqueue(What: Word; X, Y: Integer);
  end;

  { a view that fills itself with one character: the background, or a framed child }
  PFill = ^TFill;
  TFill = object(TView)
    Ch: Byte;
    constructor Init(const Bounds: TRect; ACh: Char);
    procedure Draw; virtual;
    function GetPalette: TPalette; virtual;
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
    Event.What := evNothing;
end;

procedure TTop.PutEvent(var Event: TEvent);
begin
  Pending := Event;
end;

procedure TTop.Enqueue(What: Word; X, Y: Integer);
begin
  FillChar(Queue[QCount], SizeOf(TEvent), 0);
  Queue[QCount].What := What;
  Queue[QCount].Where.X := X;
  Queue[QCount].Where.Y := Y;
  Queue[QCount].Buttons := mbLeftButton;
  Inc(QCount);
end;

constructor TFill.Init(const Bounds: TRect; ACh: Char);
begin
  inherited Init(Bounds);
  Ch := Ord(ACh);
end;

function HideZoom(Command: Word): Boolean;
begin
  Result := Command = cmZoom;
end;

procedure TFill.Draw;
var
  B: TDrawBuffer;
begin
  B.Init(W);
  B.MoveChar(0, Ch, GetColor(1).Lo, Size.X);
  WriteLineD(0, 0, Size.X, Size.Y, B);
  B.Done;
end;

function TFill.GetPalette: TPalette;
begin
  Result := MakePalette(#7);
end;

function Cell(X, Y: Integer): PScreenCell;
begin
  Result := ScreenBuffer + (Y * ScreenWidth + X);
end;

{ the text of a cell as UTF-8: characters stored as code page bytes are
  converted (the screen does the same when it shows them) }
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

function Bit(V: PView; Mask: Word): Boolean;
begin
  Result := (V^.State and Mask) = Mask;
end;

var
  Back, Boxed: PFill;
  Win, Win2: PWindow;
  Bar, HBar: PScrollBar;
  Scr: PScroller;
  SW, SL: PWindow;
  SSb, SSb2: PScrollBar;
  SSc, SSc2: PScroller;
  SM: TMemoryStream;
  I: Integer;
  Ev: TEvent;
  Min, Max: TPoint;
  Rc: TRect;
  Count: Integer;
  Before: TRect;

procedure CountViews(P: PView; Args: Pointer);
begin
  Inc(PInteger(Args)^);
end;

begin
  ScreenCreate(W, H);
  Desk.Init(R(0, 0, W, H));
  Desk.Options := 0;
  Desk.Buffer := ScreenBuffer;
  Desk.State := sfVisible or sfSelected or sfFocused or sfModal or sfExposed;
  Desk.QCount := 0;
  Desk.QPos := 0;

  New(Back, Init(R(0, 0, W, H), '.'));
  Desk.Insert(Back);

  { --- window and frame ---------------------------------------------------- }
  { the commands of a window are enabled while it is selected }
  DisableCommands([cmClose, cmZoom, cmResize, cmNext, cmPrev]);
  Check(not CommandEnabled(cmClose) and not CommandEnabled(cmZoom), 'window commands disabled');
  New(Win, Init(R(2, 1, 22, 9), 'Hi', 1));
  Desk.Insert(Win);
  Check(CommandEnabled(cmClose) and CommandEnabled(cmZoom) and CommandEnabled(cmResize) and
    CommandEnabled(cmNext) and CommandEnabled(cmPrev), 'a selected window enables its commands');
  Check(Win^.Frame <> nil, 'the window has a frame');
  Check(Win^.Last = PView(Win^.Frame), 'the frame is the only (bottom) subview');
  Check(Bit(Win, sfSelected or sfActive), 'a new window is selected and active');
  Check(Bit(Win^.Frame, sfActive), 'its frame is active');
  Check((Win^.Options and (ofSelectable or ofTopSelect)) = (ofSelectable or ofTopSelect),
    'window options');
  Check((Win^.State and sfShadow) <> 0, 'a window has a shadow');
  Check(Win^.GrowMode = (gfGrowAll or gfGrowRel), 'window grow mode');
  Check(Row(1, 2, 21) = '╔═[■]═══ Hi ═1═[↑]═╗', 'active frame: top line with icons, title, number');
  Check(Row(2, 2, 21) = '║                  ║', 'active frame: side lines');
  Check(Row(8, 2, 21) = '└─════════════════─┘', 'active frame: bottom line with resize corners');
  Check(AttrAt(2, 1) = $09, 'active frame color');
  Check(AttrAt(5, 1) = $0A, 'close icon color');
  Check(AttrAt(11, 1) = $09, 'title color');
  Check(CellText(5, 1) = '■', 'close icon');
  Check(CellText(18, 1) = '↑', 'zoom icon');
  Check(Row(1, 0, 1) = '..', 'the background shows beside the window');

  { a framed child is boxed in by the frame }
  New(Boxed, Init(R(4, 2, 10, 5), 'x'));
  Boxed^.Options := Boxed^.Options or ofFramed;
  Win^.Insert(Boxed);
  Win^.Frame^.DrawView;   { drawing the child does not draw the frame }
  Check(Row(2, 2, 21) = '║  ┌──────┐        ║', 'framed child: line above');
  Check(Row(3, 2, 21) = '║  │xxxxxx│        ║', 'framed child: side lines');
  Check(Row(6, 2, 21) = '║  └──────┘        ║', 'framed child: line below');
  Boxed^.Hide;
  Win^.Frame^.DrawView;
  Check(Row(2, 2, 21) = '║                  ║', 'a hidden framed child leaves no box');
  Dispose(Boxed, Done);

  { --- a second window: the first becomes passive ---------------------------- }
  New(Win2, Init(R(10, 4, 30, 11), 'Two', 2));
  Desk.Insert(Win2);
  Check(Desk.First = PView(Win2), 'the new window is in front');
  Check(Bit(Win2, sfActive), 'the new window is active (the background is not selectable)');
  Check(not Bit(Win, sfActive) and not Bit(Win^.Frame, sfActive), 'the first window is passive');
  Check(Row(1, 2, 21) = '┌─────── Hi ─1─────┐', 'passive frame: no icons, single lines');
  Check(AttrAt(2, 1) = $08, 'passive frame color');
  Check(Row(4, 10, 29) = '╔═[■]══ Two ═2═[↑]═╗', 'second window frame');
  Check(Row(8, 2, 10) = '└───────║', 'the second window covers the first one');
  Win^.Select;
  Check(Desk.First = PView(Win), 'Select brings a window (ofTopSelect) to the front');
  Check(Bit(Win, sfActive) and not Bit(Win2, sfActive), 'and makes it active');
  Check(Row(10, 10, 29) = '└──────────────────┘', 'the second window is passive now (bottom line)');
  Ev.What := evBroadcast;
  Ev.Command := cmSelectWindowNum;
  Ev.InfoInt := 2;
  Desk.HandleEvent(Ev);
  Check(Desk.First = PView(Win2), 'cmSelectWindowNum selects the window with that number');
  Check(Ev.What = evNothing, 'and the event is handled');

  { --- zoom -------------------------------------------------------------------- }
  Win2^.SizeLimits(Min, Max);
  Check((Min.X = 16) and (Min.Y = 6) and (Max.X = W) and (Max.Y = H), 'window size limits');
  Before := Win2^.GetBounds;
  Win2^.Zoom;
  Rc := Win2^.GetBounds;
  Check((Rc.A.X = 0) and (Rc.A.Y = 0) and (Rc.B.X = W) and (Rc.B.Y = H), 'Zoom: the whole desktop');
  Check((Win2^.ZoomRect.A.X = 10) and (Win2^.ZoomRect.A.Y = 4), 'the old bounds are remembered');
  Check(CellText(W - 5 + 1, 0) = '↕', 'zoomed: the unzoom icon');
  Win2^.Zoom;
  Rc := Win2^.GetBounds;
  Check((Rc.A.X = Before.A.X) and (Rc.A.Y = Before.A.Y) and (Rc.B.X = Before.B.X) and
    (Rc.B.Y = Before.B.Y), 'Zoom again: the old bounds');

  { --- frame, mouse -------------------------------------------------------------- }
  { close icon: pressed and released over it }
  Desk.QCount := 0; Desk.QPos := 0;
  Desk.Pending.What := evNothing;
  Desk.Enqueue(evMouseUp, 13, 4);
  FillChar(Ev, SizeOf(Ev), 0);
  Ev.What := evMouseDown;
  Ev.Where.X := 13; Ev.Where.Y := 4;
  Ev.Buttons := mbLeftButton;
  Desk.HandleEvent(Ev);
  Check((Desk.Pending.What = evCommand) and (Desk.Pending.Command = cmClose) and
    (Desk.Pending.InfoPtr = Pointer(Win2)), 'click on the close icon puts cmClose for the window');
  Check(Ev.What = evNothing, 'the click is handled');
  { pressed over it, released elsewhere: nothing }
  Desk.QCount := 0; Desk.QPos := 0;
  Desk.Pending.What := evNothing;
  Desk.Enqueue(evMouseUp, 20, 8);
  FillChar(Ev, SizeOf(Ev), 0);
  Ev.What := evMouseDown;
  Ev.Where.X := 13; Ev.Where.Y := 4;
  Ev.Buttons := mbLeftButton;
  Desk.HandleEvent(Ev);
  Check(Desk.Pending.What = evNothing, 'released elsewhere: no cmClose');
  { double click on the title: zoom }
  Desk.QCount := 0; Desk.QPos := 0;
  FillChar(Ev, SizeOf(Ev), 0);
  Ev.What := evMouseDown;
  Ev.Where.X := 20; Ev.Where.Y := 4;
  Ev.Buttons := mbLeftButton;
  Ev.EventFlags := meDoubleClick;
  Desk.HandleEvent(Ev);
  Check((Desk.Pending.What = evCommand) and (Desk.Pending.Command = cmZoom) and
    (Desk.Pending.InfoPtr = Pointer(Win2)), 'double click on the top line puts cmZoom');


  { --- scroll bar and scroller ----------------------------------------------------- }
  Win^.Select;
  Bar := Win^.StandardScrollBar(sbVertical or sbHandleKeyboard);
  HBar := Win^.StandardScrollBar(sbHorizontal);
  Rc := Bar^.GetBounds;
  Check((Rc.A.X = 19) and (Rc.A.Y = 1) and (Rc.B.X = 20) and (Rc.B.Y = 7), 'vertical scroll bar bounds');
  Rc := HBar^.GetBounds;
  Check((Rc.A.X = 2) and (Rc.A.Y = 7) and (Rc.B.X = 18) and (Rc.B.Y = 8), 'horizontal scroll bar bounds');
  Check((Bar^.Options and ofPostProcess) <> 0, 'sbHandleKeyboard: post-process');
  Check((HBar^.Options and ofPostProcess) = 0, 'otherwise not');
  Check(Bar^.Chars[3] = $FE, 'thumb character');
  Check(Bar^.Chars[0] = $1E, 'vertical bar: up arrow');
  Check(HBar^.Chars[0] = $11, 'horizontal bar: left arrow');
  Check(CellText(21, 2) = '▲', 'drawn: up arrow');
  Check(CellText(21, 7) = '▼', 'drawn: down arrow');
  Check(CellText(21, 3) = '▓', 'drawn: an empty range has no page area');
  Bar^.SetParams(3, 0, 10, 4, 1);
  Check((Bar^.Value = 3) and (Bar^.MaxVal = 10) and (Bar^.PgStep = 4), 'SetParams');
  Check(Bar^.GetPos = 2, 'thumb position');
  Check(CellText(21, 3) = '▒', 'drawn: page area');
  Check(CellText(21, 4) = '■', 'drawn: thumb');
  Bar^.SetValue(99);
  Check(Bar^.Value = 10, 'the value is limited to the maximum');
  Bar^.SetRange(0, 5);
  Check(Bar^.Value = 5, 'a smaller range limits the value');
  Bar^.SetParams(0, 0, 10, 4, 1);
  Check((Bar^.ScrollStep(sbDownArrow) = 1) and (Bar^.ScrollStep(sbUpArrow) = -1) and
    (Bar^.ScrollStep(sbPageDown) = 4) and (Bar^.ScrollStep(sbPageUp) = -4), 'ScrollStep');
  Check((Bar^.Step = -4) and not Bar^.ForceScroll, 'DN extensions: Step is the last step of ScrollStep, ForceScroll is off');
  EnableCommands([cmZoom]);
  Bar^.DisableCommands([cmZoom]);
  Check(not (cmZoom in CurCommandSet), 'DN extensions: DisableCommands as a method of a view');
  Bar^.EnableCommand(cmZoom);
  Check(cmZoom in CurCommandSet, 'DN extensions: EnableCommand as a method of a view');
  Check(Bar^.MenuEnabled(cmZoom) and Bar^.MenuEnabled(3000), 'DN extensions: MenuEnabled follows the command set (above 255 always)');
  CommandHiddenHook := @HideZoom;
  Check(not Bar^.MenuEnabled(cmZoom) and Bar^.MenuEnabled(cmClose), 'DN extensions: a hidden command is not enabled');
  CommandHiddenHook := nil;

  { keys }
  FillChar(Ev, SizeOf(Ev), 0);
  Ev.What := evKeyDown; Ev.KeyCode := kbDown;
  Bar^.HandleEvent(Ev);
  Check((Bar^.Value = 1) and (Ev.What = evNothing), 'Down: one step');
  Ev.What := evKeyDown; Ev.KeyCode := kbPgDn;
  Bar^.HandleEvent(Ev);
  Check(Bar^.Value = 5, 'PgDn: one page');
  Ev.What := evKeyDown; Ev.KeyCode := kbCtrlPgDn;
  Bar^.HandleEvent(Ev);
  Check(Bar^.Value = 10, 'Ctrl+PgDn: the end');
  Ev.What := evKeyDown; Ev.KeyCode := kbUp;
  Bar^.HandleEvent(Ev);
  Check(Bar^.Value = 9, 'Up: one step back');
  Ev.What := evKeyDown; Ev.KeyCode := kbCtrlPgUp;
  Bar^.HandleEvent(Ev);
  Check(Bar^.Value = 0, 'Ctrl+PgUp: the start');
  Ev.What := evKeyDown; Ev.KeyCode := kbEnter;
  Bar^.HandleEvent(Ev);
  Check(Ev.What = evKeyDown, 'other keys are not handled');
  { wheel }
  FillChar(Ev, SizeOf(Ev), 0);
  Ev.What := evMouseWheel; Ev.Wheel := mwDown;
  Bar^.HandleEvent(Ev);
  Check(Bar^.Value = 3, 'wheel down: three steps');
  Ev.What := evMouseWheel; Ev.Wheel := mwLeft;
  Bar^.HandleEvent(Ev);
  Check(Bar^.Value = 3, 'a vertical bar ignores a horizontal wheel');
  { mouse: the down arrow (global 21,7) }
  Desk.QCount := 0; Desk.QPos := 0;
  Desk.Enqueue(evMouseUp, 21, 7);
  FillChar(Ev, SizeOf(Ev), 0);
  Ev.What := evMouseDown; Ev.Where.X := 21; Ev.Where.Y := 7; Ev.Buttons := mbLeftButton;
  Bar^.HandleEvent(Ev);
  Check(Bar^.Value = 4, 'click on the down arrow: one step');
  { dragging the thumb to the last row before the arrow sets the maximum }
  Bar^.SetParams(0, 0, 10, 4, 1);
  Desk.QCount := 0; Desk.QPos := 0;
  Desk.Enqueue(evMouseMove, 21, 6);
  Desk.Enqueue(evMouseUp, 21, 6);
  FillChar(Ev, SizeOf(Ev), 0);
  Ev.What := evMouseDown; Ev.Where.X := 21; Ev.Where.Y := 3; Ev.Buttons := mbLeftButton;
  Bar^.HandleEvent(Ev);
  Check(Bar^.Value = 10, 'dragging the thumb to the end');

  { the scroller }
  Bar^.SetParams(0, 0, 10, 4, 1);
  Rc := Win^.GetExtent;
  Rc.Grow(-1, -1);
  New(Scr, Init(Rc, HBar, Bar));
  Win^.Insert(Scr);
  Scr^.SetLimit(100, 50);
  Check((Bar^.MaxVal = 50 - Scr^.Size.Y) and (Bar^.PgStep = Scr^.Size.Y - 1), 'SetLimit sets the vertical bar');
  Check((HBar^.MaxVal = 100 - Scr^.Size.X) and (HBar^.PgStep = Scr^.Size.X - 1), 'and the horizontal bar');
  Scr^.ScrollTo(5, 7);
  Check((Scr^.Delta.X = 5) and (Scr^.Delta.Y = 7), 'ScrollTo moves the scroller');
  Check((Bar^.Value = 7) and (HBar^.Value = 5), 'and the bars');
  Bar^.SetValue(12);
  Check(Scr^.Delta.Y = 12, 'a bar moves the scroller (cmScrollBarChanged)');
  Win2^.Select;
  Win^.Select;
  Check(Bit(Scr, sfSelected or sfActive) and Bit(Bar, sfVisible) and Bit(HBar, sfVisible),
    'the bars are shown while the scroller is selected and active');
  Win2^.Select;
  Check(not Bit(Win, sfActive) and not Bit(Bar, sfVisible) and not Bit(HBar, sfVisible),
    'and hidden when its window is passive');
  Win^.Select;
  Check(Bit(Bar, sfVisible), 'shown again');

  { --- Done and Close ------------------------------------------------------------- }
  Count := 0;
  Desk.ForEach(@CountViews, @Count);
  Check(Count = 3, 'the desk holds the background and two windows');
  FillChar(Ev, SizeOf(Ev), 0);
  Ev.What := evCommand;
  Ev.Command := cmClose;
  Win^.HandleEvent(Ev);
  Count := 0;
  Desk.ForEach(@CountViews, @Count);
  Check(Count = 2, 'cmClose closes the window');
  Check(Desk.First = PView(Win2), 'and it leaves the other window');
  Check(Row(1, 2, 5) = '....', 'the background shows where it was');
  Check(Bit(Win2, sfActive), 'the other window becomes active');

  { cmClose with the pointer of another window is not for this one }
  FillChar(Ev, SizeOf(Ev), 0);
  Ev.What := evCommand;
  Ev.Command := cmClose;
  Ev.InfoPtr := Back;
  Win2^.HandleEvent(Ev);
  Count := 0;
  Desk.ForEach(@CountViews, @Count);
  Check((Count = 2) and (Ev.What = evCommand), 'cmClose for another view is ignored');
  { a modal window turns cmClose into cmCancel }
  Win2^.State := Win2^.State or sfModal;
  Desk.Pending.What := evNothing;
  FillChar(Ev, SizeOf(Ev), 0);
  Ev.What := evCommand;
  Ev.Command := cmClose;
  Win2^.HandleEvent(Ev);
  Check((Desk.Pending.What = evCommand) and (Desk.Pending.Command = cmCancel), 'modal: cmClose becomes cmCancel');
  Win2^.State := Win2^.State and not sfModal;

  Dispose(Win2, Done);
  Count := 0;
  Desk.ForEach(@CountViews, @Count);
  Check(Count = 1, 'Dispose removes a window from the desk');
  Desk.Done;
  { streams: a window with a frame, a scroll bar and a scroller that points to it }
  RegisterType(RView);
  RegisterType(RGroup);
  RegisterType(RFrame);
  RegisterType(RScrollBar);
  RegisterType(RScroller);
  RegisterType(RWindow);
  SW := New(PWindow, Init(R(0, 0, 30, 10), 'Hello', 3));
  SW^.Flags := SW^.Flags and not wfZoom;
  SSb := SW^.StandardScrollBar(sbVertical or sbHandleKeyboard);
  SSc := New(PScroller, Init(R(1, 1, 28, 9), nil, SSb));
  SSc^.Limit.X := 100;
  SSc^.Limit.Y := 50;
  SSb^.SetParams(3, 0, 40, 5, 1);
  SW^.Insert(SSc);
  SM.Init(0, 512);
  SM.Put(SW);
  Check(SM.Status = stOk, 'a window is stored');
  SM.Seek(0);
  SL := PWindow(SM.Get);
  Check((SL <> nil) and (SM.Status = stOk), 'a window is loaded');
  Check((SL^.Title^ = 'Hello') and (SL^.Number = 3) and (SL^.Flags and wfZoom = 0), 'the title, the number and the flags');
  Check((SL^.Frame <> nil) and (SL^.Frame^.Owner = PGroup(SL)), 'the frame is a view of the window');
  SSc2 := nil;
  SSb2 := nil;
  for I := 1 to 8 do
    if SL^.At(I) <> nil then
    begin
      if TypeOf(SL^.At(I)^) = TypeOf(TScroller) then SSc2 := PScroller(SL^.At(I));
      if TypeOf(SL^.At(I)^) = TypeOf(TScrollBar) then SSb2 := PScrollBar(SL^.At(I));
    end;
  Check((SSc2 <> nil) and (SSb2 <> nil), 'the scroller and the scroll bar are loaded');
  Check(SSc2^.VScrollBar = PScrollBar(SSb2), 'the scroller points to the loaded scroll bar');
  Check((SSb2^.Value = 3) and (SSb2^.MaxVal = 40) and (SSb2^.PgStep = 5), 'the values of the scroll bar');
  Check((SSc2^.Limit.X = 100) and (SSc2^.Limit.Y = 50), 'the limit of the scroller');
  Dispose(SL, Done);
  Dispose(SW, Done);
  SM.Done;

  Finish;
end.
