{ TvList: TListViewer and TListBox.

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/views.h, dialogs.h (class declarations, TListBoxRec)
    source/tvision/tlstview.cpp, tlistbox.cpp, tvtext2.cpp (emptyText)
  Borland disclaimer and MIT notice: tv/COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/DESIGN.md):
    - GetText is a function that returns a ShortString (255 characters at most);
    - Done replaces shutDown (it clears the pointers to the scroll bars);
    - the items of TListBox are PStr (as in TStringCollection);
    - streams are not translated yet. }
unit TvList;

{$I tvdefs.inc}

interface

uses
  TvGeom, TvColors, TvCell, TvKeys, TvEvents, TvDrawBuf, TvObjs, TvUtil, TvViews, TvDialog,
  TvWindow;

const
  EmptyText = '<empty>';

type
  { Palette: 1 = active, 2 = inactive, 3 = focused, 4 = selected, 5 = divider }
  PListViewer = ^TListViewer;
  TListViewer = object(TView)
    HScrollBar: PScrollBar;
    VScrollBar: PScrollBar;
    NumCols: Integer;
    TopItem: Integer;
    Focused: Integer;
    Range: Integer;
    constructor Init(const Bounds: TRect; ANumCols: Integer; AHScrollBar, AVScrollBar: PScrollBar);
    constructor Load(var S: TStream);
    procedure Store(var S: TStream);
    destructor Done; virtual;
    procedure ChangeBounds(const Bounds: TRect); virtual;
    procedure Draw; virtual;
    procedure FocusItem(Item: Integer); virtual;
    procedure FocusItemNum(Item: Integer);
    function GetPalette: TPalette; virtual;
    function GetText(Item, MaxLen: Integer): ShortString; virtual;
    function IsSelected(Item: Integer): Boolean; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure SelectItem(Item: Integer); virtual;
    procedure SetRange(ARange: Integer);
    procedure SetState(AState: Word; Enable: Boolean); virtual;
  end;

  { the data record of a list box: the collection (owned by the list box after SetData)
    and the number of the selected item }
  PListBoxRec = ^TListBoxRec;
  TListBoxRec = record
    List: PCollection;
    Selection: Word;
  end;

  PListBox = ^TListBox;
  TListBox = object(TListViewer)
    List: PCollection;
    constructor Init(const Bounds: TRect; ANumCols: Integer; AScrollBar: PScrollBar);
    constructor Load(var S: TStream);
    procedure Store(var S: TStream);
    destructor Done; virtual;
    function DataSize: Integer; virtual;
    procedure GetData(var Rec); virtual;
    function GetText(Item, MaxLen: Integer): ShortString; virtual;
    procedure NewList(AList: PCollection);
    procedure SetData(var Rec); virtual;
  end;

const
  ListViewerPalette = #$1A#$1A#$1B#$1C#$1D;

var
  { stream records (see RView of TvViews) }
  RListViewer, RListBox: TStreamRec;

implementation

const
  MouseAutosToSkip = 4;

{ --- TListViewer ------------------------------------------------------------- }

constructor TListViewer.Init(const Bounds: TRect; ANumCols: Integer; AHScrollBar,
  AVScrollBar: PScrollBar);
var
  ArStep, PgStep: Integer;
begin
  inherited Init(Bounds);
  NumCols := ANumCols;
  TopItem := 0;
  Focused := 0;
  Range := 0;
  Options := Options or (ofFirstClick or ofSelectable);
  EventMask := EventMask or evBroadcast;
  if AVScrollBar <> nil then
  begin
    if NumCols = 1 then
    begin
      PgStep := Size.Y - 1;
      ArStep := 1;
    end
    else
    begin
      PgStep := Size.Y * NumCols;
      ArStep := Size.Y;
    end;
    AVScrollBar^.SetStep(PgStep, ArStep);
  end;
  if AHScrollBar <> nil then
    AHScrollBar^.SetStep(Size.X div NumCols, 1);
  HScrollBar := AHScrollBar;
  VScrollBar := AVScrollBar;
end;

destructor TListViewer.Done;
begin
  HScrollBar := nil;
  VScrollBar := nil;
  inherited Done;
end;

