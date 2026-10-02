{ TvColorSel: the dialog that edits a palette: TColorDialog with TColorSelector, TMonoSelector,
  TColorDisplay, TColorGroupList, TColorItemList, and the lists of groups and items
  (ColorItem, ColorGroup).

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/colorsel.h (class declarations, commands)
    source/tvision/colorsel.cpp, tvtext1.cpp (texts)
  Borland disclaimer and MIT notice: tv/COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/DESIGN.md):
    - the lists are built with ColorItem and ColorGroup (instead of operator+);
      the dialog takes them over and frees them;
    - the palette is a TPalette (a dynamic array, element 0 is the size); the data of the
      dialog is a TPalette: GetData gives a copy, SetData takes a copy;
    - the colors of the palette are TColorAttr, they are edited as BIOS colors (16 colors);
    - the remembered indexes of the groups are in ColorIndexes (FreeColorIndexes frees them);
    - streams are not translated yet. }
unit TvColorSel;

{$I tvdefs.inc}

interface

uses
  TvGeom, TvColors, TvCell, TvKeys, TvEvents, TvText, TvDrawBuf, TvObjs, TvUtil, TvViews,
  TvDialog, TvWindow, TvList, TvCluster;

const
  cmColorForegroundChanged = 71;
  cmColorBackgroundChanged = 72;
  cmColorSet               = 73;
  cmNewColorItem           = 74;
  cmNewColorIndex          = 75;
  cmSaveColorIndex         = 76;

  ColorsTitle = 'Colors';
  GroupText = '~G~roup';
  ItemText = '~I~tem';
  ForText = '~F~oreground';
  BakText = '~B~ackground';
  TextText = 'Text ';
  ColorText = 'Color';
  NormalText = 'Normal';
  HighlightText = 'Highlight';
  UnderlineText = 'Underline';
  InverseText = 'Inverse';
  ColorOKText = 'O~K~';
  ColorCancelText = 'Cancel';

type
  TColorSel = (csBackground, csForeground);

  PColorItem = ^TColorItem;
  TColorItem = record
    Name: PStr;
    Index: Byte;
    Next: PColorItem;
  end;

  PColorGroup = ^TColorGroup;
  TColorGroup = record
    Name: PStr;
    Index: Byte;
    Items: PColorItem;
    Next: PColorGroup;
  end;

  { what the dialog remembers of the last choice: the group and the item of every group }
  PColorIndex = ^TColorIndex;
  TColorIndex = record
    GroupIndex: Byte;
    ColorSize: Byte;
    ColorIndex: array[0..255] of Byte;
  end;

  PColorSelector = ^TColorSelector;
  TColorSelector = object(TView)
    Color: Byte;
    SelType: TColorSel;
    constructor Init(const Bounds: TRect; ASelType: TColorSel);
    procedure Draw; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
  private
    procedure ColorChanged;
  end;

  PMonoSelector = ^TMonoSelector;
  TMonoSelector = object(TCluster)
    constructor Init(const Bounds: TRect);
    procedure Draw; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    function Mark(Item: Integer): Boolean; virtual;
    procedure MovedTo(Item: Integer); virtual;
    procedure Press(Item: Integer); virtual;
  private
    procedure NewColor;
  end;

  PColorDisplay = ^TColorDisplay;
  TColorDisplay = object(TView)
    Color: PColorAttr;
    Text: PStr;
    constructor Init(const Bounds: TRect; const AText: ShortString);
    destructor Done; virtual;
    procedure Draw; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure SetColor(AColor: PColorAttr);
  end;

  PColorGroupList = ^TColorGroupList;
  TColorGroupList = object(TListViewer)
    Groups: PColorGroup;
    constructor Init(const Bounds: TRect; AScrollBar: PScrollBar; AGroups: PColorGroup);
    destructor Done; virtual;
    procedure FocusItem(Item: Integer); virtual;
    function GetText(Item, MaxLen: Integer): ShortString; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure SetGroupIndex(GroupNum, ItemNum: Byte);
    function GetGroupIndex(GroupNum: Byte): Byte;
    function GetGroup(GroupNum: Byte): PColorGroup;
    function GetNumGroups: Byte;
  end;

  PColorItemList = ^TColorItemList;
  TColorItemList = object(TListViewer)
    Items: PColorItem;
    constructor Init(const Bounds: TRect; AScrollBar: PScrollBar; AItems: PColorItem);
    procedure FocusItem(Item: Integer); virtual;
    function GetText(Item, MaxLen: Integer): ShortString; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
  end;

  PColorDialog = ^TColorDialog;
  TColorDialog = object(TDialog)
    Pal: TPalette;
    Display: PColorDisplay;
    Groups: PColorGroupList;
    ForLabel: PLabel;
    ForSel: PColorSelector;
    BakLabel: PLabel;
    BakSel: PColorSelector;
    MonoLabel: PLabel;
    MonoSel: PMonoSelector;
    GroupIndex: Byte;
    constructor Init(const APalette: TPalette; AGroups: PColorGroup);
    destructor Done; virtual;
    function DataSize: Integer; virtual;
    procedure GetData(var Rec); virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure SetData(var Rec); virtual;
  private
    procedure SetIndexes;
    procedure GetIndexes;
  end;

