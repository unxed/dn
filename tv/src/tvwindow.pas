{ TvWindow: window frame, scroll bars, scroller and window.

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/views.h  (TFrame, TScrollBar, TScroller, TWindow, constants)
    source/tvision/tframe.cpp, framelin.cpp, tscrlbar.cpp, tscrolle.cpp, twindow.cpp,
    tvtext1.cpp (frame tables), drivers2.cpp (ctrlToArrow, in TvKeys)
  Borland disclaimer and MIT notice: tv/COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/DESIGN.md):
    - the frame is created by the virtual method InitFrame (as in the Pascal Turbo
      Vision) instead of the TWindowInit helper class;
    - the title is a ShortString, an empty title is drawn like no title;
    - Done replaces shutDown: it clears the pointers to other views;
    - the frame characters are the CP437 ones and go through the code page of
      TvText; the original's replacement of frameChars[30] for other code pages is
      not needed (a code page maps the double-line characters itself);
    - streams are not translated yet. }
unit TvWindow;

{$I tvdefs.inc}

interface

uses
  TvGeom, TvColors, TvCell, TvKeys, TvEvents, TvText, TvDrawBuf, TvScreen, TvObjs, TvViews, TvUtil;

const
  { window flags }
  wfMove          = $01;
  wfGrow          = $02;
  wfClose         = $04;
  wfZoom          = $08;

  { window numbers }
  wnNoNumber      = 0;

  { window palettes }
  wpBlueWindow    = 0;
  wpCyanWindow    = 1;
  wpGrayWindow    = 2;

  { scroll bar parts }
  sbLeftArrow     = 0;
  sbRightArrow    = 1;
  sbPageLeft      = 2;
  sbPageRight     = 3;
  sbUpArrow       = 4;
  sbDownArrow     = 5;
  sbPageUp        = 6;
  sbPageDown      = 7;
  sbIndicator     = 8;

  { StandardScrollBar options }
  sbHorizontal       = $000;
  sbVertical         = $001;
  sbHandleKeyboard   = $002;

type
  PFrame = ^TFrame;
  PScrollBar = ^TScrollBar;
  PScroller = ^TScroller;
  PWindow = ^TWindow;

  { Palette: 1 = passive frame, 2 = passive title, 3 = active frame, 4 = active
    title, 5 = icons }
  TFrame = object(TView)
    constructor Init(const Bounds: TRect);
    constructor Load(var S: TStream);
    procedure Draw; virtual;
    function GetPalette: TPalette; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure SetState(AState: Word; Enable: Boolean); virtual;
    procedure FrameLine(var FrameBuf: TDrawBuffer; Y, N: Integer; Color: TColorAttr);
    procedure DragWindow(var Event: TEvent; Mode: Byte);
  end;

  TScrollChars = array[0..4] of Byte;

  { Palette: 1 = page areas, 2 = arrows, 3 = indicator }
  TScrollBar = object(TView)
    Value: Integer;
    Chars: TScrollChars;
    MinVal: Integer;
    MaxVal: Integer;
    PgStep: Integer;
    ArStep: Integer;
    { used by DN: the last step that ScrollStep returned, and True while the step is repeated by a held mouse button }
    Step: LongInt;
    ForceScroll: Boolean;
    constructor Init(const Bounds: TRect);
    constructor Load(var S: TStream);
    procedure Store(var S: TStream);
    procedure Draw; virtual;
    function GetPalette: TPalette; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure ScrollDraw; virtual;
    function ScrollStep(Part: Integer): Integer; virtual;
    procedure SetParams(AValue, AMin, AMax, APgStep, AArStep: Integer);
    procedure SetRange(AMin, AMax: Integer);
    procedure SetStep(APgStep, AArStep: Integer);
    procedure SetValue(AValue: Integer);
    procedure DrawPos(Pos: Integer);
    function GetPos: Integer;
    function GetSize: Integer;
    function GetPartCode: Integer;
  end;

  { Palette: 1 = normal text, 2 = selected text }
  TScroller = object(TView)
    Delta: TPoint;
    DrawLock: Byte;
    DrawFlag: Boolean;
    HScrollBar: PScrollBar;
    VScrollBar: PScrollBar;
    Limit: TPoint;
    constructor Init(const Bounds: TRect; AHScrollBar, AVScrollBar: PScrollBar);
    constructor Load(var S: TStream);
    procedure Store(var S: TStream);
    destructor Done; virtual;
    procedure ChangeBounds(const Bounds: TRect); virtual;
    function GetPalette: TPalette; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure ScrollDraw; virtual;
    procedure ScrollTo(X, Y: Integer);
    procedure SetLimit(X, Y: Integer);
    procedure SetState(AState: Word; Enable: Boolean); virtual;
    procedure CheckDraw;
    procedure ShowSBar(SBar: PScrollBar);
  end;

  { Palette: 1 = passive frame, 2 = active frame, 3 = frame icon, 4 = scroll bar
    page area, 5 = scroll bar controls, 6 = scroller normal text, 7 = scroller
    selected text, 8 = reserved }
  TWindow = object(TGroup)
    Flags: Byte;
    ZoomRect: TRect;
    Number: Integer;
    Palette: Integer;
    Frame: PFrame;
    Title: PStr;   { as in Borland TV: a heap string (NewStr/DisposeStr), nil = none; DN changes it directly }
    constructor Init(const Bounds: TRect; const ATitle: ShortString; ANumber: Integer);
    constructor Load(var S: TStream);
    procedure Store(var S: TStream);
    destructor Done; virtual;
    procedure Close; virtual;
    function GetPalette: TPalette; virtual;
    function GetTitle(MaxSize: Integer): ShortString; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure InitFrame; virtual;
    procedure SetState(AState: Word; Enable: Boolean); virtual;
    procedure SizeLimits(out Min, Max: TPoint); virtual;
    function StandardScrollBar(AOptions: Word): PScrollBar;
    procedure Zoom; virtual;
  end;