procedure TListViewer.ChangeBounds(const Bounds: TRect);
begin
  inherited ChangeBounds(Bounds);
  if HScrollBar <> nil then
    HScrollBar^.SetStep(Size.X div NumCols, HScrollBar^.ArStep);
  if VScrollBar <> nil then
    VScrollBar^.SetStep(Size.Y, VScrollBar^.ArStep);
end;

procedure TListViewer.Draw;
var
  I, J, Item, ColWidth, CurCol, Indent, ScOff: Integer;
  NormalColor, SelectedColor, FocusedColor, Color: TColorAttr;
  B: TDrawBuffer;
  FocusedVis: Boolean;
begin
  if (State and (sfSelected or sfActive)) = (sfSelected or sfActive) then
  begin
    NormalColor := GetColor(1).Lo;
    FocusedColor := GetColor(3).Lo;
    SelectedColor := GetColor(4).Lo;
  end
  else
  begin
    NormalColor := GetColor(2).Lo;
    SelectedColor := GetColor(4).Lo;
    FocusedColor := NormalColor;   { unused }
  end;
  if HScrollBar <> nil then
    Indent := HScrollBar^.Value
  else
    Indent := 0;
  FocusedVis := False;
  ColWidth := Size.X div NumCols + 1;
  B.Init(Size.X);
  for I := 0 to Size.Y - 1 do
  begin
    for J := 0 to NumCols - 1 do
    begin
      Item := J * Size.Y + I + TopItem;
      CurCol := J * ColWidth;
      if ((State and (sfSelected or sfActive)) = (sfSelected or sfActive)) and
        (Focused = Item) and (Range > 0) then
      begin
        Color := FocusedColor;
        SetCursor(CurCol + 1, I);
        ScOff := 0;
        FocusedVis := True;
      end
      else if (Item < Range) and IsSelected(Item) then
      begin
        Color := SelectedColor;
        ScOff := 2;
      end
      else
      begin
        Color := NormalColor;
        ScOff := 4;
      end;
      B.MoveChar(CurCol, Ord(' '), Color, ColWidth);
      if Item < Range then
      begin
        if Indent < 255 then
          B.MoveStrS(CurCol + 1, GetText(Item, 255), Color, ColWidth, Indent);
        if ShowMarkers then
        begin
          B.PutChar(CurCol, SpecialChars[ScOff]);
          B.PutChar(CurCol + ColWidth - 2, SpecialChars[ScOff + 1]);
        end;
      end
      else if (I = 0) and (J = 0) then
        B.MoveStrS(CurCol + 1, EmptyText, GetColor(1).Lo);
      B.MoveChar(CurCol + ColWidth - 1, $B3, GetColor(5).Lo, 1);
    end;
    WriteLineD(0, I, Size.X, 1, B);
  end;
  B.Done;
  if not FocusedVis then
    SetCursor(-1, -1);
end;

procedure TListViewer.FocusItem(Item: Integer);
begin
  Focused := Item;
  if VScrollBar <> nil then
    VScrollBar^.SetValue(Item)
  else
    DrawView;
  if Size.Y > 0 then
  begin
    if Item < TopItem then
    begin
      if NumCols = 1 then
        TopItem := Item
      else
        TopItem := Item - Item mod Size.Y;
    end
    else if Item >= TopItem + Size.Y * NumCols then
    begin
      if NumCols = 1 then
        TopItem := Item - Size.Y + 1
      else
        TopItem := Item - Item mod Size.Y - (Size.Y * (NumCols - 1));
    end;
  end;
end;

procedure TListViewer.FocusItemNum(Item: Integer);
begin
  if Item < 0 then
    Item := 0
  else if (Item >= Range) and (Range > 0) then
    Item := Range - 1;
  if Range <> 0 then
    FocusItem(Item);
end;

function TListViewer.GetPalette: TPalette;
begin
  Result := MakePalette(ListViewerPalette);
end;

function TListViewer.GetText(Item, MaxLen: Integer): ShortString;
begin
  Result := '';
end;

function TListViewer.IsSelected(Item: Integer): Boolean;
begin
  Result := Item = Focused;
end;

