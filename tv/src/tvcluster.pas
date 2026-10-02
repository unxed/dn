{ TvCluster: groups of check boxes and radio buttons: TCluster, TRadioButtons, TCheckBoxes,
  TMultiCheckBoxes, TSItem (the list of the item texts).

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/dialogs.h (class declarations)
    source/tvision/tcluster.cpp, tradiobu.cpp, tcheckbo.cpp, tmulchkb.cpp
  Borland disclaimer and MIT notice: tv/COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/DESIGN.md):
    - the texts are ShortStrings; the list of them is built with NewSItem (instead of
      the operator+ of TSItem), the cluster takes it over and frees it;
    - streams are not translated yet;
    - the data of TCluster is a Word, the one of TMultiCheckBoxes is a LongWord, as in the
      original (DataSize). }
unit TvCluster;

{$I tvdefs.inc}

interface

uses
  TvGeom, TvColors, TvCell, TvKeys, TvEvents, TvDrawBuf, TvObjs, TvUtil, TvViews,
  TvDialog;

type
  PSItem = ^TSItem;
  TSItem = record
    Value: PStr;
    Next: PSItem;
  end;

  { Palette: 1 = normal text, 2 = selected text, 3 = normal shortcut, 4 = selected
    shortcut, 5 = disabled text }
  PCluster = ^TCluster;
  TCluster = object(TView)
    Value: LongWord;
    EnableMask: LongWord;
    Sel: Integer;
    Strings: PStringCollection;
    constructor Init(const Bounds: TRect; AStrings: PSItem);
    constructor Load(var S: TStream);
    procedure Store(var S: TStream);
    destructor Done; virtual;
    function DataSize: Integer; virtual;
    procedure DrawBox(const Icon: ShortString; Marker: Char);
    procedure DrawMultiBox(const Icon, Marker: ShortString);
    procedure GetData(var Rec); virtual;
    function GetHelpCtx: Word; virtual;
    function GetPalette: TPalette; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    function Mark(Item: Integer): Boolean; virtual;
    function MultiMark(Item: Integer): Byte; virtual;
    procedure Press(Item: Integer); virtual;
    procedure MovedTo(Item: Integer); virtual;
    procedure SetData(var Rec); virtual;
    procedure SetState(AState: Word; Enable: Boolean); virtual;
    procedure SetButtonState(AMask: LongWord; Enable: Boolean); virtual;
    function ButtonState(Item: Integer): Boolean;
    function Column(Item: Integer): Integer;
    function FindSel(P: TPoint): Integer;
    function Row(Item: Integer): Integer;
  private
    procedure MoveSel(I, S: Integer);
  end;

  PRadioButtons = ^TRadioButtons;
  TRadioButtons = object(TCluster)
    constructor Load(var S: TStream);
    procedure Draw; virtual;
    function Mark(Item: Integer): Boolean; virtual;
    procedure MovedTo(Item: Integer); virtual;
    procedure Press(Item: Integer); virtual;
    procedure SetData(var Rec); virtual;
  end;

  PCheckBoxes = ^TCheckBoxes;
  TCheckBoxes = object(TCluster)
    constructor Load(var S: TStream);
    procedure Draw; virtual;
    function Mark(Item: Integer): Boolean; virtual;
    procedure Press(Item: Integer); virtual;
  end;

  { States: the characters shown for the states 0..SelRange-1; Flags: low byte is the mask
    of the bits of one item, high byte is the number of bits per item. }
  PMultiCheckBoxes = ^TMultiCheckBoxes;
  TMultiCheckBoxes = object(TCluster)
    SelRange: Byte;
    Flags: Word;
    States: PStr;
    constructor Init(const Bounds: TRect; AStrings: PSItem; ASelRange: Byte; AFlags: Word;
      const AStates: ShortString);
    constructor Load(var S: TStream);
    procedure Store(var S: TStream);
    destructor Done; virtual;
    function DataSize: Integer; virtual;
    procedure Draw; virtual;
    procedure GetData(var Rec); virtual;
    function MultiMark(Item: Integer): Byte; virtual;
    procedure Press(Item: Integer); virtual;
    procedure SetData(var Rec); virtual;
  end;