var
  { DN: called when a window with a number is destroyed (DN hands the numbers out itself: Views.GetNum) }
  WindowNumberFreeHook: procedure(Number: Integer) = nil;
  { stream records (see RView of TvViews) }
  RFrame, RScrollBar, RScroller, RWindow: TStreamRec;

implementation

const
  MinWinSize: TPoint = (X: 16; Y: 6);

  { Frame line masks: bit 0 = up, 1 = right, 2 = down, 3 = left, +16 for a double
    line. FrameInit holds the masks of the left, middle and right part of the top,
    middle and bottom line, first for a passive, then for an active frame. }
  FrameInit: array[0..17] of Byte = (
    $06, $0A, $0C, $05, $00, $05, $03, $0A, $09,
    $16, $1A, $1C, $15, $00, $15, $13, $1A, $19);

  { mask -> CP437 character }
  FrameChars: array[0..31] of Byte = (
    $20, $20, $20, $C0, $20, $B3, $DA, $C3, $20, $D9, $C4, $C1, $BF, $B4, $C2, $C5,
    $20, $20, $20, $C8, $20, $BA, $C9, $C7, $20, $BC, $CD, $CF, $BB, $B6, $D1, $20);

  CloseIcon    = '[~'#$FE'~]';
  ZoomIcon     = '[~'#$18'~]';
  UnZoomIcon   = '[~'#$12'~]';
  DragIcon     = '~'#$C4#$D9'~';
  DragLeftIcon = '~'#$C0#$C4'~';

  VChars: TScrollChars = ($1E, $1F, $B1, $FE, $B2);
  HChars: TScrollChars = ($11, $10, $B1, $FE, $B2);

var
  FramePalette, ScrollBarPalette, ScrollerPalette: TPalette;
  BluePalette, CyanPalette, GrayPalette: TPalette;

function Min2(A, B: Integer): Integer; inline;
begin
  if A < B then Result := A else Result := B;
end;

function Max2(A, B: Integer): Integer; inline;
begin
  if A > B then Result := A else Result := B;
end;

{ --- TFrame ------------------------------------------------------------------ }

constructor TFrame.Init(const Bounds: TRect);
begin
  inherited Init(Bounds);
  GrowMode := gfGrowHiX + gfGrowHiY;
  EventMask := EventMask or evBroadcast or evMouseUp;
end;

procedure TFrame.FrameLine(var FrameBuf: TDrawBuffer; Y, N: Integer; Color: TColorAttr);
var
  FrameMask: array of Byte;
  X, Start, Finish: Integer;
  V: PView;
  Mask: Word;
  MaskLow, MaskHigh: Byte;
begin
  if Size.X <= 0 then
    Exit;
  SetLength(FrameMask, Size.X);
  FrameMask[0] := FrameInit[N];
  for X := 1 to Size.X - 2 do
    FrameMask[X] := FrameInit[N + 1];
  FrameMask[Size.X - 1] := FrameInit[N + 2];
  { the framed views in front of this one cross the line }
  V := Owner^.Last^.Next;
  while V <> PView(@Self) do
  begin
    if ((V^.Options and ofFramed) <> 0) and ((V^.State and sfVisible) <> 0) then
    begin
      Mask := 0;
      if Y < V^.Origin.Y then
      begin
        if Y = V^.Origin.Y - 1 then
          Mask := $0A06;
      end
      else if Y < V^.Origin.Y + V^.Size.Y then
        Mask := $0005
      else if Y = V^.Origin.Y + V^.Size.Y then
        Mask := $0A03;
      if Mask <> 0 then
      begin
        Start := Max2(V^.Origin.X, 1);
        Finish := Min2(V^.Origin.X + V^.Size.X, Size.X - 1);
        if Start < Finish then
        begin
          MaskLow := Mask and $00FF;
          MaskHigh := (Mask and $FF00) shr 8;
          FrameMask[Start - 1] := FrameMask[Start - 1] or MaskLow;
          FrameMask[Finish] := FrameMask[Finish] or (MaskLow xor MaskHigh);
          if MaskLow <> 0 then
            for X := Start to Finish - 1 do
              FrameMask[X] := FrameMask[X] or MaskHigh;
        end;
      end;
    end;
    V := V^.Next;
  end;
  for X := 0 to Size.X - 1 do
  begin
    FrameBuf.PutChar(X, FrameChars[FrameMask[X]]);
    FrameBuf.PutAttribute(X, Color);
  end;