var
  { the indexes remembered between the uses of the dialog }
  ColorIndexes: PColorIndex = nil;

function ColorItem(const Name: ShortString; Index: Byte; Next: PColorItem): PColorItem;
function ColorGroup(const Name: ShortString; Items: PColorItem; Next: PColorGroup): PColorGroup;
{ appends the items to the last group of the list }
function ColorGroupItems(Group: PColorGroup; Items: PColorItem): PColorGroup;
procedure FreeColorIndexes;

const
  { the black and white attributes of the monochrome selector (also used by DN's T_BWSelector) }
  MonoColors: array[0..4] of Byte = ($07, $0F, $01, $70, $09);

implementation

const
  ColorSelIcon = $DB;

{ --- ColorItem, ColorGroup ----------------------------------------------------- }

function ColorItem(const Name: ShortString; Index: Byte; Next: PColorItem): PColorItem;
begin
  New(Result);
  Result^.Name := NewStr(Name);
  Result^.Index := Index;
  Result^.Next := Next;
end;

function ColorGroup(const Name: ShortString; Items: PColorItem; Next: PColorGroup): PColorGroup;
begin
  New(Result);
  Result^.Name := NewStr(Name);
  Result^.Index := 0;
  Result^.Items := Items;
  Result^.Next := Next;
end;

function ColorGroupItems(Group: PColorGroup; Items: PColorItem): PColorGroup;
var
  G: PColorGroup;
  I: PColorItem;
begin
  Result := Group;
  G := Group;
  while G^.Next <> nil do
    G := G^.Next;
  if G^.Items = nil then
    G^.Items := Items
  else
  begin
    I := G^.Items;
    while I^.Next <> nil do
      I := I^.Next;
    I^.Next := Items;
  end;
end;

procedure FreeItems(Cur: PColorItem);
var
  P: PColorItem;
begin
  while Cur <> nil do
  begin
    P := Cur;
    Cur := Cur^.Next;
    DisposeStr(P^.Name);
    Dispose(P);
  end;
end;

procedure FreeGroups(Cur: PColorGroup);
var
  P: PColorGroup;
begin
  while Cur <> nil do
  begin
    P := Cur;
    FreeItems(Cur^.Items);
    Cur := Cur^.Next;
    DisposeStr(P^.Name);
    Dispose(P);
  end;
end;

procedure FreeColorIndexes;
begin
  if ColorIndexes <> nil then
    Dispose(ColorIndexes);
  ColorIndexes := nil;
end;

{ --- TColorSelector ------------------------------------------------------------ }

constructor TColorSelector.Init(const Bounds: TRect; ASelType: TColorSel);
begin
  inherited Init(Bounds);
  Options := Options or (ofSelectable or ofFirstClick or ofFramed);
  EventMask := EventMask or evBroadcast;
  SelType := ASelType;
  Color := 0;
end;

procedure TColorSelector.Draw;
var
  B: TDrawBuffer;
  I, J, C: Integer;
begin
  B.Init(Size.X);
  B.MoveChar(0, Ord(' '), AttrFromBIOS($70), Size.X);
  for I := 0 to Size.Y do
  begin
    if I < 4 then
    begin
      for J := 0 to 3 do
      begin
        C := I * 4 + J;
        B.MoveChar(J * 3, ColorSelIcon, AttrFromBIOS(C), 3);
        if C = Color then
        begin
          B.PutChar(J * 3 + 1, 8);
          if C = 0 then
            B.PutAttribute(J * 3 + 1, AttrFromBIOS($70));
        end;
      end;
    end;
    WriteLineD(0, I, Size.X, 1, B);
  end;
  B.Done;
end;

procedure TColorSelector.ColorChanged;
var
  Msg: Word;
begin
  if SelType = csForeground then
    Msg := cmColorForegroundChanged
  else
    Msg := cmColorBackgroundChanged;
  Message(Owner, evBroadcast, Msg, Pointer(PtrUInt(Color)));
end;

procedure TColorSelector.HandleEvent(var Event: TEvent);
const
  Width = 4;
var
  OldColor: Byte;
  MaxCol: Integer;
  Mouse: TPoint;
begin
  inherited HandleEvent(Event);
  OldColor := Color;
  if SelType = csBackground then
    MaxCol := 7
  else
    MaxCol := 15;
  case Event.What of
    evMouseDown:
      repeat
        if MouseInView(Event.Where) then
        begin
          Mouse := MakeLocal(Event.Where);
          Color := Mouse.Y * 4 + Mouse.X div 3;
        end
        else
          Color := OldColor;
        ColorChanged;
        DrawView;
      until not MouseEvent(Event, evMouseMove);
    evKeyDown:
      case CtrlToArrow(Event.KeyCode) of
        kbLeft:
          if Color > 0 then
            Dec(Color)
          else
            Color := MaxCol;
        kbRight:
          if Color < MaxCol then
            Inc(Color)
          else
            Color := 0;
        kbUp:
          if Color > Width - 1 then
            Dec(Color, Width)
          else if Color = 0 then
            Color := MaxCol
          else
            Inc(Color, MaxCol - Width);
        kbDown:
          if Color < MaxCol - (Width - 1) then
            Inc(Color, Width)
          else if Color = MaxCol then
            Color := 0
          else
            Dec(Color, MaxCol - Width);
      else
        Exit;
      end;
    evBroadcast:
      begin
        if Event.Command = cmColorSet then
        begin
          if SelType = csBackground then
            Color := Event.InfoByte shr 4
          else
            Color := Event.InfoByte and $0F;
          DrawView;
        end;
        Exit;
      end;
  else
    Exit;
  end;
  DrawView;
  ColorChanged;
  ClearEvent(Event);
end;

{ --- TMonoSelector ------------------------------------------------------------- }

constructor TMonoSelector.Init(const Bounds: TRect);
begin
  inherited Init(Bounds, NewSItem(NormalText, NewSItem(HighlightText,
    NewSItem(UnderlineText, NewSItem(InverseText, nil)))));
  EventMask := EventMask or evBroadcast;
end;

procedure TMonoSelector.Draw;
begin
  DrawBox(' ( ) ', #$07);
end;

procedure TMonoSelector.HandleEvent(var Event: TEvent);
begin
  inherited HandleEvent(Event);
  if (Event.What = evBroadcast) and (Event.Command = cmColorSet) then
  begin
    Value := Event.InfoByte;
    DrawView;
  end;
end;

function TMonoSelector.Mark(Item: Integer): Boolean;
begin
  Result := MonoColors[Item] = Value;
end;

procedure TMonoSelector.NewColor;
begin
  Message(Owner, evBroadcast, cmColorForegroundChanged, Pointer(PtrUInt(Value and $0F)));
  Message(Owner, evBroadcast, cmColorBackgroundChanged, Pointer(PtrUInt((Value shr 4) and $0F)));
end;

procedure TMonoSelector.Press(Item: Integer);
begin
  Value := MonoColors[Item];
  NewColor;
end;

procedure TMonoSelector.MovedTo(Item: Integer);
begin
  Value := MonoColors[Item];
  NewColor;
end;

{ --- TColorDisplay ------------------------------------------------------------- }

constructor TColorDisplay.Init(const Bounds: TRect; const AText: ShortString);
begin
  inherited Init(Bounds);
  Color := nil;
  Text := NewStr(AText);
  EventMask := EventMask or evBroadcast;
end;

destructor TColorDisplay.Done;
begin
  DisposeStr(Text);
  Text := nil;
  inherited Done;
end;

procedure TColorDisplay.Draw;
var
  C: TColorAttr;
  B: TDrawBuffer;
  Len, I: Integer;
begin
  if Color = nil then
    Exit;
  C := Color^;
  { BIOS color 0 has a special meaning in TDrawBuffer functions, so it is shown as an
    invalid color }
  if AttrToBIOS(C) = 0 then
    C := ErrorAttr;
  Len := TextWidthS(Text^);
  if Len < 1 then
    Len := 1;
  B.Init(Size.X);
  for I := 0 to Size.X div Len do
    B.MoveStrS(I * Len, Text^, C);
  WriteLineD(0, 0, Size.X, Size.Y, B);
  B.Done;
end;

procedure TColorDisplay.HandleEvent(var Event: TEvent);
var
  Bios: Byte;
begin
  inherited HandleEvent(Event);
  if (Event.What = evBroadcast) and (Color <> nil) then
    case Event.Command of
      cmColorBackgroundChanged:
        begin
          Bios := (AttrToBIOS(Color^) and $0F) or ((Event.InfoByte shl 4) and $F0);
          Color^ := AttrFromBIOS(Bios);
          DrawView;
        end;
      cmColorForegroundChanged:
        begin
          Bios := (AttrToBIOS(Color^) and $F0) or (Event.InfoByte and $0F);
          Color^ := AttrFromBIOS(Bios);
          DrawView;
        end;
    end;
end;

procedure TColorDisplay.SetColor(AColor: PColorAttr);
begin
  Color := AColor;
  Message(Owner, evBroadcast, cmColorSet, Pointer(PtrUInt(AttrToBIOS(Color^))));
  DrawView;
end;

{ --- TColorGroupList ----------------------------------------------------------- }

constructor TColorGroupList.Init(const Bounds: TRect; AScrollBar: PScrollBar;
  AGroups: PColorGroup);
var
  I: Integer;
  G: PColorGroup;
begin
  inherited Init(Bounds, 1, nil, AScrollBar);
  Groups := AGroups;
  I := 0;
  G := AGroups;
  while G <> nil do
  begin
    G := G^.Next;
    Inc(I);
  end;
  SetRange(I);
end;

destructor TColorGroupList.Done;
begin
  FreeGroups(Groups);
  Groups := nil;
  inherited Done;
end;

function TColorGroupList.GetGroup(GroupNum: Byte): PColorGroup;
begin
  Result := Groups;
  while (Result <> nil) and (GroupNum > 0) do
  begin
    Result := Result^.Next;
    Dec(GroupNum);
  end;
end;

procedure TColorGroupList.FocusItem(Item: Integer);
var
  G: PColorGroup;
begin
  inherited FocusItem(Item);
  G := Groups;
  while (G <> nil) and (Item > 0) do
  begin
    G := G^.Next;
    Dec(Item);
  end;
  if G <> nil then
    Message(Owner, evBroadcast, cmNewColorItem, G);
end;

function TColorGroupList.GetText(Item, MaxLen: Integer): ShortString;
var
  G: PColorGroup;
begin
  G := GetGroup(Item);
  if G <> nil then
  begin
    Result := G^.Name^;
    if Length(Result) > MaxLen then
      SetLength(Result, MaxLen);
  end
  else
    Result := '';
end;

procedure TColorGroupList.HandleEvent(var Event: TEvent);
begin
  inherited HandleEvent(Event);
  if (Event.What = evBroadcast) and (Event.Command = cmSaveColorIndex) then
    SetGroupIndex(Focused, Event.InfoByte);
end;

procedure TColorGroupList.SetGroupIndex(GroupNum, ItemNum: Byte);
var
  G: PColorGroup;
  Index: Byte;
  Cur: PColorItem;
begin
  G := GetGroup(GroupNum);
  if G <> nil then
  begin
    Index := 0;
    Cur := G^.Items;
    if Cur <> nil then
      while Index < ItemNum do
      begin
        Cur := Cur^.Next;
        if Cur = nil then
          Break;
        Inc(Index);
      end;
    G^.Index := Index;
  end;
end;

function TColorGroupList.GetGroupIndex(GroupNum: Byte): Byte;
var
  G: PColorGroup;
begin
  G := GetGroup(GroupNum);
  if G <> nil then
    Result := G^.Index
  else
    Result := 0;
end;

function TColorGroupList.GetNumGroups: Byte;
var
  G: PColorGroup;
begin
  Result := 0;
  G := Groups;
  while G <> nil do
  begin
    Inc(Result);
    G := G^.Next;
  end;
end;

{ --- TColorItemList ------------------------------------------------------------ }

constructor TColorItemList.Init(const Bounds: TRect; AScrollBar: PScrollBar;
  AItems: PColorItem);
var
  I: Integer;
  P: PColorItem;
begin
  inherited Init(Bounds, 1, nil, AScrollBar);
  Items := AItems;
  EventMask := EventMask or evBroadcast;
  I := 0;
  P := AItems;
  while P <> nil do
  begin
    P := P^.Next;
    Inc(I);
  end;
  SetRange(I);
end;

procedure TColorItemList.FocusItem(Item: Integer);
var
  Cur: PColorItem;
  N: Integer;
begin
  inherited FocusItem(Item);
  Message(Owner, evBroadcast, cmSaveColorIndex, Pointer(PtrUInt(Item)));
  Cur := Items;
  N := Item;
  while (Cur <> nil) and (N > 0) do
  begin
    Cur := Cur^.Next;
    Dec(N);
  end;
  if Cur <> nil then
    Message(Owner, evBroadcast, cmNewColorIndex, Pointer(PtrUInt(Cur^.Index)));
end;

function TColorItemList.GetText(Item, MaxLen: Integer): ShortString;
var
  Cur: PColorItem;
begin
  Cur := Items;
  while (Cur <> nil) and (Item > 0) do
  begin
    Cur := Cur^.Next;
    Dec(Item);
  end;
  if Cur <> nil then
  begin
    Result := Cur^.Name^;
    if Length(Result) > MaxLen then
      SetLength(Result, MaxLen);
  end
  else
    Result := '';
end;

procedure TColorItemList.HandleEvent(var Event: TEvent);
var
  G: PColorGroup;
  Cur: PColorItem;
  I: Integer;
begin
  inherited HandleEvent(Event);
  if (Event.What = evBroadcast) and (Event.Command = cmNewColorItem) then
  begin
    G := PColorGroup(Event.InfoPtr);
    Items := G^.Items;
    Cur := Items;
    I := 0;
    while Cur <> nil do
    begin
      Cur := Cur^.Next;
      Inc(I);
    end;
    SetRange(I);
    FocusItem(G^.Index);
    DrawView;
  end;
end;

{ --- TColorDialog -------------------------------------------------------------- }

constructor TColorDialog.Init(const APalette: TPalette; AGroups: PColorGroup);
var
  R: TRect;
  SB: PScrollBar;
  Lbl: PLabel;
  P: PView;
  Btn: PButton;
begin
  R.Assign(0, 0, 61, 18);
  inherited Init(R, ColorsTitle);
  Options := Options or ofCentered;
  if Length(APalette) > 0 then
    Pal := Copy(APalette)
  else
    Pal := nil;

  R.Assign(18, 3, 19, 14);
  New(SB, Init(R));
  Insert(SB);
  R.Assign(3, 3, 18, 14);
  New(Groups, Init(R, SB, AGroups));
  Insert(Groups);
  R.Assign(2, 2, 8, 3);
  New(Lbl, Init(R, GroupText, Groups));
  Insert(Lbl);

  R.Assign(41, 3, 42, 14);
  New(SB, Init(R));
  Insert(SB);
  R.Assign(21, 3, 41, 14);
  New(PColorItemList(P), Init(R, SB, AGroups^.Items));
  Insert(P);
  R.Assign(20, 2, 25, 3);
  New(Lbl, Init(R, ItemText, P));
  Insert(Lbl);

  R.Assign(45, 3, 57, 7);
  New(ForSel, Init(R, csForeground));
  Insert(ForSel);
  R.Assign(45, 2, 57, 3);
  New(ForLabel, Init(R, ForText, ForSel));
  Insert(ForLabel);

  R.Assign(45, 9, 57, 11);
  New(BakSel, Init(R, csBackground));
  Insert(BakSel);
  R.Assign(45, 8, 57, 9);
  New(BakLabel, Init(R, BakText, BakSel));
  Insert(BakLabel);

  R.Assign(44, 12, 58, 14);
  New(Display, Init(R, TextText));
  Insert(Display);

  R.Assign(44, 3, 59, 7);
  New(MonoSel, Init(R));
  MonoSel^.Hide;
  Insert(MonoSel);
  R.Assign(43, 2, 49, 3);
  New(MonoLabel, Init(R, ColorText, MonoSel));
  MonoLabel^.Hide;
  Insert(MonoLabel);

  R.Assign(36, 15, 46, 17);
  New(Btn, Init(R, ColorOKText, cmOK, bfDefault));
  Insert(Btn);
  R.Assign(48, 15, 58, 17);
  New(Btn, Init(R, ColorCancelText, cmCancel, bfNormal));
  Insert(Btn);
  SelectNext(False);

  GroupIndex := 0;
  if Length(Pal) > 0 then
    SetData(Pal);
end;

destructor TColorDialog.Done;
begin
  Pal := nil;
  inherited Done;
end;

procedure TColorDialog.HandleEvent(var Event: TEvent);
begin
  if (Event.What = evBroadcast) and (Event.Command = cmNewColorItem) then
    GroupIndex := Groups^.Focused;
  inherited HandleEvent(Event);
  if (Event.What = evBroadcast) and (Event.Command = cmNewColorIndex) and
    (Event.InfoByte < Length(Pal)) then
    Display^.SetColor(@Pal[Event.InfoByte]);
end;

function TColorDialog.DataSize: Integer;
begin
  Result := SizeOf(TPalette);
end;

procedure TColorDialog.GetData(var Rec);
begin
  GetIndexes;
  TPalette(Rec) := Copy(Pal);
end;

procedure TColorDialog.SetData(var Rec);
begin
  Pal := Copy(TPalette(Rec));
  SetIndexes;
  { the original takes the index of the item in the group as the index of the palette }
  if Groups^.GetGroupIndex(GroupIndex) < Length(Pal) then
    Display^.SetColor(@Pal[Groups^.GetGroupIndex(GroupIndex)]);
  Groups^.FocusItem(GroupIndex);
  if ShowMarkers then
  begin
    ForLabel^.Hide;
    ForSel^.Hide;
    BakLabel^.Hide;
    BakSel^.Hide;
    MonoLabel^.Show;
    MonoSel^.Show;
  end;
  Groups^.Select;
end;

procedure TColorDialog.SetIndexes;
var
  NumGroups, Index: Byte;
begin
  NumGroups := Groups^.GetNumGroups;
  if (ColorIndexes <> nil) and (ColorIndexes^.ColorSize <> NumGroups) then
    FreeColorIndexes;
  if ColorIndexes = nil then
  begin
    New(ColorIndexes);
    FillChar(ColorIndexes^, SizeOf(TColorIndex), 0);
    ColorIndexes^.ColorSize := NumGroups;
  end;
  for Index := 0 to NumGroups - 1 do
    Groups^.SetGroupIndex(Index, ColorIndexes^.ColorIndex[Index]);
  GroupIndex := ColorIndexes^.GroupIndex;
end;

procedure TColorDialog.GetIndexes;
var
  N, Index: Byte;
begin
  N := Groups^.GetNumGroups;
  if ColorIndexes = nil then
  begin
    New(ColorIndexes);
    FillChar(ColorIndexes^, SizeOf(TColorIndex), 0);
    ColorIndexes^.ColorSize := N;
  end;
  ColorIndexes^.GroupIndex := GroupIndex;
  for Index := 0 to N - 1 do
    ColorIndexes^.ColorIndex[Index] := Groups^.GetGroupIndex(Index);
end;

end.