function NewSItem(const Str: ShortString; ANext: PSItem): PSItem;

const
  ClusterPalette = #$10#$11#$12#$12#$1F;

var
  { stream records (see RView of TvViews) }
  RCluster, RRadioButtons, RCheckBoxes, RMultiCheckBoxes: TStreamRec;

implementation

function NewSItem(const Str: ShortString; ANext: PSItem): PSItem;
begin
  New(Result);
  Result^.Value := NewStr(Str);
  Result^.Next := ANext;
end;

{ --- TCluster ---------------------------------------------------------------- }

constructor TCluster.Init(const Bounds: TRect; AStrings: PSItem);
var
  I: Integer;
  P: PSItem;
begin
  inherited Init(Bounds);
  Value := 0;
  Sel := 0;
  Options := Options or (ofSelectable or ofFirstClick or ofPreProcess or ofPostProcess);
  I := 0;
  P := AStrings;
  while P <> nil do
  begin
    Inc(I);
    P := P^.Next;
  end;
  New(Strings, Init(I, 0));
  while AStrings <> nil do
  begin
    P := AStrings;
    Strings^.AtInsert(Strings^.Count, P^.Value);   { the collection owns the text now }
    AStrings := AStrings^.Next;
    Dispose(P);
  end;
  SetCursor(2, 0);
  ShowCursor;
  EnableMask := $FFFFFFFF;
end;

destructor TCluster.Done;
begin
  if Strings <> nil then
    Dispose(Strings, Done);
  Strings := nil;
  inherited Done;
end;

function TCluster.DataSize: Integer;
begin
  { the value is a LongWord, but the data is a Word, as in the original;
    TMultiCheckBoxes gives the size of a LongWord }
  Result := SizeOf(Word);
end;

procedure TCluster.DrawBox(const Icon: ShortString; Marker: Char);
var
  S: ShortString;
begin
  S := ' ' + Marker;
  DrawMultiBox(Icon, S);
end;

procedure TCluster.DrawMultiBox(const Icon, Marker: ShortString);
var
  B: TDrawBuffer;
  Color, CNorm, CSel, CDis: TAttrPair;
  I, J, Cur, Col, M: Integer;
begin
  CNorm := GetColor($0301);
  CSel := GetColor($0402);
  CDis := GetColor($0505);
  B.Init(Size.X);
  for I := 0 to Size.Y - 1 do
  begin
    B.MoveChar(0, Ord(' '), CNorm.Lo, Size.X);
    for J := 0 to (Strings^.Count - 1) div Size.Y + 1 do
    begin
      Cur := J * Size.Y + I;
      if Cur < Strings^.Count then
      begin
        Col := Column(Cur);
        if Col < Size.X then
        begin
          if not ButtonState(Cur) then
            Color := CDis
          else if (Cur = Sel) and ((State and sfSelected) <> 0) then
            Color := CSel
          else
            Color := CNorm;
          B.MoveChar(Col, Ord(' '), Color.Lo, Size.X - Col);
          B.MoveCStrS(Col, Icon, Color);
          M := MultiMark(Cur);
          if M < Length(Marker) then
            B.PutChar(Col + 2, Ord(Marker[M + 1]));
          B.MoveCStrS(Col + 5, PStr(Strings^.At(Cur))^, Color);
          if ShowMarkers and ((State and sfSelected) <> 0) and (Cur = Sel) then
          begin
            B.PutChar(Col, SpecialChars[0]);
            B.PutChar(Column(Cur + Size.Y) - 1, SpecialChars[1]);
          end;
        end;
      end;
    end;
    WriteBufD(0, I, Size.X, 1, B);
  end;
  B.Done;
  SetCursor(Column(Sel) + 2, Row(Sel));
end;

procedure TCluster.GetData(var Rec);
begin
  Word(Rec) := Word(Value);
  DrawView;
end;

function TCluster.GetHelpCtx: Word;
begin
  if HelpCtx = hcNoContext then
    Result := hcNoContext
  else
    Result := HelpCtx + Sel;
end;

function TCluster.GetPalette: TPalette;
begin
  Result := MakePalette(ClusterPalette);
end;