end;

procedure TFrame.Draw;
var
  CFrame, CTitle: TAttrPair;
  F, I, L, Width: Integer;
  B: TDrawBuffer;
  W: PWindow;
  T: ShortString;
  MinSize, MaxSize: TPoint;
begin
  if Owner = nil then
    Exit;
  W := PWindow(Owner);
  if (State and sfDragging) <> 0 then
  begin
    CFrame := GetColor($0505);
    CTitle := GetColor($0005);
    F := 0;
  end
  else if (State and sfActive) = 0 then
  begin
    CFrame := GetColor($0101);
    CTitle := GetColor($0002);
    F := 0;
  end
  else
  begin
    CFrame := GetColor($0503);
    CTitle := GetColor($0004);
    F := 9;
  end;
  Width := Size.X;
  L := Width - 10;
  if (W^.Flags and (wfClose or wfZoom)) <> 0 then
    Dec(L, 6);
  B.Init(Width);
  FrameLine(B, 0, F, CFrame.Lo);
  if (W^.Number <> wnNoNumber) and (W^.Number < 10) then
  begin
    Dec(L, 4);
    if (W^.Flags and wfZoom) <> 0 then
      I := 7
    else
      I := 3;
    B.PutChar(Width - I, W^.Number + Ord('0'));
  end;
  T := W^.GetTitle(L);
  if T <> '' then
  begin
    L := Min2(TextWidthS(T), Width - 10);
    L := Max2(L, 0);
    I := (Width - L) shr 1;
    B.PutChar(I - 1, Ord(' '));
    B.MoveStrS(I, T, CTitle.Lo, L);
    B.PutChar(I + L, Ord(' '));
  end;
  if (State and sfActive) <> 0 then
  begin
    if (W^.Flags and wfClose) <> 0 then
      B.MoveCStrS(2, CloseIcon, CFrame);
    if (W^.Flags and wfZoom) <> 0 then
    begin
      Owner^.SizeLimits(MinSize, MaxSize);
      if PointEq(Owner^.Size, MaxSize) then
        B.MoveCStrS(Width - 5, UnZoomIcon, CFrame)
      else
        B.MoveCStrS(Width - 5, ZoomIcon, CFrame);
    end;
  end;
  WriteLineD(0, 0, Size.X, 1, B);
  for I := 1 to Size.Y - 2 do
  begin
    FrameLine(B, I, F + 3, CFrame.Lo);
    WriteLineD(0, I, Size.X, 1, B);
  end;
  FrameLine(B, Size.Y - 1, F + 6, CFrame.Lo);
  if ((State and sfActive) <> 0) and ((W^.Flags and wfGrow) <> 0) then
  begin
    B.MoveCStrS(0, DragLeftIcon, CFrame);
    B.MoveCStrS(Width - 2, DragIcon, CFrame);
  end;
  WriteLineD(0, Size.Y - 1, Size.X, 1, B);
  B.Done;
end;

function TFrame.GetPalette: TPalette;
begin
  Result := FramePalette;
end;

procedure TFrame.DragWindow(var Event: TEvent; Mode: Byte);
var
  Limits: TRect;
  Min, Max: TPoint;
begin
  Limits := Owner^.Owner^.GetExtent;
  Owner^.SizeLimits(Min, Max);
  Owner^.DragView(Event, Owner^.DragMode or Mode, Limits, Min, Max);
  ClearEvent(Event);
end;

procedure TFrame.HandleEvent(var Event: TEvent);
var
  Mouse: TPoint;
  W: PWindow;
