program t_views;
{$I ../src/tvdefs.inc}
uses TvGeom, TvColors, TvCell, TvEvents, TvKeys, TvDrawBuf, TvScreen, TvViews;
{$I testlib.inc}

const
  W = 40;
  H = 12;

type
  { a view that fills itself with one character, in one color }
  PFill = ^TFill;
  TFill = object(TView)
    Ch: Byte;
    Col: Byte;
    constructor Init(const Bounds: TRect; ACh: Char; ACol: Byte);
    destructor Done; virtual;
    procedure Draw; virtual;
    function GetPalette: TPalette; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
  end;

var
  Desk: TGroup;
  DoneCount: Integer = 0;

constructor TFill.Init(const Bounds: TRect; ACh: Char; ACol: Byte);
begin
  inherited Init(Bounds);
  Ch := Ord(ACh);
  Col := ACol;
end;

destructor TFill.Done;
begin
  Inc(DoneCount);
  inherited Done;
end;

procedure TFill.Draw;
var
  B: TDrawBuffer;
  Pair: TAttrPair;
begin
  B.Init(W);
  Pair := GetColor(1);
  B.MoveChar(0, Ch, Pair.Lo, Size.X);
  WriteLineD(0, 0, Size.X, Size.Y, B);
  B.Done;
end;

function TFill.GetPalette: TPalette;
begin
  Result := MakePalette(Chr(Col));
end;

procedure TFill.HandleEvent(var Event: TEvent);
begin
  inherited HandleEvent(Event);
  if (Event.What = evCommand) and (Event.Command = cmOK) then
    ClearEvent(Event);
end;

function Cell(X, Y: Integer): PScreenCell;
begin
  Result := ScreenBuffer + (Y * ScreenWidth + X);
end;

{ the characters of a row between two columns; '_' for a cell nothing drew }
function Row(Y, X0, X1: Integer): ShortString;
var
  X: Integer;
  T: ShortString;
begin
  Result := '';
  for X := X0 to X1 do
  begin
    T := ScText(Cell(X, Y)^.Character);
    if T = #0 then
      Result := Result + '_'
    else
      Result := Result + T[1];
  end;
end;

function AttrAt(X, Y: Integer): Byte;
begin
  Result := AttrAsBIOSByte(Cell(X, Y)^.Attribute);
end;

function Shadowed(X, Y: Integer): Boolean;
begin
  Result := (AttrStyle(Cell(X, Y)^.Attribute) and slWindowShadow) <> 0;
end;

function R(A, B, C, D: Integer): TRect;
begin
  Result.Assign(A, B, C, D);
end;

var
  Bg, A, B, E, F, C: PFill;
  Rc: TRect;
  Ev: TEvent;
  Cmds: TCommandSet;
  Min, Max: TPoint;
  G: PGroup;
  V1, V2, V3: PFill;
  Count: Integer;

procedure CountViews(P: PView; Args: Pointer);
begin
  Inc(PInteger(Args)^);
end;

function IsV2(P: PView; Args: Pointer): Boolean;
begin
  Result := P = PView(Args);
end;