procedure TListViewer.HandleEvent(var Event: TEvent);
var
  Mouse: TPoint;
  ColWidth, OldItem, NewItem, Count: Integer;
begin
  inherited HandleEvent(Event);
  NewItem := 0;
  if Event.What = evMouseDown then
  begin
    ColWidth := Size.X div NumCols + 1;
    OldItem := Focused;
    Count := 0;
    repeat
      Mouse := MakeLocal(Event.Where);
      if MouseInView(Event.Where) then
        NewItem := Mouse.Y + (Size.Y * (Mouse.X div ColWidth)) + TopItem
      else if NumCols = 1 then
      begin
        if Event.What = evMouseAuto then
          Inc(Count);
        if Count = MouseAutosToSkip then
        begin
          Count := 0;
          if Mouse.Y < 0 then
            NewItem := Focused - 1
          else if Mouse.Y >= Size.Y then
            NewItem := Focused + 1;
        end;
      end
      else
      begin
        if Event.What = evMouseAuto then
          Inc(Count);
        if Count = MouseAutosToSkip then
        begin
          Count := 0;
          if Mouse.X < 0 then
            NewItem := Focused - Size.Y
          else if Mouse.X >= Size.X then
            NewItem := Focused + Size.Y
          else if Mouse.Y < 0 then
            NewItem := Focused - Focused mod Size.Y
          else if Mouse.Y > Size.Y then
            NewItem := Focused - Focused mod Size.Y + Size.Y - 1;
        end;
      end;
      if NewItem <> OldItem then
      begin
        FocusItemNum(NewItem);
        DrawView;
      end;
      OldItem := NewItem;
      if (Event.EventFlags and meDoubleClick) <> 0 then
        Break;
    until not MouseEvent(Event, evMouseMove or evMouseAuto);
    FocusItemNum(NewItem);
    DrawView;
    if ((Event.EventFlags and meDoubleClick) <> 0) and (Range > NewItem) then
      SelectItem(NewItem);
    ClearEvent(Event);
  end
  else if Event.What = evKeyDown then
  begin
    if (Event.CharCode = Ord(' ')) and (Focused < Range) then
    begin
      SelectItem(Focused);
      NewItem := Focused;
    end
    else
    begin
      case CtrlToArrow(Event.KeyCode) of
        kbUp: NewItem := Focused - 1;
        kbDown: NewItem := Focused + 1;
        kbRight:
          if NumCols > 1 then
            NewItem := Focused + Size.Y
          else
            Exit;
        kbLeft:
          if NumCols > 1 then
            NewItem := Focused - Size.Y
          else
            Exit;
        kbPgDn: NewItem := Focused + Size.Y * NumCols;
        kbPgUp: NewItem := Focused - Size.Y * NumCols;
        kbHome: NewItem := TopItem;
        kbEnd: NewItem := TopItem + (Size.Y * NumCols) - 1;
        kbCtrlPgDn: NewItem := Range - 1;
        kbCtrlPgUp: NewItem := 0;
      else
        Exit;
      end;
    end;
    FocusItemNum(NewItem);
    DrawView;
    ClearEvent(Event);
  end
  else if Event.What = evBroadcast then
  begin
    if (Options and ofSelectable) <> 0 then
    begin
      if (Event.Command = cmScrollBarClicked) and
        ((Event.InfoPtr = HScrollBar) or (Event.InfoPtr = VScrollBar)) then
        Select
      else if Event.Command = cmScrollBarChanged then
      begin
        if VScrollBar = Event.InfoPtr then
        begin
          FocusItemNum(VScrollBar^.Value);
          DrawView;
        end
        else if HScrollBar = Event.InfoPtr then
          DrawView;
      end;
    end;
  end;
end;

procedure TListViewer.SelectItem(Item: Integer);
begin
  Message(Owner, evBroadcast, cmListItemSelected, @Self);
end;

procedure TListViewer.SetRange(ARange: Integer);
begin
  Range := ARange;
  if Focused >= ARange then
    Focused := 0;
  if VScrollBar <> nil then
    VScrollBar^.SetParams(Focused, 0, ARange - 1, VScrollBar^.PgStep, VScrollBar^.ArStep)
  else
    DrawView;
end;