begin
  inherited HandleEvent(Event);
  if Event.What = evMouseDown then
  begin
    W := PWindow(Owner);
    Mouse := MakeLocal(Event.Where);
    if Mouse.Y = 0 then
    begin
      if ((W^.Flags and wfClose) <> 0) and ((State and sfActive) <> 0) and
        (Mouse.X >= 2) and (Mouse.X <= 4) then
      begin
        while MouseEvent(Event, evMouse) do
          ;
        Mouse := MakeLocal(Event.Where);
        if (Mouse.Y = 0) and (Mouse.X >= 2) and (Mouse.X <= 4) then
        begin
          Event.What := evCommand;
          Event.Command := cmClose;
          Event.InfoPtr := Owner;
          PutEvent(Event);
          ClearEvent(Event);
        end;
      end
      else if ((W^.Flags and wfZoom) <> 0) and ((State and sfActive) <> 0) and
        (((Mouse.X >= Size.X - 5) and (Mouse.X <= Size.X - 3)) or
         ((Event.EventFlags and meDoubleClick) <> 0)) then
      begin
        Event.What := evCommand;
        Event.Command := cmZoom;
        Event.InfoPtr := Owner;
        PutEvent(Event);
        ClearEvent(Event);
      end
      else if (W^.Flags and wfMove) <> 0 then
        DragWindow(Event, dmDragMove);
    end
    else if ((State and sfActive) <> 0) and (Mouse.Y >= Size.Y - 1) and
      ((W^.Flags and wfGrow) <> 0) then
    begin
      if Mouse.X >= Size.X - 2 then
        DragWindow(Event, dmDragGrow)
      else if Mouse.X <= 1 then
        DragWindow(Event, dmDragGrowLeft);
    end
    else if (Event.What = evMouseDown) and (Event.Buttons = mbMiddleButton) and
      (0 < Mouse.X) and (Mouse.X < Size.X - 1) and (0 < Mouse.Y) and
      (Mouse.Y < Size.Y - 1) and ((W^.Flags and wfMove) <> 0) then
      DragWindow(Event, dmDragMove);
  end;
end;

procedure TFrame.SetState(AState: Word; Enable: Boolean);
begin
  inherited SetState(AState, Enable);
  if (AState and (sfActive or sfDragging)) <> 0 then
    DrawView;
end;

{ --- TScrollBar -------------------------------------------------------------- }

{ the state of the mouse handling of a bar (static in the original, so a bar
  cannot be handled while another one is: that never happens) }
var
  SbMouse: TPoint;
  SbP, SbS: Integer;
  SbExtent: TRect;

constructor TScrollBar.Init(const Bounds: TRect);
begin
  inherited Init(Bounds);
  Value := 0;
  MinVal := 0;
  MaxVal := 0;
  PgStep := 1;
  ArStep := 1;
  if Size.X = 1 then
  begin
    GrowMode := gfGrowLoX or gfGrowHiX or gfGrowHiY;
    Chars := VChars;
  end
  else
  begin
    GrowMode := gfGrowLoY or gfGrowHiX or gfGrowHiY;
    Chars := HChars;
  end;
  EventMask := EventMask or evMouseWheel;
end;

procedure TScrollBar.Draw;
begin
  DrawPos(GetPos);
end;

procedure TScrollBar.DrawPos(Pos: Integer);
var
  B: TDrawBuffer;
  S: Integer;
begin
  B.Init(GetSize);
  S := GetSize - 1;
  B.MoveChar(0, Chars[0], GetColor(2).Lo, 1);
  if MaxVal = MinVal then
    B.MoveChar(1, Chars[4], GetColor(1).Lo, S - 1)
  else
  begin
    B.MoveChar(1, Chars[2], GetColor(1).Lo, S - 1);
    B.MoveChar(Pos, Chars[3], GetColor(3).Lo, 1);
  end;
  B.MoveChar(S, Chars[1], GetColor(2).Lo, 1);
  WriteBufD(0, 0, Size.X, Size.Y, B);
  B.Done;
end;

function TScrollBar.GetPalette: TPalette;
begin
  Result := ScrollBarPalette;
end;

function TScrollBar.GetSize: Integer;
var
  S: Integer;
begin
  if Size.X = 1 then
    S := Size.Y
  else
    S := Size.X;
  Result := Max2(3, S);
end;

function TScrollBar.GetPos: Integer;
var
  R: Integer;
begin
  R := MaxVal - MinVal;
  if R = 0 then
    Result := 1
  else
    Result := Integer((((Int64(Value - MinVal) * (GetSize - 3)) + (R shr 1)) div R) + 1);
end;

function TScrollBar.GetPartCode: Integer;
var
  Part, Mark: Integer;
begin
  Part := -1;
  if SbExtent.Contains(SbMouse) then
  begin
    if Size.X = 1 then
      Mark := SbMouse.Y
    else
      Mark := SbMouse.X;
    if Mark = SbP then
      Part := sbIndicator
    else
    begin
      if Mark < 1 then
        Part := sbLeftArrow
      else if Mark < SbP then
        Part := sbPageLeft
      else if Mark < SbS then
        Part := sbPageRight
      else
        Part := sbRightArrow;
      if Size.X = 1 then
        Inc(Part, 4);
    end;
  end;
  Result := Part;