begin
  ScreenCreate(W, H);
  { the top group, set up as the application does }
  Desk.Init(R(0, 0, W, H));
  Desk.Options := 0;
  Desk.Buffer := ScreenBuffer;
  Desk.State := sfVisible or sfSelected or sfFocused or sfModal or sfExposed;

  { background and two overlapping views }
  New(Bg, Init(R(0, 0, W, H), '.', $07));
  Desk.Insert(Bg);
  Check(Row(0, 0, 5) = '......', 'inserting the background draws it');
  Check(Row(H - 1, W - 3, W - 1) = '...', 'background covers the whole screen');
  Check(AttrAt(0, 0) = $07, 'background attribute through the palette');

  New(A, Init(R(2, 1, 12, 4), 'A', $1F));
  Desk.Insert(A);
  Check(Row(1, 0, 13) = '..AAAAAAAAAA..', 'a view is drawn where it is');
  Check(Row(3, 0, 13) = '..AAAAAAAAAA..', 'a view is drawn on all its rows');
  Check(Row(4, 0, 13) = '..............', 'not below its bottom edge');
  Check(AttrAt(2, 1) = $1F, 'attribute of a view');

  New(B, Init(R(7, 2, 17, 6), 'B', $2E));
  Desk.Insert(B);
  Check(Row(2, 0, 18) = '..AAAAABBBBBBBBBB..', 'the newer view is in front');
  Check(Row(5, 5, 18) = '..BBBBBBBBBB..', 'rows below the older view');
  Check(Desk.First = PView(B), 'First is the top view');
  Check(Desk.Last = PView(Bg), 'Last is the bottom view');

  { z-order }
  A^.MakeFirst;
  Check(Row(2, 0, 18) = '..AAAAAAAAAABBBBB..', 'MakeFirst brings a view to the front');
  Check(Desk.First = PView(A), 'it is now the first view');
  B^.MakeFirst;
  Check(Row(2, 0, 18) = '..AAAAABBBBBBBBBB..', 'and back');

  { hiding and showing redraw what is below }
  B^.Hide;
  Check(Row(2, 0, 18) = '..AAAAAAAAAA.......', 'Hide uncovers what was below');
  Check(Row(5, 5, 18) = '..............', 'the background shows where the hidden view was');
  B^.Show;
  Check(Row(2, 0, 18) = '..AAAAABBBBBBBBBB..', 'Show draws the view again');

  { moving }
  B^.MoveTo(20, 6);
  Check(Row(2, 0, 18) = '..AAAAAAAAAA.......', 'moved away: the old place is redrawn');
  Check(Row(6, 18, 31) = '..BBBBBBBBBB..', 'drawn at the new place');
  Check((B^.Origin.X = 20) and (B^.Origin.Y = 6) and (B^.Size.X = 10), 'origin and size after MoveTo');
  B^.GrowTo(4, 2);
  Check(Row(6, 18, 27) = '..BBBB....', 'GrowTo makes it smaller');
  Rc := B^.GetBounds;
  Check((Rc.A.X = 20) and (Rc.B.X = 24) and (Rc.B.Y = 8), 'GetBounds after GrowTo');
  Rc.Assign(7, 2, 17, 6);
  B^.Locate(Rc);
  Check(Row(2, 0, 18) = '..AAAAABBBBBBBBBB..', 'Locate moves and resizes');
  Rc.Assign(0, 0, 999, 999);
  B^.Locate(Rc);
  Check((B^.Size.X = W) and (B^.Size.Y = H), 'Locate limits the size to the owner');
  Rc.Assign(7, 2, 17, 6);
  B^.Locate(Rc);

  { visibility }
  New(E, Init(R(20, 8, 24, 10), 'E', $4F));
  Desk.Insert(E);
  Check(E^.Exposed, 'a view with nothing over it is exposed');
  New(F, Init(R(19, 7, 25, 11), 'F', $5F));
  Desk.Insert(F);
  Check(not E^.Exposed, 'a view completely covered is not exposed');
  Check(F^.Exposed, 'the covering view is exposed');
  Check(Row(8, 18, 26) = '.FFFFFF..', 'the covering view is what shows');
  New(C, Init(R(18, 8, 21, 9), 'C', $6F));
  Desk.Insert(C);
  F^.Hide;
  Check(E^.Exposed, 'exposed again once the cover is hidden');
  F^.Show;
  Check(not E^.Exposed, 'and covered again');
  Desk.Delete(C);
  Dispose(C, Done);
  Desk.Delete(F);
  Dispose(F, Done);
  Desk.Delete(E);
  Dispose(E, Done);

  { shadows }
  B^.SetState(sfShadow, True);
  Check(Shadowed(17, 3) and Shadowed(18, 3), 'the shadow is on the right of the view');
  Check(Shadowed(9, 6) and Shadowed(18, 6), 'and below it');
  Check(not Shadowed(19, 3), 'not further right');
  Check(not Shadowed(7, 6) and not Shadowed(8, 6), 'the first columns below are not shadowed');
  Check(not Shadowed(16, 3), 'the view itself is not shadowed');
  Check(Row(3, 15, 19) = 'BB...', 'the shadow keeps the text under it');
  B^.SetState(sfShadow, False);
  Check(not Shadowed(17, 3) and not Shadowed(9, 6), 'removing the shadow redraws the area');

  { bounds of children when the owner changes size }
  New(G, Init(R(0, 0, 20, 6)));
  New(V1, Init(R(0, 0, 10, 3), 'x', $07));
  V1^.GrowMode := gfGrowHiX;
  G^.Insert(V1);
  G^.Size.X := 20;
  Rc.Assign(0, 0, 0, 0);
  V1^.CalcBounds(Rc, Point(10, 0));
  Check((Rc.A.X = 0) and (Rc.B.X = 20) and (Rc.B.Y = 3), 'CalcBounds with gfGrowHiX');
  V1^.GrowMode := gfGrowLoX or gfGrowHiX;
  V1^.CalcBounds(Rc, Point(4, 0));
  Check((Rc.A.X = 4) and (Rc.B.X = 14) and (Rc.B.Y = 3), 'CalcBounds with gfGrowLoX or gfGrowHiX moves the view');
  V1^.GrowMode := 0;
  V1^.CalcBounds(Rc, Point(7, 7));
  Check((Rc.A.X = 0) and (Rc.B.X = 10), 'CalcBounds without grow flags keeps the view');
  Dispose(G, Done);
  Check(DoneCount = 4, 'Dispose of a group disposes its views');

  { selection and focus }
  Desk.SetCurrent(nil, normalSelect);
  New(V1, Init(R(0, 0, 3, 1), '1', $07));
  New(V2, Init(R(4, 0, 7, 1), '2', $07));
  New(V3, Init(R(8, 0, 11, 1), '3', $07));
  V1^.Options := ofSelectable;
  V2^.Options := ofSelectable;
  V3^.Options := ofSelectable;
  New(G, Init(R(20, 0, 40, 2)));
  G^.State := G^.State or sfExposed;
  G^.Insert(V1);
  G^.Insert(V2);
  G^.Insert(V3);
  { ResetCurrent looks from Last, the bottom view: the first inserted one }
  Check(G^.Current = PView(V1), 'the first inserted selectable view becomes current');
  Check((V1^.State and sfSelected) <> 0, 'and selected');
  Check((V3^.State and sfSelected) = 0, 'the others are not');
  V3^.Select;
  Check((G^.Current = PView(V3)) and ((V3^.State and sfSelected) <> 0), 'Select works');
  V1^.Select;
  Check((G^.Current = PView(V1)) and ((V1^.State and sfSelected) <> 0)
    and ((V3^.State and sfSelected) = 0), 'Select moves the selection');
  G^.SelectNext(True);
  Check(G^.Current = PView(V3), 'SelectNext goes on (toward the back of the list)');
  G^.SelectNext(False);
  Check(G^.Current = PView(V1), 'SelectNext backwards');
  V2^.Options := V2^.Options and not ofSelectable;
  G^.SelectNext(True);
  Check(G^.Current <> PView(V2), 'a view that cannot be selected is skipped');
  V3^.State := V3^.State or sfDisabled;
  V1^.Select;
  G^.SelectNext(True);
  Check(G^.Current = PView(V1), 'a disabled view is skipped too');
  V3^.State := V3^.State and not sfDisabled;

  { group access }
  Count := 0;
  G^.ForEach(@CountViews, @Count);
  Check(Count = 3, 'ForEach visits all the views');
  Check(G^.FirstThat(@IsV2, V2) = PView(V2), 'FirstThat');
  Check(G^.FirstThat(@IsV2, B) = nil, 'FirstThat finds nothing');
  Check((G^.IndexOf(V1) = 3) and (G^.IndexOf(V3) = 1), 'IndexOf counts from Last (the bottom view is 3 here)');
  Check(G^.At(0) = G^.Last, 'At(0) is Last');
  Check(G^.First = PView(V3), 'First is the view inserted last');
  G^.Delete(V2);
  Check((V2^.Owner = nil) and (V2^.Next = nil), 'Delete detaches a view');
  Count := 0;
  G^.ForEach(@CountViews, @Count);
  Check(Count = 2, 'Delete removes it from the list');
  Dispose(V2, Done);
  Dispose(G, Done);

  { the caret }
  New(V1, Init(R(3, 2, 8, 3), 'q', $07));
  V1^.Options := ofSelectable;
  Desk.Insert(V1);
  Check((V1^.State and sfFocused) <> 0, 'a selectable view inserted into a focused group is focused');
  V1^.SetCursor(2, 0);
  Check(CaretSize = 0, 'no caret before the cursor is shown');
  V1^.ShowCursor;
  Check((CaretX = 5) and (CaretY = 2) and (CaretSize = CursorLines), 'the caret is where the cursor is, in screen coordinates');
  V1^.BlockCursor;
  Check(CaretSize = 100, 'a block cursor');
  V1^.NormalCursor;
  V1^.HideCursor;
  Check(CaretSize = 0, 'a hidden cursor hides the caret');
  V1^.ShowCursor;
  New(F, Init(R(4, 1, 10, 4), 'F', $5F));
  Desk.Insert(F);
  V1^.ResetCursor;
  Check(CaretSize = 0, 'no caret under a view that covers it');
  Desk.Delete(F);
  Dispose(F, Done);
  V1^.ResetCursor;
  Check(CaretSize = CursorLines, 'the caret is back when uncovered');
  Desk.Delete(V1);
  Dispose(V1, Done);

  { messages }
  New(V1, Init(R(0, 0, 2, 1), 'm', $07));
  Check(Message(V1, evCommand, cmOK, nil) = V1, 'a message that is handled returns the receiver');
  Check(Message(V1, evCommand, cmCancel, nil) = nil, 'a message that is not handled returns nil');
  Check(Message(nil, evCommand, cmOK, nil) = nil, 'a message to nil');
  V1^.ClearEvent(Ev);
  Check((Ev.What = evNothing) and (Ev.InfoPtr = V1), 'ClearEvent');
  Dispose(V1, Done);

  { commands }
  Check(not CommandEnabled(cmZoom), 'zoom is disabled at the start');
  Check(CommandEnabled(cmQuit) and CommandEnabled(cmOK), 'the others are enabled');
  Check(CommandEnabled(1000) and CommandEnabled(40000), 'commands above 255 are always enabled');
  CommandSetChanged := False;
  EnableCommand(cmZoom);
  Check(CommandEnabled(cmZoom) and CommandSetChanged, 'EnableCommand marks the set as changed');
  CommandSetChanged := False;
  EnableCommand(cmZoom);
  Check(not CommandSetChanged, 'enabling an enabled command changes nothing');
  Cmds := [cmZoom, cmQuit];
  DisableCommands(Cmds);
  Check(not CommandEnabled(cmZoom) and not CommandEnabled(cmQuit), 'DisableCommands');
  GetCommands(Cmds);
  EnableCommands([cmQuit, cmClose]);
  Check(CommandEnabled(cmQuit) and CommandEnabled(cmClose), 'EnableCommands');
  SetCommands(Cmds);
  Check(not CommandEnabled(cmClose) and not CommandEnabled(cmQuit), 'SetCommands restores a saved set');
  SetCmdState([cmQuit], True);
  Check(CommandEnabled(cmQuit), 'SetCmdState enable');

  { colors }
  New(V1, Init(R(0, 0, 2, 1), 'c', $07));
  V1^.Options := 0;
  Check(AttrAsBIOSByte(V1^.MapColor(1)) = $07, 'color 1 through the palette of the view');
  Check(AttrEq(V1^.MapColor(2), ErrorAttr), 'a color beyond the palette is the error color');
  Check(AttrEq(V1^.MapColor(0), ErrorAttr), 'color 0 is the error color');
  Check(PaletteSize(MakePalette(#1#2#3)) = 3, 'palette size');
  Dispose(V1, Done);

  Desk.State := Desk.State and not sfExposed;
  Dispose(Bg, Done);
  Dispose(A, Done);
  Dispose(B, Done);
  Desk.Done;
  ScreenDestroy;
  Finish;
end.