procedure TListViewer.SetState(AState: Word; Enable: Boolean);
begin
  inherited SetState(AState, Enable);
  if (AState and (sfSelected or sfActive or sfVisible)) <> 0 then
  begin
    if HScrollBar <> nil then
    begin
      if GetState(sfActive) and GetState(sfVisible) then
        HScrollBar^.Show
      else
        HScrollBar^.Hide;
    end;
    if VScrollBar <> nil then
    begin
      if GetState(sfActive) and GetState(sfVisible) then
        VScrollBar^.Show
      else
        VScrollBar^.Hide;
    end;
    DrawView;
  end;
end;

{ --- TListBox ---------------------------------------------------------------- }

constructor TListBox.Init(const Bounds: TRect; ANumCols: Integer; AScrollBar: PScrollBar);
begin
  inherited Init(Bounds, ANumCols, nil, AScrollBar);
  List := nil;
  SetRange(0);
end;

destructor TListBox.Done;
begin
  if List <> nil then
    Dispose(List, Done);
  List := nil;
  inherited Done;
end;

function TListBox.DataSize: Integer;
begin
  Result := SizeOf(TListBoxRec);
end;

procedure TListBox.GetData(var Rec);
begin
  TListBoxRec(Rec).List := List;
  TListBoxRec(Rec).Selection := Focused;
end;

function TListBox.GetText(Item, MaxLen: Integer): ShortString;
begin
  if List <> nil then
  begin
    Result := PStr(List^.At(Item))^;
    if Length(Result) > MaxLen then
      SetLength(Result, MaxLen);
  end
  else
    Result := '';
end;

procedure TListBox.NewList(AList: PCollection);
begin
  if List <> nil then
    Dispose(List, Done);
  List := AList;
  if AList <> nil then
    SetRange(AList^.Count)
  else
    SetRange(0);
  if Range > 0 then
    FocusItem(0);
  DrawView;
end;

procedure TListBox.SetData(var Rec);
begin
  NewList(TListBoxRec(Rec).List);
  FocusItem(TListBoxRec(Rec).Selection);
  DrawView;
end;

{ --- Streams ------------------------------------------------------------------ }

constructor TListViewer.Load(var S: TStream);
begin
  inherited Load(S);
  GetPeerViewPtr(S, HScrollBar);
  GetPeerViewPtr(S, VScrollBar);
  S.Read(NumCols, SizeOf(NumCols));
  S.Read(TopItem, SizeOf(TopItem));
  S.Read(Focused, SizeOf(Focused));
  S.Read(Range, SizeOf(Range));
end;

procedure TListViewer.Store(var S: TStream);
begin
  inherited Store(S);
  PutPeerViewPtr(S, HScrollBar);
  PutPeerViewPtr(S, VScrollBar);
  S.Write(NumCols, SizeOf(NumCols));
  S.Write(TopItem, SizeOf(TopItem));
  S.Write(Focused, SizeOf(Focused));
  S.Write(Range, SizeOf(Range));
end;

constructor TListBox.Load(var S: TStream);
begin
  inherited Load(S);
  List := PCollection(S.Get);
  if List <> nil then
    Range := List^.Count;
end;

procedure TListBox.Store(var S: TStream);
begin
  inherited Store(S);
  S.Put(List);
end;

function BuildListViewer(var S: TStream): PObject;
begin
  Result := New(PListViewer, Load(S));
end;

procedure StoreListViewer(P: PObject; var S: TStream);
begin
  PListViewer(P)^.Store(S);
end;

function BuildListBox(var S: TStream): PObject;
begin
  Result := New(PListBox, Load(S));
end;

procedure StoreListBox(P: PObject; var S: TStream);
begin
  PListBox(P)^.Store(S);
end;

initialization
  RListViewer.ObjType := 5;
  RListViewer.VmtLink := PtrUInt(TypeOf(TListViewer));
  RListViewer.Load := @BuildListViewer;
  RListViewer.Store := @StoreListViewer;
  RListBox.ObjType := 17;
  RListBox.VmtLink := PtrUInt(TypeOf(TListBox));
  RListBox.Load := @BuildListBox;
  RListBox.Store := @StoreListBox;

end.