end;

procedure TScrollBar.HandleEvent(var Event: TEvent);
var
  I, ClickPart: Integer;   { Step: the field (DN reads the step of a wheel turn too) }
begin
  Step := 0;
  I := 0;
  inherited HandleEvent(Event);
  ForceScroll := False;
  case Event.What of
    evMouseWheel:
      begin
        if (State and sfVisible) <> 0 then
        begin
          if Size.X = 1 then
            case Event.Wheel of
              mwUp: Step := -ArStep;
              mwDown: Step := ArStep;
            end
          else
            case Event.Wheel of
              mwLeft: Step := -ArStep;
              mwRight: Step := ArStep;
            end;
        end;
        if Step <> 0 then
        begin
          { e.g. when the bar belongs to a list viewer, this makes it selected }
          Message(Owner, evBroadcast, cmScrollBarClicked, @Self);
          SetValue(Value + 3 * Step);
          ClearEvent(Event);
        end;
      end;
    evMouseDown:
      begin
        Message(Owner, evBroadcast, cmScrollBarClicked, @Self);
        SbMouse := MakeLocal(Event.Where);
        SbExtent := GetExtent;
        SbExtent.Grow(1, 1);
        SbP := GetPos;
        SbS := GetSize - 1;
        ClickPart := GetPartCode;
        case ClickPart of
          sbLeftArrow, sbRightArrow, sbUpArrow, sbDownArrow:
            { an arrow: repeat the step while the button is down over it }
            repeat
              SbMouse := MakeLocal(Event.Where);
              if GetPartCode = ClickPart then
              begin
                ForceScroll := True;
                SetValue(Value + ScrollStep(ClickPart));
              end;
            until not MouseEvent(Event, evMouseAuto);
        else
          { otherwise the thumb follows the mouse }
          repeat
            SbMouse := MakeLocal(Event.Where);
            if Size.X = 1 then
              I := SbMouse.Y
            else
              I := SbMouse.X;
            I := Max2(I, 1);
            I := Min2(I, SbS - 1);
            SbP := I;
            if SbS > 2 then
              SetValue(Integer(((Int64(SbP - 1) * (MaxVal - MinVal) + ((SbS - 2) shr 1)) div
                (SbS - 2)) + MinVal));
            DrawPos(SbP);
          until not MouseEvent(Event, evMouseMove);
        end;
        ClearEvent(Event);
      end;
    evKeyDown:
      if (State and sfVisible) <> 0 then
      begin
        ClickPart := sbIndicator;
        if Size.Y = 1 then
          case CtrlToArrow(Event.KeyCode) of
            kbLeft: ClickPart := sbLeftArrow;
            kbRight: ClickPart := sbRightArrow;
            kbCtrlLeft: ClickPart := sbPageLeft;
            kbCtrlRight: ClickPart := sbPageRight;
            kbCtrlUp: ClickPart := sbPageUp;
            kbCtrlDown: ClickPart := sbPageDown;
            kbHome: I := MinVal;
            kbEnd: I := MaxVal;
          else
            Exit;
          end
        else
          case CtrlToArrow(Event.KeyCode) of
            kbUp: ClickPart := sbUpArrow;
            kbDown: ClickPart := sbDownArrow;
            kbPgUp: ClickPart := sbPageUp;
            kbPgDn: ClickPart := sbPageDown;
            kbCtrlPgUp: I := MinVal;
            kbCtrlPgDn: I := MaxVal;
          else
            Exit;
          end;
        Message(Owner, evBroadcast, cmScrollBarClicked, @Self);
        if ClickPart <> sbIndicator then
          I := Value + ScrollStep(ClickPart);
        SetValue(I);
        ClearEvent(Event);
      end;
  end;
end;

procedure TScrollBar.ScrollDraw;
begin
  Message(Owner, evBroadcast, cmScrollBarChanged, @Self);
end;

function TScrollBar.ScrollStep(Part: Integer): Integer;
var
  St: Integer;
begin
  if (Part and 2) = 0 then
    St := ArStep
  else
    St := PgStep;
  if (Part and 1) = 0 then
    St := -St;
  Step := St;
  Result := St;
end;

procedure TScrollBar.SetParams(AValue, AMin, AMax, APgStep, AArStep: Integer);
var
  SValue: Integer;
begin
  AMax := Max2(AMax, AMin);
  AValue := Max2(AMin, AValue);
  AValue := Min2(AMax, AValue);
  SValue := Value;
  if (SValue <> AValue) or (MinVal <> AMin) or (MaxVal <> AMax) then
  begin
    Value := AValue;
    MinVal := AMin;
    MaxVal := AMax;
    DrawView;
    if SValue <> AValue then
      ScrollDraw;
  end;
  PgStep := APgStep;
  ArStep := AArStep;