procedure TCluster.MoveSel(I, S: Integer);
begin
  if I <= Strings^.Count then
  begin
    Sel := S;
    MovedTo(Sel);
    DrawView;
  end;
end;

procedure TCluster.HandleEvent(var Event: TEvent);
var
  Mouse: TPoint;
  I, S, N: Integer;
  C: Char;
begin
  inherited HandleEvent(Event);
  if (Options and ofSelectable) = 0 then
    Exit;
  N := Strings^.Count;
  if Event.What = evMouseDown then
  begin
    Mouse := MakeLocal(Event.Where);
    I := FindSel(Mouse);
    if (I <> -1) and ButtonState(I) then
      Sel := I;
    DrawView;
    repeat
      Mouse := MakeLocal(Event.Where);
      if (FindSel(Mouse) = Sel) and ButtonState(Sel) then
        ShowCursor
      else
        HideCursor;
    until not MouseEvent(Event, evMouseMove);
    ShowCursor;
    Mouse := MakeLocal(Event.Where);
    if FindSel(Mouse) = Sel then
    begin
      Press(Sel);
      DrawView;
    end;
    ClearEvent(Event);
  end
  else if Event.What = evKeyDown then
  begin
    S := Sel;
    case CtrlToArrow(Event.KeyCode) of
      kbUp:
        if (State and sfFocused) <> 0 then
        begin
          I := 0;
          repeat
            Inc(I);
            Dec(S);
            if S < 0 then
              S := N - 1;
          until ButtonState(S) or (I > N);
          MoveSel(I, S);
          ClearEvent(Event);
        end;
      kbDown:
        if (State and sfFocused) <> 0 then
        begin
          I := 0;
          repeat
            Inc(I);
            Inc(S);
            if S >= N then
              S := 0;
          until ButtonState(S) or (I > N);
          MoveSel(I, S);
          ClearEvent(Event);
        end;
      kbRight:
        if (State and sfFocused) <> 0 then
        begin
          I := 0;
          repeat
            Inc(I);
            Inc(S, Size.Y);
            if S >= N then
              S := 0;
          until ButtonState(S) or (I > N);
          MoveSel(I, S);
          ClearEvent(Event);
        end;
      kbLeft:
        if (State and sfFocused) <> 0 then
        begin
          I := 0;
          repeat
            Inc(I);
            if S > 0 then
            begin
              Dec(S, Size.Y);
              if S < 0 then
              begin
                S := ((N + Size.Y - 1) div Size.Y) * Size.Y + S - 1;
                if S >= N then
                  S := N - 1;
              end;
            end
            else
              S := N - 1;
          until ButtonState(S) or (I > N);
          MoveSel(I, S);
          ClearEvent(Event);
        end;
    else
      begin
        for I := 0 to N - 1 do
        begin
          C := HotKey(PStr(Strings^.At(I))^);
          if (Event.KeyCode <> 0) and
            ((GetAltCode(C) = Event.KeyCode) or
             (((Owner <> nil) and (Owner^.Phase = phPostProcess)) or ((State and sfFocused) <> 0)) and
             (C <> #0) and (C = UpCase(Chr(Event.CharCode)))) then
          begin
            if ButtonState(I) then
            begin
              if Focus then
              begin
                Sel := I;
                MovedTo(Sel);
                Press(Sel);
                DrawView;
              end;
              ClearEvent(Event);
            end;
            Exit;
          end;
        end;
        if (Event.CharCode = Ord(' ')) and ((State and sfFocused) <> 0) then
        begin
          Press(Sel);
          DrawView;
          ClearEvent(Event);
        end;
      end;
    end;
  end;
end;

procedure TCluster.SetButtonState(AMask: LongWord; Enable: Boolean);
var
  N: Integer;
  TestMask: LongWord;
begin
  if not Enable then
    EnableMask := EnableMask and not AMask
  else
    EnableMask := EnableMask or AMask;
  N := Strings^.Count;
  if N < 32 then
  begin
    TestMask := (LongWord(1) shl N) - 1;
    if (EnableMask and TestMask) <> 0 then
      Options := Options or ofSelectable
    else
      Options := Options and not ofSelectable;
  end;
end;

procedure TCluster.SetData(var Rec);
begin
  Value := Word(Rec);
  DrawView;
end;

procedure TCluster.SetState(AState: Word; Enable: Boolean);
begin
  inherited SetState(AState, Enable);
  if AState = sfSelected then
    DrawView;
end;

function TCluster.Mark(Item: Integer): Boolean;
begin
  Result := False;
end;

function TCluster.MultiMark(Item: Integer): Byte;
begin
  if Mark(Item) then
    Result := 1
  else
    Result := 0;
end;

procedure TCluster.MovedTo(Item: Integer);
begin
end;

procedure TCluster.Press(Item: Integer);
begin
end;

function TCluster.Column(Item: Integer): Integer;
var
  Width, Col, L, I: Integer;
begin
  if Item < Size.Y then
    Result := 0
  else
  begin
    Width := 0;
    Col := -6;
    L := 0;
    for I := 0 to Item do
    begin
      if I mod Size.Y = 0 then
      begin
        Inc(Col, Width + 6);
        Width := 0;
      end;
      if I < Strings^.Count then
        L := CStrLen(PStr(Strings^.At(I))^);
      if L > Width then
        Width := L;
    end;
    Result := Col;
  end;
end;

function TCluster.FindSel(P: TPoint): Integer;
var
  R: TRect;
  I, S: Integer;
begin
  R := GetExtent;
  if not R.Contains(P) then
    Result := -1
  else
  begin
    I := 0;
    while P.X >= Column(I + Size.Y) do
      Inc(I, Size.Y);
    S := I + P.Y;
    if S >= Strings^.Count then
      Result := -1
    else
      Result := S;
  end;
end;

function TCluster.Row(Item: Integer): Integer;
begin
  Result := Item mod Size.Y;
end;

function TCluster.ButtonState(Item: Integer): Boolean;
begin
  if (Item >= 0) and (Item < 32) then
    Result := (EnableMask and (LongWord(1) shl Item)) <> 0
  else
    Result := False;
end;

{ --- TRadioButtons ----------------------------------------------------------- }

procedure TRadioButtons.Draw;
begin
  DrawMultiBox(' ( ) ', ' ' + #7);
end;

function TRadioButtons.Mark(Item: Integer): Boolean;
begin
  Result := Item = Integer(Value);
end;

procedure TRadioButtons.Press(Item: Integer);
begin
  Value := Item;
end;

procedure TRadioButtons.MovedTo(Item: Integer);
begin
  Value := Item;
end;

procedure TRadioButtons.SetData(var Rec);
begin
  inherited SetData(Rec);
  Sel := Integer(Value);
end;

{ --- TCheckBoxes ------------------------------------------------------------- }

procedure TCheckBoxes.Draw;
begin
  DrawMultiBox(' [ ] ', ' X');
end;

function TCheckBoxes.Mark(Item: Integer): Boolean;
begin
  Result := (Item < 32) and ((Value and (LongWord(1) shl Item)) <> 0);
end;

procedure TCheckBoxes.Press(Item: Integer);
begin
  if Item < 32 then
    Value := Value xor (LongWord(1) shl Item);
end;

{ --- TMultiCheckBoxes -------------------------------------------------------- }

constructor TMultiCheckBoxes.Init(const Bounds: TRect; AStrings: PSItem; ASelRange: Byte;
  AFlags: Word; const AStates: ShortString);
begin
  inherited Init(Bounds, AStrings);
  SelRange := ASelRange;
  Flags := AFlags;
  States := NewStr(AStates);
end;

destructor TMultiCheckBoxes.Done;
begin
  DisposeStr(States);
  States := nil;
  inherited Done;
end;

procedure TMultiCheckBoxes.Draw;
begin
  DrawMultiBox(' [ ] ', States^);
end;

function TMultiCheckBoxes.DataSize: Integer;
begin
  Result := SizeOf(LongWord);
end;

function TMultiCheckBoxes.MultiMark(Item: Integer): Byte;
var
  Flo, Fhi: Integer;
begin
  Flo := Flags and $FF;
  Fhi := (Flags shr 8) * Item;
  if Fhi > 31 then
    Result := 0
  else
    Result := Byte((Value and (LongWord(Flo) shl Fhi)) shr Fhi);
end;

procedure TMultiCheckBoxes.GetData(var Rec);
begin
  LongWord(Rec) := Value;
  DrawView;
end;

procedure TMultiCheckBoxes.Press(Item: Integer);
var
  Flo, Fhi, Cur: Integer;
begin
  Flo := Flags and $FF;
  Fhi := (Flags shr 8) * Item;
  if Fhi > 31 then
    Exit;
  Cur := Integer((Value and (LongWord(Flo) shl Fhi)) shr Fhi);
  Inc(Cur);
  if Cur >= SelRange then
    Cur := 0;
  Value := (Value and not (LongWord(Flo) shl Fhi)) or (LongWord(Cur) shl Fhi);
end;

procedure TMultiCheckBoxes.SetData(var Rec);
begin
  Value := LongWord(Rec);
  DrawView;
end;

{ --- Streams ------------------------------------------------------------------ }

constructor TCluster.Load(var S: TStream);
begin
  inherited Load(S);
  S.Read(Value, SizeOf(Value));
  S.Read(Sel, SizeOf(Sel));
  S.Read(EnableMask, SizeOf(EnableMask));
  New(Strings, Load(S));
end;

procedure TCluster.Store(var S: TStream);
begin
  inherited Store(S);
  S.Write(Value, SizeOf(Value));
  S.Write(Sel, SizeOf(Sel));
  S.Write(EnableMask, SizeOf(EnableMask));
  Strings^.Store(S);
end;

constructor TRadioButtons.Load(var S: TStream);
begin
  inherited Load(S);
end;

constructor TCheckBoxes.Load(var S: TStream);
begin
  inherited Load(S);
end;

constructor TMultiCheckBoxes.Load(var S: TStream);
begin
  inherited Load(S);
  S.Read(SelRange, SizeOf(SelRange));
  S.Read(Flags, SizeOf(Flags));
  States := S.ReadStr;
end;

procedure TMultiCheckBoxes.Store(var S: TStream);
begin
  inherited Store(S);
  S.Write(SelRange, SizeOf(SelRange));
  S.Write(Flags, SizeOf(Flags));
  S.WriteStr(States);
end;

function BuildCluster(var S: TStream): PObject;
begin
  Result := New(PCluster, Load(S));
end;

procedure StoreCluster(P: PObject; var S: TStream);
begin
  PCluster(P)^.Store(S);
end;

function BuildRadioButtons(var S: TStream): PObject;
begin
  Result := New(PRadioButtons, Load(S));
end;

procedure StoreRadioButtons(P: PObject; var S: TStream);
begin
  PRadioButtons(P)^.Store(S);
end;

function BuildCheckBoxes(var S: TStream): PObject;
begin
  Result := New(PCheckBoxes, Load(S));
end;

procedure StoreCheckBoxes(P: PObject; var S: TStream);
begin
  PCheckBoxes(P)^.Store(S);
end;

function BuildMultiCheckBoxes(var S: TStream): PObject;
begin
  Result := New(PMultiCheckBoxes, Load(S));
end;

procedure StoreMultiCheckBoxes(P: PObject; var S: TStream);
begin
  PMultiCheckBoxes(P)^.Store(S);
end;

initialization
  RCluster.ObjType := 13;
  RCluster.VmtLink := PtrUInt(TypeOf(TCluster));
  RCluster.Load := @BuildCluster;
  RCluster.Store := @StoreCluster;
  RRadioButtons.ObjType := 14;
  RRadioButtons.VmtLink := PtrUInt(TypeOf(TRadioButtons));
  RRadioButtons.Load := @BuildRadioButtons;
  RRadioButtons.Store := @StoreRadioButtons;
  RCheckBoxes.ObjType := 15;
  RCheckBoxes.VmtLink := PtrUInt(TypeOf(TCheckBoxes));
  RCheckBoxes.Load := @BuildCheckBoxes;
  RCheckBoxes.Store := @StoreCheckBoxes;
  RMultiCheckBoxes.ObjType := 16;
  RMultiCheckBoxes.VmtLink := PtrUInt(TypeOf(TMultiCheckBoxes));
  RMultiCheckBoxes.Load := @BuildMultiCheckBoxes;
  RMultiCheckBoxes.Store := @StoreMultiCheckBoxes;

end.