end;

procedure TScrollBar.SetRange(AMin, AMax: Integer);
begin
  SetParams(Value, AMin, AMax, PgStep, ArStep);
end;

procedure TScrollBar.SetStep(APgStep, AArStep: Integer);
begin
  SetParams(Value, MinVal, MaxVal, APgStep, AArStep);
end;

procedure TScrollBar.SetValue(AValue: Integer);
begin
  SetParams(AValue, MinVal, MaxVal, PgStep, ArStep);
end;

{ --- TScroller --------------------------------------------------------------- }

constructor TScroller.Init(const Bounds: TRect; AHScrollBar, AVScrollBar: PScrollBar);
begin
  inherited Init(Bounds);
  DrawLock := 0;
  DrawFlag := False;
  HScrollBar := AHScrollBar;
  VScrollBar := AVScrollBar;
  Delta.X := 0;
  Delta.Y := 0;
  Limit.X := 0;
  Limit.Y := 0;
  Options := Options or ofSelectable;
  EventMask := EventMask or evBroadcast;
end;

destructor TScroller.Done;
begin
  HScrollBar := nil;
  VScrollBar := nil;
  inherited Done;
end;

procedure TScroller.ChangeBounds(const Bounds: TRect);
begin
  SetBounds(Bounds);
  Inc(DrawLock);
  SetLimit(Limit.X, Limit.Y);
  Dec(DrawLock);
  DrawFlag := False;
  DrawView;
end;

procedure TScroller.CheckDraw;
begin
  if (DrawLock = 0) and DrawFlag then
  begin
    DrawFlag := False;
    DrawView;
  end;
end;

function TScroller.GetPalette: TPalette;
begin
  Result := ScrollerPalette;
end;

procedure TScroller.HandleEvent(var Event: TEvent);
begin
  inherited HandleEvent(Event);
  if (Event.What = evBroadcast) and (Event.Command = cmScrollBarChanged) and
    ((Event.InfoPtr = HScrollBar) or (Event.InfoPtr = VScrollBar)) then
    ScrollDraw;
end;

procedure TScroller.ScrollDraw;
var
  D: TPoint;
begin
  if HScrollBar <> nil then
    D.X := HScrollBar^.Value
  else
    D.X := 0;
  if VScrollBar <> nil then
    D.Y := VScrollBar^.Value
  else
    D.Y := 0;
  if (D.X <> Delta.X) or (D.Y <> Delta.Y) then
  begin
    SetCursor(Cursor.X + Delta.X - D.X, Cursor.Y + Delta.Y - D.Y);
    Delta := D;
    if DrawLock <> 0 then
      DrawFlag := True
    else
      DrawView;
  end;
end;

procedure TScroller.ScrollTo(X, Y: Integer);
begin
  Inc(DrawLock);
  if HScrollBar <> nil then
    HScrollBar^.SetValue(X);
  if VScrollBar <> nil then
    VScrollBar^.SetValue(Y);
  Dec(DrawLock);
  CheckDraw;
end;

procedure TScroller.SetLimit(X, Y: Integer);
begin
  Limit.X := X;
  Limit.Y := Y;
  Inc(DrawLock);
  if HScrollBar <> nil then
    HScrollBar^.SetParams(HScrollBar^.Value, 0, X - Size.X, Size.X - 1, HScrollBar^.ArStep);
  if VScrollBar <> nil then
    VScrollBar^.SetParams(VScrollBar^.Value, 0, Y - Size.Y, Size.Y - 1, VScrollBar^.ArStep);
  Dec(DrawLock);
  CheckDraw;
end;

procedure TScroller.ShowSBar(SBar: PScrollBar);
begin
  if SBar <> nil then
  begin
    { both bits are asked for at once: the original calls getState(sfActive | sfSelected) }
    if GetState(sfActive or sfSelected) then
      SBar^.Show
    else
      SBar^.Hide;
  end;
end;

procedure TScroller.SetState(AState: Word; Enable: Boolean);
begin
  inherited SetState(AState, Enable);
  if (AState and (sfActive or sfSelected)) <> 0 then
  begin
    ShowSBar(HScrollBar);
    ShowSBar(VScrollBar);
  end;
end;

{ --- TWindow ----------------------------------------------------------------- }

constructor TWindow.Init(const Bounds: TRect; const ATitle: ShortString; ANumber: Integer);
begin
  inherited Init(Bounds);
  Flags := wfMove or wfGrow or wfClose or wfZoom;
  ZoomRect := GetBounds;
  Number := ANumber;
  Palette := wpBlueWindow;
  Title := NewStr(ATitle);
  State := State or sfShadow;
  Options := Options or (ofSelectable or ofTopSelect);
  GrowMode := gfGrowAll or gfGrowRel;
  Frame := nil;
  InitFrame;
  if Frame <> nil then
    Insert(Frame);
end;

destructor TWindow.Done;
begin
  { the frame is destroyed with the other subviews }
  if Assigned(WindowNumberFreeHook) and (Number > 0) then
    WindowNumberFreeHook(Number);
  Frame := nil;
  inherited Done;
  DisposeStr(Title);
  Title := nil;
end;

procedure TWindow.InitFrame;
var
  R: TRect;
begin
  R := GetExtent;
  New(Frame, Init(R));
end;

procedure TWindow.Close;
begin
  if Valid(cmClose) then
  begin
    Frame := nil;   { so the frame is not used after it has been deleted }
    Dispose(PWindow(@Self), Done);
  end;
end;

function TWindow.GetPalette: TPalette;
begin
  case Palette of
    wpCyanWindow: Result := CyanPalette;
    wpGrayWindow: Result := GrayPalette;
  else
    Result := BluePalette;
  end;
end;

function TWindow.GetTitle(MaxSize: Integer): ShortString;
begin
  if Title <> nil then
    Result := Title^
  else
    Result := '';
end;

procedure TWindow.HandleEvent(var Event: TEvent);
var
  Limits: TRect;
  Min, Max: TPoint;
begin
  inherited HandleEvent(Event);
  if Event.What = evCommand then
    case Event.Command of
      cmResize:
        if (Flags and (wfMove or wfGrow)) <> 0 then
        begin
          Limits := Owner^.GetExtent;
          SizeLimits(Min, Max);
          DragView(Event, DragMode or (Flags and (wfMove or wfGrow)), Limits, Min, Max);
          ClearEvent(Event);
        end;
      cmClose:
        if ((Flags and wfClose) <> 0) and
          ((Event.InfoPtr = nil) or (Event.InfoPtr = @Self)) then
        begin
          ClearEvent(Event);
          if (State and sfModal) = 0 then
            Close
          else
          begin
            Event.What := evCommand;
            Event.Command := cmCancel;
            PutEvent(Event);
            ClearEvent(Event);
          end;
        end;
      cmZoom:
        if ((Flags and wfZoom) <> 0) and
          ((Event.InfoPtr = nil) or (Event.InfoPtr = @Self)) then
        begin
          Zoom;
          ClearEvent(Event);
        end;
    end
  else if Event.What = evKeyDown then
  begin
    case Event.KeyCode of
      kbTab:
        begin
          FocusNext(False);
          ClearEvent(Event);
        end;
      kbShiftTab:
        begin
          FocusNext(True);
          ClearEvent(Event);
        end;
    end;
  end
  else if (Event.What = evBroadcast) and (Event.Command = cmSelectWindowNum) and
    (Event.InfoInt = Number) and ((Options and ofSelectable) <> 0) then
  begin
    Select;
    ClearEvent(Event);
  end;
end;

procedure TWindow.SetState(AState: Word; Enable: Boolean);
var
  WindowCommands: TCommandSet;
begin
  inherited SetState(AState, Enable);
  if (AState and sfSelected) <> 0 then
  begin
    SetState(sfActive, Enable);
    if Frame <> nil then
      Frame^.SetState(sfActive, Enable);
    WindowCommands := [];
    Include(WindowCommands, cmNext);
    Include(WindowCommands, cmPrev);
    if (Flags and (wfGrow or wfMove)) <> 0 then
      Include(WindowCommands, cmResize);
    if (Flags and wfClose) <> 0 then
      Include(WindowCommands, cmClose);
    if (Flags and wfZoom) <> 0 then
      Include(WindowCommands, cmZoom);
    if Enable then
      EnableCommands(WindowCommands)
    else
      DisableCommands(WindowCommands);
  end;
end;

function TWindow.StandardScrollBar(AOptions: Word): PScrollBar;
var
  R: TRect;
  S: PScrollBar;
begin
  R := GetExtent;
  if (AOptions and sbVertical) <> 0 then
    R.Assign(R.B.X - 1, R.A.Y + 1, R.B.X, R.B.Y - 1)
  else
    R.Assign(R.A.X + 2, R.B.Y - 1, R.B.X - 2, R.B.Y);
  New(S, Init(R));
  Insert(S);
  if (AOptions and sbHandleKeyboard) <> 0 then
    S^.Options := S^.Options or ofPostProcess;
  Result := S;
end;

procedure TWindow.SizeLimits(out Min, Max: TPoint);
begin
  inherited SizeLimits(Min, Max);
  Min := MinWinSize;
end;

procedure TWindow.Zoom;
var
  MinSize, MaxSize: TPoint;
  R: TRect;
begin
  SizeLimits(MinSize, MaxSize);
  if not PointEq(Size, MaxSize) then
  begin
    ZoomRect := GetBounds;
    R.Assign(0, 0, MaxSize.X, MaxSize.Y);
    Locate(R);
  end
  else
    Locate(ZoomRect);
end;


{ --- Streams ------------------------------------------------------------------ }

constructor TFrame.Load(var S: TStream);
begin
  inherited Load(S);
end;

constructor TScrollBar.Load(var S: TStream);
begin
  inherited Load(S);
  S.Read(Value, SizeOf(Value));
  S.Read(MinVal, SizeOf(MinVal));
  S.Read(MaxVal, SizeOf(MaxVal));
  S.Read(PgStep, SizeOf(PgStep));
  S.Read(ArStep, SizeOf(ArStep));
  S.Read(Chars, SizeOf(Chars));
end;

procedure TScrollBar.Store(var S: TStream);
begin
  inherited Store(S);
  S.Write(Value, SizeOf(Value));
  S.Write(MinVal, SizeOf(MinVal));
  S.Write(MaxVal, SizeOf(MaxVal));
  S.Write(PgStep, SizeOf(PgStep));
  S.Write(ArStep, SizeOf(ArStep));
  S.Write(Chars, SizeOf(Chars));
end;

constructor TScroller.Load(var S: TStream);
begin
  inherited Load(S);
  GetPeerViewPtr(S, HScrollBar);
  GetPeerViewPtr(S, VScrollBar);
  S.Read(Delta, SizeOf(Delta));
  S.Read(Limit, SizeOf(Limit));
  DrawLock := 0;
  DrawFlag := False;
end;

procedure TScroller.Store(var S: TStream);
begin
  inherited Store(S);
  PutPeerViewPtr(S, HScrollBar);
  PutPeerViewPtr(S, VScrollBar);
  S.Write(Delta, SizeOf(Delta));
  S.Write(Limit, SizeOf(Limit));
end;

constructor TWindow.Load(var S: TStream);
begin
  inherited Load(S);
  S.Read(Flags, SizeOf(Flags));
  S.Read(ZoomRect, SizeOf(ZoomRect));
  S.Read(Number, SizeOf(Number));
  S.Read(Palette, SizeOf(Palette));
  Frame := PFrame(ReadChildPtr(S));
  Title := S.ReadStr;
end;

procedure TWindow.Store(var S: TStream);
begin
  inherited Store(S);
  S.Write(Flags, SizeOf(Flags));
  S.Write(ZoomRect, SizeOf(ZoomRect));
  S.Write(Number, SizeOf(Number));
  S.Write(Palette, SizeOf(Palette));
  PutSubViewPtr(S, Frame);
  S.WriteStr(Title);
end;

function BuildFrame(var S: TStream): PObject;
begin
  Result := New(PFrame, Load(S));
end;

procedure StoreFrame(P: PObject; var S: TStream);
begin
  PFrame(P)^.Store(S);
end;

function BuildScrollBar(var S: TStream): PObject;
begin
  Result := New(PScrollBar, Load(S));
end;

procedure StoreScrollBar(P: PObject; var S: TStream);
begin
  PScrollBar(P)^.Store(S);
end;

function BuildScroller(var S: TStream): PObject;
begin
  Result := New(PScroller, Load(S));
end;

procedure StoreScroller(P: PObject; var S: TStream);
begin
  PScroller(P)^.Store(S);
end;

function BuildWindow(var S: TStream): PObject;
begin
  Result := New(PWindow, Load(S));
end;

procedure StoreWindow(P: PObject; var S: TStream);
begin
  PWindow(P)^.Store(S);
end;

initialization
  RFrame.ObjType := 2;
  RFrame.VmtLink := PtrUInt(TypeOf(TFrame));
  RFrame.Load := @BuildFrame;
  RFrame.Store := @StoreFrame;
  RScrollBar.ObjType := 3;
  RScrollBar.VmtLink := PtrUInt(TypeOf(TScrollBar));
  RScrollBar.Load := @BuildScrollBar;
  RScrollBar.Store := @StoreScrollBar;
  RScroller.ObjType := 4;
  RScroller.VmtLink := PtrUInt(TypeOf(TScroller));
  RScroller.Load := @BuildScroller;
  RScroller.Store := @StoreScroller;
  RWindow.ObjType := 7;
  RWindow.VmtLink := PtrUInt(TypeOf(TWindow));
  RWindow.Load := @BuildWindow;
  RWindow.Store := @StoreWindow;
  FramePalette := MakePalette(#1#1#2#2#3);
  ScrollBarPalette := MakePalette(#4#5#5);
  ScrollerPalette := MakePalette(#6#7);
  BluePalette := MakePalette(#8#9#10#11#12#13#14#15);
  CyanPalette := MakePalette(#16#17#18#19#20#21#22#23);
  GrayPalette := MakePalette(#24#25#26#27#28#29#30#31);
end.
