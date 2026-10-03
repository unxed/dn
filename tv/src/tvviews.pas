{ TvViews: views and groups of views (the core of Turbo Vision).

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/views.h        (constants, TCommandSet, TPalette, TView, TGroup)
    source/tvision/tview.cpp, tgroup.cpp, grp.cpp, mapcolor.cpp, palette.cpp,
    tcmdset.cpp, misc.cpp (message), tvwrite.cpp (output engine),
    tvexposd.cpp (exposed), tvcursor.cpp (resetCursor)
  Borland disclaimer and MIT notice: tv/COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/DESIGN.md):
    - Pascal names: Done (which also detaches the view from its group, like the
      Pascal Turbo Vision), Delete instead of remove;
    - TCommandSet is `set of Byte` (commands above 255 are always enabled);
    - a TPalette is an array of TColorAttr whose element 0 is the number of
      entries as a BIOS attribute; a nil palette is an empty one;
    - the screen is TvScreen, the output engine only knows TScreenCell buffers;
    - streams (read/write/build) and timers are not translated yet; GetEvent with
      a timeout, TextEvent and the event loop of TProgram come with TvApp.
  The two goto-style engines of the original (tvwrite, tvexposd, translations of
  Borland's assembler) are kept step by step: their L-numbers are the original's. }
unit TvViews;

{$I tvdefs.inc}

interface

uses
  TvGeom, TvColors, TvCell, TvKeys, TvEvents, TvText, TvDrawBuf, TvScreen, TvObjs, TvTimer;

const
  { standard command codes }
  cmValid         = 0;
  cmQuit          = 1;
  cmError         = 2;
  cmMenu          = 3;
  cmClose         = 4;
  cmZoom          = 5;
  cmResize        = 6;
  cmNext          = 7;
  cmPrev          = 8;
  cmHelp          = 9;
  cmOK            = 10;
  cmCancel        = 11;
  cmYes           = 12;
  cmNo            = 13;
  cmDefault       = 14;
  cmCut           = 20;
  cmCopy          = 21;
  cmPaste         = 22;
  cmUndo          = 23;
  cmClear         = 24;
  cmTile          = 25;
  cmCascade       = 26;
  cmRedo          = 27;
  cmNew           = 30;
  cmOpen          = 31;
  cmSave          = 32;
  cmSaveAs        = 33;
  cmSaveAll       = 34;
  cmChDir         = 35;
  cmDosShell      = 36;
  cmCloseAll      = 37;

  { standard messages }
  cmReceivedFocus     = 50;
  cmReleasedFocus     = 51;
  cmCommandSetChanged = 52;
  cmScrollBarChanged  = 53;
  cmScrollBarClicked  = 54;
  cmSelectWindowNum   = 55;
  cmListItemSelected  = 56;
  cmScreenChanged     = 57;
  cmTimerExpired      = 58;

  { TView state masks }
  sfVisible       = $001;
  sfCursorVis     = $002;
  sfCursorIns     = $004;
  sfShadow        = $008;
  sfActive        = $010;
  sfSelected      = $020;
  sfFocused       = $040;
  sfDragging      = $080;
  sfDisabled      = $100;
  sfModal         = $200;
  sfDefault       = $400;
  sfExposed       = $800;

  { TView option masks }
  ofSelectable    = $001;
  ofTopSelect     = $002;
  ofFirstClick    = $004;
  ofFramed        = $008;
  ofPreProcess    = $010;
  ofPostProcess   = $020;
  ofBuffered      = $040;
  ofTileable      = $080;
  ofCenterX       = $100;
  ofCenterY       = $200;
  ofCentered      = $300;
  ofValidate      = $400;

  { TView growMode masks }
  gfGrowLoX       = $01;
  gfGrowLoY       = $02;
  gfGrowHiX       = $04;
  gfGrowHiY       = $08;
  gfGrowAll       = $0F;
  gfGrowRel       = $10;
  gfFixed         = $20;

  { TView dragMode masks }
  dmDragMove      = $01;
  dmDragGrow      = $02;
  dmDragGrowLeft  = $04;
  dmLimitLoX      = $10;
  dmLimitLoY      = $20;
  dmLimitHiX      = $40;
  dmLimitHiY      = $80;
  dmLimitAll      = dmLimitLoX or dmLimitLoY or dmLimitHiX or dmLimitHiY;

  { help contexts }
  hcNoContext     = 0;
  hcDragging      = 1;

  { event masks combining several event kinds }
  positionalEvents = evMouse and not evMouseWheel;
  focusedEvents    = evKeyboard or evCommand;

type
  PView = ^TView;
  PGroup = ^TGroup;

  TCommandSet = set of Byte;

  { Element 0 holds the number of entries (a BIOS attribute); entries 1..N map a
    color index of a view to a color index of its owner (or, in the palette of the
    application, to a real color). }
  TPalette = array of TColorAttr;

  TPhaseType = (phFocused, phPreProcess, phPostProcess);
  TSelectMode = (normalSelect, enterSelect, leaveSelect);

  TForEachProc = procedure(P: PView; Args: Pointer);
  TNestedViewTest = function(P: PView): Boolean is nested;
  TNestedViewAction = procedure(P: PView) is nested;
  TFirstThatFunc = function(P: PView; Args: Pointer): Boolean;

  { a timer of DN: the time of the start and of the end in milliseconds (the fields of DN views) }
  TEventTimer = record
    StartMSecs, ExpireMSecs: LongInt;
  end;

  TView = object(TObject)
    Next: PView;
    Size: TPoint;
    Options: Word;
    EventMask: Word;
    State: Word;
    Origin: TPoint;
    Cursor: TPoint;
    GrowMode: Byte;
    DragMode: Byte;
    HelpCtx: Word;
    Owner: PGroup;
    ResizeBalance: TPoint;
    { the fields of DN: the interval of Update in milliseconds, its timer, a flag of the mouse events }
    UpdTicks: LongInt;
    UpTmr: TEventTimer;
    ClearPositionalEvents: Boolean;
    constructor Init(const Bounds: TRect);
    { Streams (the format is ours): a view is read back as it was stored, but not active, selected, focused,
      exposed. Load is called by the function of the stream record of the type (RView...). }
    constructor Load(var S: TStream);
    procedure Store(var S: TStream);
    { A pointer to another view of the same owner is stored as its number and made a pointer again when the
      owner has loaded all its views (the same for GetPeerViewPtr and GetSubViewPtr). P is a pointer variable. }
    procedure GetSubViewPtr(var S: TStream; var P);
    procedure PutSubViewPtr(var S: TStream; P: PView);
    procedure GetPeerViewPtr(var S: TStream; var P);
    procedure PutPeerViewPtr(var S: TStream; P: PView);
    { Called by the program from time to time for the views that asked for it (DN: RegisterToBackground). }
    procedure Update; virtual;
    { Hides the view and removes it from its owner. }
    destructor Done; virtual;
    procedure SizeLimits(out Min, Max: TPoint); virtual;
    function GetBounds: TRect; overload;
    function GetExtent: TRect; overload;
    function GetClipRect: TRect; overload;
    { The forms of Turbo Vision for Borland Pascal: the result goes to a variable. }
    procedure GetBounds(var R: TRect); overload;
    procedure GetExtent(var R: TRect); overload;
    procedure GetClipRect(var R: TRect); overload;
    function MouseInView(Mouse: TPoint): Boolean;
    function ContainsMouse(var Event: TEvent): Boolean;
    procedure Locate(var Bounds: TRect);
    { the command set as methods (Turbo Vision 2.0 has them; the unit procedures of the same names do the work) }
    procedure DisableCommands(const Commands: TCommandSet);
    procedure EnableCommands(const Commands: TCommandSet);
    procedure DisableCommand(Command: Word);
    procedure EnableCommand(Command: Word);
    procedure GetCommands(out Commands: TCommandSet);
    procedure SetCommands(const Commands: TCommandSet);
    { as CommandEnabled, but a command that the program has switched off for good (CommandHiddenHook) is not enabled }
    function MenuEnabled(Command: Word): Boolean;
    procedure DragView(var Event: TEvent; Mode: Byte; var Limits: TRect;
      MinSize, MaxSize: TPoint); virtual;
    procedure CalcBounds(var Bounds: TRect; Delta: TPoint); virtual;
    procedure ChangeBounds(const Bounds: TRect); virtual;
    procedure GrowTo(X, Y: Integer);
    procedure MoveTo(X, Y: Integer);
    procedure SetBounds(const Bounds: TRect);
    function GetHelpCtx: Word; virtual;
    function Valid(Command: Word): Boolean; virtual;
    procedure Hide;
    procedure Show;
    procedure Draw; virtual;
    procedure DrawView;
    function Exposed: Boolean;
    function Focus: Boolean;
    procedure HideCursor;
    procedure DrawHide(LastView: PView);
    procedure DrawShow(LastView: PView);
    procedure DrawUnderRect(var R: TRect; LastView: PView);
    procedure DrawUnderView(DoShadow: Boolean; LastView: PView);
    function DataSize: Integer; virtual;
    procedure GetData(var Rec); virtual;
    procedure SetData(var Rec); virtual;
    procedure Awaken; virtual;
    procedure BlockCursor;
    procedure NormalCursor;
    procedure ResetCursor; virtual;
    procedure SetCursor(X, Y: Integer);
    procedure ShowCursor;
    procedure DrawCursor;
    procedure ClearEvent(var Event: TEvent);
    function EventAvail: Boolean;
    procedure GetEvent(var Event: TEvent); virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure PutEvent(var Event: TEvent); virtual;
    procedure EndModal(Command: Word); virtual;
    function Execute: Word; virtual;
    function GetColor(Color: Word): TAttrPair;
    function GetPalette: TPalette; virtual;
    function MapColor(Index: Byte): TColorAttr; virtual;
    function GetState(AState: Word): Boolean;
    procedure Select;
    procedure SetState(AState: Word; Enable: Boolean); virtual;
    procedure KeyEvent(var Event: TEvent);
    function MouseEvent(var Event: TEvent; Mask: Word): Boolean;
    function MakeGlobal(Source: TPoint): TPoint; overload;
    function MakeLocal(Source: TPoint): TPoint; overload;
    procedure MakeGlobal(Source: TPoint; var Dest: TPoint); overload;
    procedure MakeLocal(Source: TPoint; var Dest: TPoint); overload;
    function NextView: PView;
    function PrevView: PView;
    function Prev: PView;
    procedure MakeFirst;
    procedure PutInFrontOf(Target: PView);
    function TopView: PView;
    { Timers: the group chain ends at the program, which owns the timer queue; a view
      outside a group has none (SetTimer returns nil). }
    function SetTimer(TimeoutMs: LongWord; PeriodMs: Integer = -1): TTimerId; virtual;
    procedure KillTimer(Id: TTimerId); virtual;
    { Writing into the view: coordinates are in the view, clipped to the part of
      the view that is visible. WriteBuf writes H rows of W cells, taken one
      after the other from B; WriteLine writes the same W cells to H rows. }
    procedure WriteBuf(X, Y, W, H: Integer; B: PScreenCell);
    procedure WriteBufD(X, Y, W, H: Integer; const B: TDrawBuffer);
    procedure WriteChar(X, Y: Integer; C: Byte; Color: Byte; Count: Integer);
    procedure WriteLine(X, Y, W, H: Integer; B: PScreenCell);
    procedure WriteLineD(X, Y, W, H: Integer; const B: TDrawBuffer);
    procedure WriteStr(X, Y: Integer; const Str: ShortString; Color: Byte);
    procedure WriteView(X, Y, Count: Integer; B: PScreenCell);
    { The 16-bit interface of Turbo Vision for Borland Pascal, for programs written for it: a cell is a Word
      (low byte: the character, high byte: the BIOS attribute) and a color is a BIOS attribute. B is an array
      of Word (WriteLineW takes W cells, WriteBufW H rows of them); GetColorW(C) = Lo + 256 * Hi of GetColor(C). }
    procedure WriteBufW(X, Y, W, H: Integer; const B);
    procedure WriteLineW(X, Y, W, H: Integer; const B);
    { The same for a row of cells of tv/ (an array of TScreenCell, as the draw buffers of DN are): B is the first cell, as for WriteBuf/WriteLine. }
    procedure WriteBufC(X, Y, W, H: Integer; const B);
    procedure WriteLineC(X, Y, W, H: Integer; const B);
    function GetColorW(Color: Word): Word;
  end;

  TGroup = object(TView)
    Last: PView;
    Clip: TRect;
    Phase: TPhaseType;
    Buffer: PScreenCell;
    LockFlag: Byte;
    EndState: Word;
    Current: PView;
    constructor Load(var S: TStream);
    procedure Store(var S: TStream);
    { Reads the number that PutSubViewPtr wrote and gives the view of this group (nil for 0). }
    function ReadChildPtr(var S: TStream): PView;
    { As in Borland TV: the number that PutSubViewPtr wrote gives a view of THIS group at once (a group that loads its own fields after
      "inherited Load" has all its views already; TView.GetSubViewPtr would only put the pointer into the list of fixups of an enclosing
      group, which no longer waits for it). P is a pointer variable. }
    procedure GetSubViewPtr(var S: TStream; var P);
    constructor Init(const Bounds: TRect);
    destructor Done; virtual;
    function ExecView(P: PView): Word;
    function Execute: Word; virtual;
    procedure Awaken; virtual;
    procedure InsertView(P, Target: PView);
    procedure Delete(P: PView);
    procedure RemoveView(P: PView);
    procedure ResetCurrent;
    procedure SetCurrent(P: PView; Mode: TSelectMode);
    procedure SelectNext(Forwards: Boolean);
    function FirstThat(Func: TFirstThatFunc; Args: Pointer): PView; overload;
    { The forms of Turbo Vision for Borland Pascal (a routine that is declared inside the caller is fine). }
    function FirstThat(Test: TNestedViewTest): PView; overload;
    function FocusNext(Forwards: Boolean): Boolean;
    procedure ForEach(Func: TForEachProc; Args: Pointer); overload;
    procedure ForEach(Action: TNestedViewAction); overload;
    procedure Insert(P: PView);
    procedure InsertBefore(P, Target: PView);
    function At(Index: Integer): PView;
    function FirstMatch(AState, AOptions: Word): PView;
    function IndexOf(P: PView): Integer;
    function First: PView;
    procedure SetState(AState: Word; Enable: Boolean); virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure DrawSubViews(P, Bottom: PView);
    procedure ChangeBounds(const Bounds: TRect); virtual;
    function DataSize: Integer; virtual;
    procedure GetData(var Rec); virtual;
    procedure SetData(var Rec); virtual;
    procedure Draw; virtual;
    procedure Redraw;
    procedure Lock;
    procedure Unlock;
    procedure ResetCursor; virtual;
    procedure EndModal(Command: Word); virtual;
    procedure EventError(var Event: TEvent); virtual;
    function GetHelpCtx: Word; virtual;
    function Valid(Command: Word): Boolean; virtual;
    procedure FreeBuffer;
    procedure GetBuffer;
  private
    function FindNext(Forwards: Boolean): PView;
    procedure FocusView(P: PView; Enable: Boolean);
    procedure SelectView(P: PView; Enable: Boolean);
  end;

var
  { the view being run modally by ExecView, if any }
  TheTopView: PView = nil;
  { the commands that are enabled; commands above 255 are always enabled }
  CurCommandSet: TCommandSet;
  CommandSetChanged: Boolean = False;
  ShowMarkers: Boolean = False;
  ErrorAttr: TColorAttr;

{ Commands (static members of TView in the C++ original). }
function CommandEnabled(Command: Word): Boolean;
procedure DisableCommands(const Commands: TCommandSet);
procedure EnableCommands(const Commands: TCommandSet);
procedure DisableCommand(Command: Word);
procedure EnableCommand(Command: Word);
procedure GetCommands(out Commands: TCommandSet);
procedure SetCommands(const Commands: TCommandSet);
procedure SetCmdState(const Commands: TCommandSet; Enable: Boolean);

{ Palettes. MakePalette builds a palette from a string of color indices, as the
  Pascal Turbo Vision's palette strings. }
function MakePalette(const S: ShortString): TPalette;
function PaletteSize(const P: TPalette): Integer;

{ Sends a message to a view: the view's HandleEvent gets an event with the
  command and Info; if the view cleared the event, its InfoPtr is returned. }
function Message(Receiver: PView; What, Command: Word; InfoPtr: Pointer): Pointer;

var
  { DN: the number of the modal views that are being executed (ExecView calls that have not returned) }
  ModalCount: Word = 0;
  { DN: the commands of the features that are not in the program are never enabled (TView.MenuEnabled) }
  CommandHiddenHook: function(Command: Word): Boolean = nil;
  { stream records: RegisterType(RView) makes TView known to the streams }
  RView, RGroup: TStreamRec;
  { called at the start of the destructor of every view (DN: the view leaves the list of the views that
    are updated in the background) }
  ViewDoneHook: procedure(P: PView) = nil;

implementation

{ ------------------------------------------------------------------------- }
{ Commands, palettes, message                                               }
{ ------------------------------------------------------------------------- }

procedure InitCommands;
var
  I: Integer;
begin
  CurCommandSet := [];
  for I := 0 to 255 do
    Include(CurCommandSet, I);
  Exclude(CurCommandSet, cmZoom);
  Exclude(CurCommandSet, cmClose);
  Exclude(CurCommandSet, cmResize);
  Exclude(CurCommandSet, cmNext);
  Exclude(CurCommandSet, cmPrev);
end;

function CommandEnabled(Command: Word): Boolean;
begin
  Result := (Command > 255) or (Byte(Command) in CurCommandSet);
end;

procedure DisableCommands(const Commands: TCommandSet);
begin
  CommandSetChanged := CommandSetChanged or ((CurCommandSet * Commands) <> []);
  CurCommandSet := CurCommandSet - Commands;
end;

procedure EnableCommands(const Commands: TCommandSet);
begin
  CommandSetChanged := CommandSetChanged or ((CurCommandSet * Commands) <> Commands);
  CurCommandSet := CurCommandSet + Commands;
end;

procedure DisableCommand(Command: Word);
begin
  if Command > 255 then
    Exit;
  CommandSetChanged := CommandSetChanged or (Byte(Command) in CurCommandSet);
  Exclude(CurCommandSet, Byte(Command));
end;

procedure EnableCommand(Command: Word);
begin
  if Command > 255 then
    Exit;
  CommandSetChanged := CommandSetChanged or not (Byte(Command) in CurCommandSet);
  Include(CurCommandSet, Byte(Command));
end;

procedure GetCommands(out Commands: TCommandSet);
begin
  Commands := CurCommandSet;
end;

procedure SetCommands(const Commands: TCommandSet);
begin
  CommandSetChanged := CommandSetChanged or (CurCommandSet <> Commands);
  CurCommandSet := Commands;
end;

procedure SetCmdState(const Commands: TCommandSet; Enable: Boolean);
begin
  if Enable then
    EnableCommands(Commands)
  else
    DisableCommands(Commands);
end;

function MakePalette(const S: ShortString): TPalette;
var
  I: Integer;
begin
  SetLength(Result, Length(S) + 1);
  Result[0] := AttrFromBIOS(Length(S));
  for I := 1 to Length(S) do
    Result[I] := AttrFromBIOS(Ord(S[I]));
end;

function PaletteSize(const P: TPalette): Integer;
begin
  Result := Length(P) - 1;
  if Result < 0 then
    Result := 0;
end;

function Message(Receiver: PView; What, Command: Word; InfoPtr: Pointer): Pointer;
var
  Event: TEvent;
begin
  if Receiver = nil then
    Exit(nil);
  ClearEvent(Event);
  Event.What := What;
  Event.Command := Command;
  Event.InfoPtr := InfoPtr;
  Receiver^.HandleEvent(Event);
  if Event.What = evNothing then
    Result := Event.InfoPtr
  else
    Result := nil;
end;

{ ------------------------------------------------------------------------- }
{ Arithmetic helpers of TView                                               }
{ ------------------------------------------------------------------------- }

function Range(Val, Min, Max: Integer): Integer;
begin
  if Min > Max then
    Min := Max;
  if Val < Min then
    Result := Min
  else if Val > Max then
    Result := Max
  else
    Result := Val;
end;

function BalancedRange(Val, Min, Max: Integer; var Balance: Integer): Integer;
var
  Offset: Integer;
begin
  if Min > Max then
    Max := Min;
  if Val < Min then
  begin
    Inc(Balance, Val - Min);
    Result := Min;
  end
  else if Val > Max then
  begin
    Inc(Balance, Val - Max);
    Result := Max;
  end
  else
  begin
    Offset := Range(Val + Balance, Min, Max) - Val;
    Dec(Balance, Offset);
    Result := Val + Offset;
  end;
end;

procedure FitToLimits(A: Integer; var B: Integer; Min, Max: Integer; var Balance: Integer);
begin
  B := A + BalancedRange(B - A, Min, Max, Balance);
end;

{ the C++ original divides and shifts as C does: truncating division and an
  arithmetic shift }
procedure GrowCoord(P: PView; S, D: Integer; var I: Integer);
begin
  if (P^.GrowMode and gfGrowRel) <> 0 then
  begin
    if S <> D then
      I := (I * S + SarLongint(S - D, 1)) div (S - D);
  end
  else
    Inc(I, D);
end;

function IMin(A, B: Integer): Integer; inline;
begin
  if A < B then Result := A else Result := B;
end;

function IMax(A, B: Integer): Integer; inline;
begin
  if A > B then Result := A else Result := B;
end;

{ ------------------------------------------------------------------------- }
{ The output engine (tvwrite.cpp)                                           }
{ ------------------------------------------------------------------------- }

type
  { state of one write: the part of the row still to be written is X..Count of
    the row Y, in the coordinates of the group being written to; Buffer[X - WOffset]
    is the cell for X; Edx counts the shadows the row passes through }
  TVWrite = record
    X, Y, Count, WOffset: Integer;
    Buffer: PScreenCell;
    Target: PView;
    Edx, Esi: Integer;
  end;

  TCellArray = array[0..MaxInt div SizeOf(TScreenCell) - 1] of TScreenCell;
  PCellArray = ^TCellArray;

procedure WriteL10(var W: TVWrite; Dest: PView); forward;
procedure WriteL20(var W: TVWrite; Dest: PView); forward;

function ApplyShadow(Attr: TColorAttr): TColorAttr;
var
  Style: Word;
begin
  { a style flag says whether the shadow has already been applied }
  Style := AttrStyle(Attr);
  if (Style and slWindowShadow) = 0 then
  begin
    if ColorToBIOS(AttrBg(Attr), False) = 0 then
      Attr := AttrReversed(ShadowAttr)    { reverse the shadow on black areas }
    else
      Attr := ShadowAttr;
    AttrSetStyle(Attr, Style or slWindowShadow);
  end;
  Result := Attr;
end;

procedure CopyCells(var W: TVWrite; Dst, Src: PCellArray);
var
  I: Integer;
  C: TScreenCell;
begin
  if W.Edx = 0 then
    Move(Src^, Dst^, SizeOf(TScreenCell) * (W.Count - W.X))
  else
    for I := 0 to W.Count - W.X - 1 do
    begin
      C := Src^[I];
      C.Attribute := ApplyShadow(C.Attribute);
      Dst^[I] := C;
    end;
end;

procedure WriteL50(var W: TVWrite; Owner: PGroup);
var
  Dst: PCellArray;
begin
  Dst := PCellArray(Owner^.Buffer + (W.Y * Owner^.Size.X + W.X));
  CopyCells(W, Dst, PCellArray(W.Buffer + (W.X - W.WOffset)));
  if Owner^.Buffer = ScreenBuffer then
    ScreenWrite(W.X, W.Y, PScreenCell(Dst), W.Count - W.X);
end;

procedure WriteL40(var W: TVWrite; Dest: PView);
var
  Owner: PGroup;
begin
  Owner := Dest^.Owner;
  if Owner^.Buffer <> nil then
    WriteL50(W, Owner);
  if Owner^.LockFlag = 0 then
    WriteL10(W, Owner);
end;

{ Runs the rest of the row through the views below Dest, with the row cut at
  Esi: used when a view covers the middle of the row. }
procedure WriteL30(var W: TVWrite; Dest: PView);
var
  SaveTarget: PView;
  SaveWOffset, SaveEsi, SaveEdx, SaveCount, SaveY: Integer;
begin
  SaveTarget := W.Target;
  SaveWOffset := W.WOffset;
  SaveEsi := W.Esi;
  SaveEdx := W.Edx;
  SaveCount := W.Count;
  SaveY := W.Y;
  W.Count := W.Esi;
  WriteL20(W, Dest);
  W.Y := SaveY;
  W.Count := SaveCount;
  W.Edx := SaveEdx;
  W.Esi := SaveEsi;
  W.WOffset := SaveWOffset;
  W.Target := SaveTarget;
  W.X := W.Esi;
end;

{ Walks the views that are above the target, from the topmost one down, cutting
  out the parts of the row they cover (and noting the shadows they cast). }
procedure WriteL20(var W: TVWrite; Dest: PView);
var
  Next: PView;
begin
  Next := Dest^.Next;
  if Next = W.Target then
  begin
    WriteL40(W, Next);
    Exit;
  end;
  if ((Next^.State and sfVisible) <> 0) and (Next^.Origin.Y <= W.Y) then
    repeat
      W.Esi := Next^.Origin.Y + Next^.Size.Y;
      if W.Y < W.Esi then
      begin
        W.Esi := Next^.Origin.X;
        if W.X < W.Esi then
        begin
          if W.Count > W.Esi then
            WriteL30(W, Next)
          else
            Break;
        end;
        Inc(W.Esi, Next^.Size.X);
        if W.X < W.Esi then
        begin
          if W.Count > W.Esi then
            W.X := W.Esi
          else
            Exit;
        end;
        if ((Next^.State and sfShadow) <> 0) and (Next^.Origin.Y + ShadowSize.Y <= W.Y) then
          Inc(W.Esi, ShadowSize.X)
        else
          Break;
      end
      else if ((Next^.State and sfShadow) <> 0) and (W.Y < W.Esi + ShadowSize.Y) then
      begin
        W.Esi := Next^.Origin.X + ShadowSize.X;
        if W.X < W.Esi then
        begin
          if W.Count > W.Esi then
            WriteL30(W, Next)
          else
            Break;
        end;
        Inc(W.Esi, Next^.Size.X);
      end
      else
        Break;
      if W.X < W.Esi then
      begin
        Inc(W.Edx);
        if W.Count > W.Esi then
        begin
          WriteL30(W, Next);
          Dec(W.Edx);
        end;
      end;
    until True;
  WriteL20(W, Next);
end;

{ Moves the write into the coordinates of the owner and clips it to the owner's
  clip rectangle. }
procedure WriteL10(var W: TVWrite; Dest: PView);
var
  Owner: PGroup;
begin
  Owner := Dest^.Owner;
  if ((Dest^.State and sfVisible) <> 0) and (Owner <> nil) then
  begin
    W.Target := Dest;
    Inc(W.Y, Dest^.Origin.Y);
    Inc(W.X, Dest^.Origin.X);
    Inc(W.Count, Dest^.Origin.X);
    Inc(W.WOffset, Dest^.Origin.X);
    if (Owner^.Clip.A.Y <= W.Y) and (W.Y < Owner^.Clip.B.Y) then
    begin
      if W.X < Owner^.Clip.A.X then
        W.X := Owner^.Clip.A.X;
      if W.Count > Owner^.Clip.B.X then
        W.Count := Owner^.Clip.B.X;
      if W.X < W.Count then
        WriteL20(W, Owner^.Last);
    end;
  end;
end;

procedure WriteL0(var W: TVWrite; Dest: PView; AX, AY, ACount: Integer; B: PScreenCell);
begin
  W.X := AX;
  W.Y := AY;
  W.Count := ACount;
  W.Buffer := B;
  W.WOffset := W.X;
  Inc(W.Count, W.X);
  W.Edx := 0;
  W.Esi := 0;
  W.Target := nil;
  if (0 <= W.Y) and (W.Y < Dest^.Size.Y) then
  begin
    if W.X < 0 then
      W.X := 0;
    if W.Count > Dest^.Size.X then
      W.Count := Dest^.Size.X;
    if W.X < W.Count then
      WriteL10(W, Dest);
  end;
end;

{ ------------------------------------------------------------------------- }
{ The visibility test (tvexposd.cpp)                                        }
{ ------------------------------------------------------------------------- }

type
  { Row Eax (in the coordinates of the current owner), columns Ebx..Ecx }
  TVExposd = record
    Eax, Ebx, Ecx, Esi: Integer;
    Target: PView;
  end;

function ExposdL11(var E: TVExposd; Dest: PView): Boolean; forward;
function ExposdL20(var E: TVExposd; Dest: PView): Boolean; forward;

function ExposdL10(var E: TVExposd; Dest: PView): Boolean;
var
  Owner: PGroup;
begin
  Owner := Dest^.Owner;
  if (Owner^.Buffer <> nil) or (Owner^.LockFlag <> 0) then
    Exit(False);
  Result := ExposdL11(E, Owner);
end;

function ExposdL23(var E: TVExposd; Next: PView): Boolean;
var
  SaveTarget: PView;
  SaveEsi, SaveEcx, SaveEax: Integer;
  B: Boolean;
begin
  SaveTarget := E.Target;
  SaveEsi := E.Esi;
  SaveEcx := E.Ecx;
  SaveEax := E.Eax;
  E.Ecx := Next^.Origin.X;
  B := ExposdL20(E, Next);
  E.Eax := SaveEax;
  E.Ecx := SaveEcx;
  E.Ebx := SaveEsi;
  E.Target := SaveTarget;
  if B then
    Result := ExposdL20(E, Next)
  else
    Result := False;
end;

function ExposdL22(var E: TVExposd; Next: PView): Boolean;
begin
  if E.Ecx <= E.Esi then
    Exit(ExposdL20(E, Next));
  Inc(E.Esi, Next^.Size.X);
  if E.Ecx > E.Esi then
    Exit(ExposdL23(E, Next));
  E.Ecx := Next^.Origin.X;
  Result := ExposdL20(E, Next);
end;

function ExposdL21(var E: TVExposd; Next: PView): Boolean;
begin
  if (Next^.State and sfVisible) = 0 then
    Exit(ExposdL20(E, Next));
  E.Esi := Next^.Origin.Y;
  if E.Eax < E.Esi then
    Exit(ExposdL20(E, Next));
  Inc(E.Esi, Next^.Size.Y);
  if E.Eax >= E.Esi then
    Exit(ExposdL20(E, Next));
  E.Esi := Next^.Origin.X;
  if E.Ebx < E.Esi then
    Exit(ExposdL22(E, Next));
  Inc(E.Esi, Next^.Size.X);
  if E.Ebx >= E.Esi then
    Exit(ExposdL20(E, Next));
  E.Ebx := E.Esi;
  if E.Ebx < E.Ecx then
    Exit(ExposdL20(E, Next));
  Result := True;
end;

function ExposdL20(var E: TVExposd; Dest: PView): Boolean;
var
  Next: PView;
begin
  Next := Dest^.Next;
  if Next = E.Target then
    Result := ExposdL10(E, Next)
  else
    Result := ExposdL21(E, Next);
end;

function ExposdL13(var E: TVExposd; Owner: PGroup): Boolean;
begin
  if E.Ebx >= E.Ecx then
    Exit(True);
  Result := ExposdL20(E, Owner^.Last);
end;

function ExposdL12(var E: TVExposd; Owner: PGroup): Boolean;
begin
  if E.Ecx > Owner^.Clip.B.X then
    E.Ecx := Owner^.Clip.B.X;
  Result := ExposdL13(E, Owner);
end;

function ExposdL11(var E: TVExposd; Dest: PView): Boolean;
var
  Owner: PGroup;
begin
  E.Target := Dest;
  Inc(E.Eax, Dest^.Origin.Y);
  Inc(E.Ebx, Dest^.Origin.X);
  Inc(E.Ecx, Dest^.Origin.X);
  Owner := Dest^.Owner;
  if Owner = nil then
    Exit(False);
  if E.Eax < Owner^.Clip.A.Y then
    Exit(True);
  if E.Eax >= Owner^.Clip.B.Y then
    Exit(True);
  if E.Ebx < Owner^.Clip.A.X then
    E.Ebx := Owner^.Clip.A.X;
  Result := ExposdL12(E, Owner);
end;

{ True when some cell of the view can be seen: it is exposed, and for some row
  a part of the row is not covered by the views above it nor clipped away. }
function ViewExposed(Dest: PView): Boolean;
var
  E: TVExposd;
  I: Integer;
begin
  if (Dest^.State and sfExposed) = 0 then
    Exit(False);
  if (Dest^.Size.X <= 0) or (Dest^.Size.Y <= 0) then
    Exit(False);
  FillChar(E, SizeOf(E), 0);
  for I := 0 to Dest^.Size.Y - 1 do
  begin
    E.Eax := I;
    E.Ebx := 0;
    E.Ecx := Dest^.Size.X;
    if not ExposdL11(E, Dest) then
      Exit(True);
  end;
  Result := False;
end;

{ ------------------------------------------------------------------------- }
{ The caret (tvcursor.cpp)                                                  }
{ ------------------------------------------------------------------------- }

function DecideCaretSize(P: PView): Integer;
begin
  if (P^.State and sfCursorIns) <> 0 then
    Result := 100
  else
    Result := CursorLines and $FF;
end;

function CaretIsCoveredBySiblings(P: PView; X, Y: Integer): Boolean;
var
  U: PView;
begin
  U := P^.Owner^.Last^.Next;
  while U <> P do
  begin
    if ((U^.State and sfVisible) <> 0)
      and (U^.Origin.Y <= Y) and (Y < U^.Origin.Y + U^.Size.Y)
      and (U^.Origin.X <= X) and (X < U^.Origin.X + U^.Size.X) then
      Exit(True);
    U := U^.Next;
  end;
  Result := False;
end;

function ComputeCaretSize(P: PView; var X, Y: Integer): Integer;
var
  Mask: Word;
  V: PView;
begin
  Mask := sfVisible or sfCursorVis or sfFocused;
  if (P^.State and Mask) <> Mask then
    Exit(0);
  V := P;
  while (0 <= Y) and (Y < V^.Size.Y) and (0 <= X) and (X < V^.Size.X) do
  begin
    Inc(Y, V^.Origin.Y);
    Inc(X, V^.Origin.X);
    if V^.Owner = nil then
      Exit(DecideCaretSize(P));
    if ((V^.Owner^.State and sfVisible) = 0) or CaretIsCoveredBySiblings(V, X, Y) then
      Break;
    V := V^.Owner;
  end;
  Result := 0;
end;

{ ------------------------------------------------------------------------- }
{ TView                                                                      }
{ ------------------------------------------------------------------------- }

constructor TView.Init(const Bounds: TRect);
begin
  inherited Init;       { zeroes all the fields, also those of the descendants }
  Next := nil;
  Options := 0;
  EventMask := evMouseDown or evKeyDown or evCommand;
  State := sfVisible;
  GrowMode := 0;
  DragMode := dmLimitLoY;
  HelpCtx := hcNoContext;
  Owner := nil;
  SetBounds(Bounds);
  Cursor.X := 0;
  Cursor.Y := 0;
  ResizeBalance.X := 0;
  ResizeBalance.Y := 0;
end;

destructor TView.Done;
begin
  if Assigned(ViewDoneHook) then
    ViewDoneHook(@Self);
  Hide;
  if Owner <> nil then
    Owner^.Delete(@Self);
  inherited Done;
end;

procedure TView.Awaken;
begin
end;

procedure TView.BlockCursor;
begin
  SetState(sfCursorIns, True);
end;

procedure TView.CalcBounds(var Bounds: TRect; Delta: TPoint);
var
  S, D: Integer;
  MinLim, MaxLim: TPoint;
begin
  Bounds := GetBounds;
  S := Owner^.Size.X;
  D := Delta.X;
  if (GrowMode and gfGrowLoX) <> 0 then
    GrowCoord(@Self, S, D, Bounds.A.X);
  if (GrowMode and gfGrowHiX) <> 0 then
    GrowCoord(@Self, S, D, Bounds.B.X);
  S := Owner^.Size.Y;
  D := Delta.Y;
  if (GrowMode and gfGrowLoY) <> 0 then
    GrowCoord(@Self, S, D, Bounds.A.Y);
  if (GrowMode and gfGrowHiY) <> 0 then
    GrowCoord(@Self, S, D, Bounds.B.Y);
  SizeLimits(MinLim, MaxLim);
  FitToLimits(Bounds.A.X, Bounds.B.X, MinLim.X, MaxLim.X, ResizeBalance.X);
  FitToLimits(Bounds.A.Y, Bounds.B.Y, MinLim.Y, MaxLim.Y, ResizeBalance.Y);
end;

procedure TView.ChangeBounds(const Bounds: TRect);
begin
  SetBounds(Bounds);
  DrawView;
end;

procedure TView.ClearEvent(var Event: TEvent);
begin
  Event.What := evNothing;
  Event.InfoPtr := @Self;
end;

function TView.ContainsMouse(var Event: TEvent): Boolean;
begin
  Result := ((State and sfVisible) <> 0) and MouseInView(Event.Where);
end;

function TView.DataSize: Integer;
begin
  Result := 0;
end;

procedure TView.DisableCommands(const Commands: TCommandSet);
begin
  TvViews.DisableCommands(Commands);
end;

procedure TView.EnableCommands(const Commands: TCommandSet);
begin
  TvViews.EnableCommands(Commands);
end;

procedure TView.DisableCommand(Command: Word);
begin
  TvViews.DisableCommand(Command);
end;

procedure TView.EnableCommand(Command: Word);
begin
  TvViews.EnableCommand(Command);
end;

procedure TView.GetCommands(out Commands: TCommandSet);
begin
  TvViews.GetCommands(Commands);
end;

procedure TView.SetCommands(const Commands: TCommandSet);
begin
  TvViews.SetCommands(Commands);
end;

function TView.MenuEnabled(Command: Word): Boolean;
begin
  if Assigned(CommandHiddenHook) and CommandHiddenHook(Command) then
    Result := False
  else
    Result := (Command > 255) or (Byte(Command) in CurCommandSet);
end;

procedure TView.DragView(var Event: TEvent; Mode: Byte; var Limits: TRect;
  MinSize, MaxSize: TPoint);
var
  SaveBounds, Bounds: TRect;
  P, S: TPoint;

  procedure MoveGrow(P, S: TPoint);
  var
    R: TRect;
  begin
    S.X := IMin(IMax(S.X, MinSize.X), MaxSize.X);
    S.Y := IMin(IMax(S.Y, MinSize.Y), MaxSize.Y);
    P.X := IMin(IMax(P.X, Limits.A.X - S.X + 1), Limits.B.X - 1);
    P.Y := IMin(IMax(P.Y, Limits.A.Y - S.Y + 1), Limits.B.Y - 1);
    if (Mode and dmLimitLoX) <> 0 then P.X := IMax(P.X, Limits.A.X);
    if (Mode and dmLimitLoY) <> 0 then P.Y := IMax(P.Y, Limits.A.Y);
    if (Mode and dmLimitHiX) <> 0 then P.X := IMin(P.X, Limits.B.X - S.X);
    if (Mode and dmLimitHiY) <> 0 then P.Y := IMin(P.Y, Limits.B.Y - S.Y);
    R.Assign(P.X, P.Y, P.X + S.X, P.Y + S.Y);
    Locate(R);
  end;

  procedure Change(DX, DY: Integer);
  begin
    if ((Mode and dmDragMove) <> 0) and ((Event.ControlKeyState and kbShift) = 0) then
    begin
      Inc(P.X, DX);
      Inc(P.Y, DY);
    end
    else if ((Mode and dmDragGrow) <> 0) and ((Event.ControlKeyState and kbShift) <> 0) then
    begin
      Inc(S.X, DX);
      Inc(S.Y, DY);
    end;
  end;

begin
  SetState(sfDragging, True);
  if Event.What = evMouseDown then
  begin
    if (Mode and dmDragMove) <> 0 then
    begin
      P := PointSub(Origin, Event.Where);
      repeat
        Event.Where := PointAdd(Event.Where, P);
        MoveGrow(Event.Where, Size);
      until not MouseEvent(Event, evMouseMove);
    end
    else if (Mode and dmDragGrow) <> 0 then
    begin
      P := PointSub(Size, Event.Where);
      repeat
        Event.Where := PointAdd(Event.Where, P);
        MoveGrow(Origin, Event.Where);
      until not MouseEvent(Event, evMouseMove);
    end
    else
    begin
      { dmDragGrowLeft }
      Bounds := GetBounds;
      S := Origin;
      Inc(S.Y, Size.Y);
      P := PointSub(S, Event.Where);
      repeat
        Event.Where := PointAdd(Event.Where, P);
        Bounds.A.X := IMin(IMax(Event.Where.X, Bounds.B.X - MaxSize.X), Bounds.B.X - MinSize.X);
        Bounds.B.Y := Event.Where.Y;
        MoveGrow(Bounds.A, PointSub(Bounds.B, Bounds.A));
      until not MouseEvent(Event, evMouseMove);
    end;
  end
  else
  begin
    SaveBounds := GetBounds;
    repeat
      P := Origin;
      S := Size;
      KeyEvent(Event);
      case Event.KeyCode and $FF00 of
        kbLeft:      Change(-1, 0);
        kbRight:     Change(1, 0);
        kbUp:        Change(0, -1);
        kbDown:      Change(0, 1);
        kbCtrlLeft:  Change(-8, 0);
        kbCtrlRight: Change(8, 0);
        kbCtrlUp:    Change(0, -4);
        kbCtrlDown:  Change(0, 4);
        kbHome:      P.X := Limits.A.X;
        kbEnd:       P.X := Limits.B.X - S.X;
        kbPgUp:      P.Y := Limits.A.Y;
        kbPgDn:      P.Y := Limits.B.Y - S.Y;
      end;
      MoveGrow(P, S);
    until (Event.KeyCode = kbEsc) or (Event.KeyCode = kbEnter);
    if Event.KeyCode = kbEsc then
      Locate(SaveBounds);
  end;
  SetState(sfDragging, False);
end;

procedure TView.Draw;
var
  B: TDrawBuffer;
  Pair: TAttrPair;
begin
  B.Init(IMax(ScreenWidth, ScreenHeight));
  Pair := GetColor(1);
  B.MoveChar(0, Ord(' '), Pair.Lo, Size.X);
  WriteLineD(0, 0, Size.X, Size.Y, B);
  B.Done;
end;

procedure TView.DrawCursor;
begin
  if (State and sfFocused) <> 0 then
    ResetCursor;
end;

procedure TView.DrawHide(LastView: PView);
begin
  DrawCursor;
  DrawUnderView((State and sfShadow) <> 0, LastView);
end;

procedure TView.DrawShow(LastView: PView);
begin
  DrawView;
  if (State and sfShadow) <> 0 then
    DrawUnderView(True, LastView);
end;

procedure TView.DrawUnderRect(var R: TRect; LastView: PView);
begin
  Owner^.Clip.Intersect(R);
  Owner^.DrawSubViews(NextView, LastView);
  Owner^.Clip := Owner^.GetExtent;
end;

procedure TView.DrawUnderView(DoShadow: Boolean; LastView: PView);
var
  R: TRect;
begin
  R := GetBounds;
  if DoShadow then
    R.B := PointAdd(R.B, ShadowSize);
  if (Options and ofFramed) <> 0 then
    R.Grow(1, 1);
  DrawUnderRect(R, LastView);
end;

procedure TView.DrawView;
begin
  if Exposed then
  begin
    Draw;
    DrawCursor;
  end;
end;

function TView.EventAvail: Boolean;
var
  Event: TEvent;
begin
  GetEvent(Event);
  if Event.What <> evNothing then
    PutEvent(Event);
  Result := Event.What <> evNothing;
end;

procedure TView.EndModal(Command: Word);
begin
  if TopView <> nil then
    TopView^.EndModal(Command);
end;

function TView.Exposed: Boolean;
begin
  Result := ViewExposed(@Self);
end;

function TView.Execute: Word;
begin
  Result := cmCancel;
end;

function TView.Focus: Boolean;
begin
  Result := True;
  if (State and (sfSelected or sfModal)) = 0 then
    if Owner <> nil then
    begin
      Result := Owner^.Focus;
      if Result then
      begin
        if (Owner^.Current = nil)
          or ((Owner^.Current^.Options and ofValidate) = 0)
          or Owner^.Current^.Valid(cmReleasedFocus) then
          Select
        else
          Result := False;
      end;
    end;
end;

procedure TView.GetBounds(var R: TRect);
begin
  R := GetBounds;
end;

procedure TView.GetExtent(var R: TRect);
begin
  R := GetExtent;
end;

procedure TView.GetClipRect(var R: TRect);
begin
  R := GetClipRect;
end;

procedure TView.MakeGlobal(Source: TPoint; var Dest: TPoint);
begin
  Dest := MakeGlobal(Source);
end;

procedure TView.MakeLocal(Source: TPoint; var Dest: TPoint);
begin
  Dest := MakeLocal(Source);
end;

function TView.GetBounds: TRect;
begin
  Result.A := Origin;
  Result.B := PointAdd(Origin, Size);
end;

function TView.GetClipRect: TRect;
begin
  Result := GetBounds;
  if Owner <> nil then
    Result.Intersect(Owner^.Clip);
  Result.Move(-Origin.X, -Origin.Y);
end;

function TView.GetColor(Color: Word): TAttrPair;
begin
  Result.Lo := MapColor(Color and $FF);
  if (Color and $FF00) <> 0 then
    Result.Hi := MapColor(Color shr 8)
  else
    Result.Hi := AttrFromBIOS(0);
end;

procedure TView.GetData(var Rec);
begin
end;

procedure TView.GetEvent(var Event: TEvent);
begin
  if Owner <> nil then
    Owner^.GetEvent(Event);
end;

function TView.GetExtent: TRect;
begin
  Result.Assign(0, 0, Size.X, Size.Y);
end;

function TView.GetHelpCtx: Word;
begin
  if (State and sfDragging) <> 0 then
    Result := hcDragging
  else
    Result := HelpCtx;
end;

function TView.GetPalette: TPalette;
begin
  Result := nil;
end;

function TView.GetState(AState: Word): Boolean;
begin
  Result := (State and AState) = AState;
end;

procedure TView.GrowTo(X, Y: Integer);
var
  R: TRect;
begin
  R.Assign(Origin.X, Origin.Y, Origin.X + X, Origin.Y + Y);
  Locate(R);
end;

procedure TView.HandleEvent(var Event: TEvent);
begin
  if Event.What = evMouseDown then
    if ((State and (sfSelected or sfDisabled)) = 0) and ((Options and ofSelectable) <> 0) then
      if (not Focus) or ((Options and ofFirstClick) = 0) then
        ClearEvent(Event);
end;

procedure TView.Hide;
begin
  if (State and sfVisible) <> 0 then
    SetState(sfVisible, False);
end;

procedure TView.HideCursor;
begin
  SetState(sfCursorVis, False);
end;

procedure TView.KeyEvent(var Event: TEvent);
begin
  repeat
    GetEvent(Event);
  until Event.What = evKeyDown;
end;

procedure TView.Locate(var Bounds: TRect);
var
  Min, Max: TPoint;
  R: TRect;
begin
  SizeLimits(Min, Max);
  Bounds.B.X := Bounds.A.X + Range(Bounds.B.X - Bounds.A.X, Min.X, Max.X);
  Bounds.B.Y := Bounds.A.Y + Range(Bounds.B.Y - Bounds.A.Y, Min.Y, Max.Y);
  R := GetBounds;
  if not Bounds.Equals(R) then
  begin
    ChangeBounds(Bounds);
    if (Owner <> nil) and ((State and sfVisible) <> 0) then
    begin
      if (State and sfShadow) <> 0 then
      begin
        R.Union(Bounds);
        R.B := PointAdd(R.B, ShadowSize);
      end;
      DrawUnderRect(R, nil);
    end;
  end;
end;

procedure TView.MakeFirst;
begin
  PutInFrontOf(Owner^.First);
end;

function TView.MakeGlobal(Source: TPoint): TPoint;
var
  Cur: PView;
begin
  Result := PointAdd(Source, Origin);
  Cur := @Self;
  while Cur^.Owner <> nil do
  begin
    Cur := Cur^.Owner;
    Result := PointAdd(Result, Cur^.Origin);
  end;
end;

function TView.MakeLocal(Source: TPoint): TPoint;
var
  Cur: PView;
begin
  Result := PointSub(Source, Origin);
  Cur := @Self;
  while Cur^.Owner <> nil do
  begin
    Cur := Cur^.Owner;
    Result := PointSub(Result, Cur^.Origin);
  end;
end;

function TView.MapColor(Index: Byte): TColorAttr;
var
  P: TPalette;
  Color: TColorAttr;
begin
  P := GetPalette;
  if PaletteSize(P) <> 0 then
  begin
    if (Index > 0) and (Index <= PaletteSize(P)) then
      Color := P[Index]
    else
      Exit(ErrorAttr);
  end
  else
    Color := AttrFromBIOS(Index);
  if AttrEq(Color, AttrFromBIOS(0)) then
    Exit(ErrorAttr);
  if Owner <> nil then
    Result := Owner^.MapColor(AttrAsBIOSByte(Color))
  else
    Result := Color;
end;

function TView.MouseEvent(var Event: TEvent; Mask: Word): Boolean;
begin
  repeat
    GetEvent(Event);
  until (Event.What and (Mask or evMouseUp)) <> 0;
  Result := Event.What <> evMouseUp;
end;

function TView.MouseInView(Mouse: TPoint): Boolean;
var
  R: TRect;
begin
  Mouse := MakeLocal(Mouse);
  R := GetExtent;
  Result := R.Contains(Mouse);
end;

procedure TView.MoveTo(X, Y: Integer);
var
  R: TRect;
begin
  R.Assign(X, Y, X + Size.X, Y + Size.Y);
  Locate(R);
end;

function TView.NextView: PView;
begin
  if @Self = Owner^.Last then
    Result := nil
  else
    Result := Next;
end;

procedure TView.NormalCursor;
begin
  SetState(sfCursorIns, False);
end;

function TView.Prev: PView;
begin
  Result := @Self;
  while Result^.Next <> @Self do
    Result := Result^.Next;
end;

function TView.PrevView: PView;
begin
  if @Self = Owner^.First then
    Result := nil
  else
    Result := Prev;
end;

procedure TView.PutEvent(var Event: TEvent);
begin
  if Owner <> nil then
    Owner^.PutEvent(Event);
end;

procedure TView.PutInFrontOf(Target: PView);
var
  P, LastView: PView;
begin
  if (Owner <> nil) and (Target <> @Self) and (Target <> NextView)
    and ((Target = nil) or (Target^.Owner = Owner)) then
  begin
    if (State and sfVisible) = 0 then
    begin
      Owner^.RemoveView(@Self);
      Owner^.InsertView(@Self, Target);
    end
    else
    begin
      LastView := NextView;
      P := Target;
      while (P <> nil) and (P <> @Self) do
        P := P^.NextView;
      if P = nil then
        LastView := Target;
      State := State and not sfVisible;
      if LastView = Target then
        DrawHide(LastView);
      Owner^.RemoveView(@Self);
      Owner^.InsertView(@Self, Target);
      State := State or sfVisible;
      if LastView <> Target then
        DrawShow(LastView);
      if (Options and ofSelectable) <> 0 then
        Owner^.ResetCurrent;
    end;
  end;
end;

procedure TView.ResetCursor;
var
  X, Y, CaretSize: Integer;
begin
  X := Cursor.X;
  Y := Cursor.Y;
  CaretSize := ComputeCaretSize(@Self, X, Y);
  if CaretSize <> 0 then
    SetCaretPosition(X, Y);
  SetCaretSize(CaretSize);
end;

procedure TView.Select;
begin
  if ((Options and ofSelectable) <> 0) and (Owner <> nil) then
  begin
    if (Options and ofTopSelect) <> 0 then
      MakeFirst
    else
      Owner^.SetCurrent(@Self, normalSelect);
  end;
end;

procedure TView.SetBounds(const Bounds: TRect);
begin
  Origin := Bounds.A;
  Size := PointSub(Bounds.B, Bounds.A);
end;

procedure TView.SetCursor(X, Y: Integer);
begin
  Cursor.X := X;
  Cursor.Y := Y;
  DrawCursor;
end;

procedure TView.SetData(var Rec);
begin
end;

procedure TView.SetState(AState: Word; Enable: Boolean);
begin
  if Enable then
    State := State or AState
  else
    State := State and not AState;
  if Owner = nil then
    Exit;
  case AState of
    sfVisible:
    begin
      if (Owner^.State and sfExposed) <> 0 then
        SetState(sfExposed, Enable);
      if Enable then
        DrawShow(nil)
      else
        DrawHide(nil);
      if (Options and ofSelectable) <> 0 then
        Owner^.ResetCurrent;
    end;
    sfCursorVis, sfCursorIns:
      DrawCursor;
    sfShadow:
      DrawUnderView(True, nil);
    sfFocused:
    begin
      ResetCursor;
      if Enable then
        Message(Owner, evBroadcast, cmReceivedFocus, @Self)
      else
        Message(Owner, evBroadcast, cmReleasedFocus, @Self);
    end;
  end;
end;

procedure TView.Show;
begin
  if (State and sfVisible) = 0 then
    SetState(sfVisible, True);
end;

procedure TView.ShowCursor;
begin
  SetState(sfCursorVis, True);
end;

procedure TView.SizeLimits(out Min, Max: TPoint);
begin
  Min.X := 0;
  Min.Y := 0;
  if ((GrowMode and gfFixed) = 0) and (Owner <> nil) then
    Max := Owner^.Size
  else
  begin
    Max.X := MaxInt;
    Max.Y := MaxInt;
  end;
end;

function TView.SetTimer(TimeoutMs: LongWord; PeriodMs: Integer): TTimerId;
begin
  if Owner <> nil then
    Result := Owner^.SetTimer(TimeoutMs, PeriodMs)
  else
    Result := nil;
end;

procedure TView.KillTimer(Id: TTimerId);
begin
  if Owner <> nil then
    Owner^.KillTimer(Id);
end;

function TView.TopView: PView;
begin
  if TheTopView <> nil then
    Result := TheTopView
  else
  begin
    Result := @Self;
    while (Result <> nil) and ((Result^.State and sfModal) = 0) do
      Result := PView(Result^.Owner);
  end;
end;

function TView.Valid(Command: Word): Boolean;
begin
  Result := True;
end;

procedure TView.WriteView(X, Y, Count: Integer; B: PScreenCell);
var
  W: TVWrite;
begin
  WriteL0(W, @Self, X, Y, Count, B);
end;

procedure TView.WriteBuf(X, Y, W, H: Integer; B: PScreenCell);
begin
  while H > 0 do
  begin
    WriteView(X, Y, W, B);
    Inc(Y);
    Inc(B, W);
    Dec(H);
  end;
end;

procedure TView.WriteBufD(X, Y, W, H: Integer; const B: TDrawBuffer);
begin
  WriteBuf(X, Y, IMin(W, B.Capacity - X), H, B.Data);
end;

procedure TView.WriteLine(X, Y, W, H: Integer; B: PScreenCell);
begin
  while H > 0 do
  begin
    WriteView(X, Y, W, B);
    Inc(Y);
    Dec(H);
  end;
end;

procedure TView.WriteLineD(X, Y, W, H: Integer; const B: TDrawBuffer);
begin
  WriteLine(X, Y, IMin(W, B.Capacity - X), H, B.Data);
end;

procedure TView.WriteBufW(X, Y, W, H: Integer; const B);
var
  Src: PWord;
  Buf: PScreenCell;
  I: Integer;
begin
  if (W <= 0) or (H <= 0) then
    Exit;
  Src := @B;
  GetMem(Buf, W * SizeOf(TScreenCell));
  while H > 0 do
  begin
    for I := 0 to W - 1 do
      Buf[I] := CellFromBIOS(Src[I]);
    WriteView(X, Y, W, Buf);
    Inc(Y);
    Inc(Src, W);
    Dec(H);
  end;
  FreeMem(Buf);
end;

procedure TView.WriteLineW(X, Y, W, H: Integer; const B);
var
  Src: PWord;
  Buf: PScreenCell;
  I: Integer;
begin
  if (W <= 0) or (H <= 0) then
    Exit;
  Src := @B;
  GetMem(Buf, W * SizeOf(TScreenCell));
  for I := 0 to W - 1 do
    Buf[I] := CellFromBIOS(Src[I]);
  while H > 0 do
  begin
    WriteView(X, Y, W, Buf);
    Inc(Y);
    Dec(H);
  end;
  FreeMem(Buf);
end;

procedure TView.WriteBufC(X, Y, W, H: Integer; const B);
begin
  WriteBuf(X, Y, W, H, PScreenCell(@B));
end;

procedure TView.WriteLineC(X, Y, W, H: Integer; const B);
begin
  WriteLine(X, Y, W, H, PScreenCell(@B));
end;

function TView.GetColorW(Color: Word): Word;
var
  P: TAttrPair;
begin
  P := GetColor(Color);
  Result := AttrAsBIOSByte(P.Lo) or (Word(AttrAsBIOSByte(P.Hi)) shl 8);
end;

procedure TView.WriteChar(X, Y: Integer; C: Byte; Color: Byte; Count: Integer);
var
  Buf: PScreenCell;
  Attr: TColorAttr;
begin
  if Count > Size.X then
    Count := Size.X;
  if Count > 0 then
  begin
    GetMem(Buf, Count * SizeOf(TScreenCell));
    Attr := MapColor(Color);
    TextDrawChar(Buf, Count, C, @Attr);
    WriteView(X, Y, Count, Buf);
    FreeMem(Buf);
  end;
end;

procedure TView.WriteStr(X, Y: Integer; const Str: ShortString; Color: Byte);
var
  Buf: PScreenCell;
  Attr: TColorAttr;
  Count: Integer;
begin
  Count := TextWidthS(Str);
  if Count > Size.X then
    Count := Size.X;
  if Count > 0 then
  begin
    GetMem(Buf, Count * SizeOf(TScreenCell));
    FillChar(Buf^, Count * SizeOf(TScreenCell), 0);
    Attr := MapColor(Color);
    TextDrawStrS(Buf, Count, 0, Str, 0, @Attr);
    WriteView(X, Y, Count, Buf);
    FreeMem(Buf);
  end;
end;

{ ------------------------------------------------------------------------- }
{ TGroup                                                                     }
{ ------------------------------------------------------------------------- }

constructor TGroup.Init(const Bounds: TRect);
begin
  inherited Init(Bounds);
  Current := nil;
  Last := nil;
  Phase := phFocused;
  Buffer := nil;
  LockFlag := 0;
  EndState := 0;
  Options := Options or ofSelectable or ofBuffered;
  Clip := GetExtent;
  EventMask := $FFFF;
end;

destructor TGroup.Done;
var
  P: PView;
begin
  Hide;
  P := Last;
  if P <> nil then
  begin
    repeat
      P^.Hide;
      P := P^.Prev;
    until P = Last;
    { the top view is disposed again and again, not a view that was taken before: the Done of a view may dispose another
      view of the group (DN: a panel disposes its info panel), which would leave the remembered one dangling }
    while Last <> nil do
      Dispose(Last, Done);
  end;
  FreeBuffer;
  Current := nil;
  inherited Done;
end;

procedure DoCalcChange(P: PView; D: Pointer);
var
  R: TRect;
begin
  P^.CalcBounds(R, PPoint(D)^);
  P^.ChangeBounds(R);
end;

procedure DoAwaken(V: PView; Args: Pointer);
begin
  V^.Awaken;
end;

procedure TGroup.Awaken;
begin
  ForEach(@DoAwaken, nil);
end;

procedure TGroup.ChangeBounds(const Bounds: TRect);
var
  D: TPoint;
begin
  D.X := (Bounds.B.X - Bounds.A.X) - Size.X;
  D.Y := (Bounds.B.Y - Bounds.A.Y) - Size.Y;
  if (D.X = 0) and (D.Y = 0) then
  begin
    SetBounds(Bounds);
    DrawView;
  end
  else
  begin
    SetBounds(Bounds);
    Clip := GetExtent;
    GetBuffer;
    Lock;
    ForEach(@DoCalcChange, @D);
    Unlock;
  end;
end;

procedure AddSubviewDataSize(P: PView; T: Pointer);
begin
  Inc(PInteger(T)^, P^.DataSize);
end;

function TGroup.DataSize: Integer;
var
  T: Integer;
begin
  T := 0;
  ForEach(@AddSubviewDataSize, @T);
  Result := T;
end;

procedure TGroup.Delete(P: PView);
var
  SaveState: Word;
begin
  if P <> nil then
  begin
    SaveState := P^.State;
    P^.Hide;
    RemoveView(P);
    P^.Owner := nil;
    P^.Next := nil;
    if (SaveState and sfVisible) <> 0 then
      P^.Show;
  end;
end;

procedure TGroup.Draw;
begin
  if Buffer = nil then
  begin
    GetBuffer;
    if Buffer <> nil then
    begin
      Inc(LockFlag);
      Redraw;
      Dec(LockFlag);
    end;
  end;
  if Buffer <> nil then
    WriteBuf(0, 0, Size.X, Size.Y, Buffer)
  else
  begin
    Clip := GetClipRect;
    Redraw;
    Clip := GetExtent;
  end;
end;

procedure TGroup.DrawSubViews(P, Bottom: PView);
begin
  while P <> Bottom do
  begin
    P^.DrawView;
    P := P^.NextView;
  end;
end;

procedure TGroup.EndModal(Command: Word);
begin
  if (State and sfModal) <> 0 then
    EndState := Command
  else
    inherited EndModal(Command);
end;

procedure TGroup.EventError(var Event: TEvent);
begin
  if Owner <> nil then
    Owner^.EventError(Event);
end;

function TGroup.Execute: Word;
var
  E: TEvent;
begin
  repeat
    EndState := 0;
    repeat
      GetEvent(E);
      HandleEvent(E);
      if E.What <> evNothing then
        EventError(E);
    until EndState <> 0;
  until Valid(EndState);
  Result := EndState;
end;

function TGroup.ExecView(P: PView): Word;
var
  SaveOptions: Word;
  SaveOwner: PGroup;
  SaveTopView, SaveCurrent: PView;
  SaveCommands: TCommandSet;
begin
  if P = nil then
    Exit(cmCancel);
  SaveOptions := P^.Options;
  SaveOwner := P^.Owner;
  SaveTopView := TheTopView;
  SaveCurrent := Current;
  GetCommands(SaveCommands);
  TheTopView := P;
  P^.Options := P^.Options and not ofSelectable;
  P^.SetState(sfModal, True);
  SetCurrent(P, enterSelect);
  if SaveOwner = nil then
    Insert(P);
  Inc(ModalCount);
  Result := P^.Execute;
  Dec(ModalCount);
  if SaveOwner = nil then
    Delete(P);
  SetCurrent(SaveCurrent, leaveSelect);
  P^.SetState(sfModal, False);
  P^.Options := SaveOptions;
  TheTopView := SaveTopView;
  SetCommands(SaveCommands);
end;

function TGroup.First: PView;
begin
  if Last = nil then
    Result := nil
  else
    Result := Last^.Next;
end;

function TGroup.FindNext(Forwards: Boolean): PView;
var
  P: PView;
begin
  Result := nil;
  if Current <> nil then
  begin
    P := Current;
    repeat
      if Forwards then
        P := P^.Next
      else
        P := P^.Prev;
    until (((P^.State and (sfVisible or sfDisabled)) = sfVisible)
      and ((P^.Options and ofSelectable) <> 0)) or (P = Current);
    if P <> Current then
      Result := P;
  end;
end;

function TGroup.FocusNext(Forwards: Boolean): Boolean;
var
  P: PView;
begin
  P := FindNext(Forwards);
  if P <> nil then
    Result := P^.Focus
  else
    Result := True;
end;

function TGroup.FirstMatch(AState, AOptions: Word): PView;
var
  Temp: PView;
begin
  if Last = nil then
    Exit(nil);
  Temp := Last;
  while True do
  begin
    if ((Temp^.State and AState) = AState) and ((Temp^.Options and AOptions) = AOptions) then
      Exit(Temp);
    Temp := Temp^.Next;
    if Temp = Last then
      Exit(nil);
  end;
end;

procedure TGroup.FreeBuffer;
begin
  if ((Options and ofBuffered) <> 0) and (Buffer <> nil) then
  begin
    FreeMem(Buffer);
    Buffer := nil;
  end;
end;

procedure TGroup.GetBuffer;
var
  Sz: Integer;
begin
  if (State and sfExposed) <> 0 then
    if (Options and ofBuffered) <> 0 then
    begin
      Sz := Size.X * Size.Y * SizeOf(TScreenCell);
      if Sz < 0 then
        Sz := 0;
      if Buffer <> nil then
        FreeMem(Buffer);
      Buffer := nil;
      if Sz > 0 then
      begin
        GetMem(Buffer, Sz);
        FillChar(Buffer^, Sz, 0);
      end;
    end;
end;

procedure TGroup.GetData(var Rec);
var
  I: Integer;
  V: PView;
begin
  I := 0;
  if Last <> nil then
  begin
    V := Last;
    repeat
      V^.GetData((PByte(@Rec) + I)^);
      Inc(I, V^.DataSize);
      V := V^.Prev;
    until V = Last;
  end;
end;

type
  THandleStruct = record
    Event: ^TEvent;
    Grp: PGroup;
  end;
  PHandleStruct = ^THandleStruct;

procedure DoHandleEvent(P: PView; S: Pointer);
var
  Ptr: PHandleStruct;
begin
  Ptr := PHandleStruct(S);
  if (P = nil)
    or (((P^.State and sfDisabled) <> 0)
      and ((Ptr^.Event^.What and (positionalEvents or focusedEvents)) <> 0)) then
    Exit;
  case Ptr^.Grp^.Phase of
    phFocused: ;
    phPreProcess:
      if (P^.Options and ofPreProcess) = 0 then
        Exit;
    phPostProcess:
      if (P^.Options and ofPostProcess) = 0 then
        Exit;
  end;
  if (Ptr^.Event^.What and P^.EventMask) <> 0 then
    P^.HandleEvent(Ptr^.Event^);
end;

function HasMouse(P: PView; S: Pointer): Boolean;
begin
  Result := P^.ContainsMouse(PEvent(S)^);
end;

procedure TGroup.HandleEvent(var Event: TEvent);
var
  HS: THandleStruct;
begin
  inherited HandleEvent(Event);
  HS.Event := @Event;
  HS.Grp := @Self;
  if (Event.What and focusedEvents) <> 0 then
  begin
    Phase := phPreProcess;
    ForEach(@DoHandleEvent, @HS);
    Phase := phFocused;
    DoHandleEvent(Current, @HS);
    Phase := phPostProcess;
    ForEach(@DoHandleEvent, @HS);
  end
  else if Event.What <> 0 then
  begin
    Phase := phFocused;
    if (Event.What and positionalEvents) <> 0 then
      DoHandleEvent(FirstThat(@HasMouse, @Event), @HS)
    else
      ForEach(@DoHandleEvent, @HS);
  end;
end;

function TGroup.At(Index: Integer): PView;
begin
  Result := Last;
  while Index > 0 do
  begin
    Result := Result^.Next;
    Dec(Index);
  end;
end;

function TGroup.FirstThat(Func: TFirstThatFunc; Args: Pointer): PView;
var
  Temp: PView;
begin
  Temp := Last;
  if Temp = nil then
    Exit(nil);
  repeat
    Temp := Temp^.Next;
    if Func(Temp, Args) then
      Exit(Temp);
  until Temp = Last;
  Result := nil;
end;

procedure TGroup.ForEach(Func: TForEachProc; Args: Pointer);
var
  Term, Temp, NextV: PView;
begin
  Term := Last;
  Temp := Last;
  if Temp = nil then
    Exit;
  NextV := Temp^.Next;
  repeat
    Temp := NextV;
    NextV := Temp^.Next;
    Func(Temp, Args);
  until Temp = Term;
end;

function TGroup.FirstThat(Test: TNestedViewTest): PView;
var
  Temp: PView;
begin
  Temp := Last;
  if Temp = nil then
    Exit(nil);
  repeat
    Temp := Temp^.Next;
    if Test(Temp) then
      Exit(Temp);
  until Temp = Last;
  Result := nil;
end;

procedure TGroup.ForEach(Action: TNestedViewAction);
var
  Term, Temp, NextV: PView;
begin
  Term := Last;
  Temp := Last;
  if Temp = nil then
    Exit;
  NextV := Temp^.Next;
  repeat
    Temp := NextV;
    NextV := Temp^.Next;
    Action(Temp);
  until Temp = Term;
end;

function TGroup.IndexOf(P: PView): Integer;
var
  Temp: PView;
begin
  if Last = nil then
    Exit(0);
  Result := 0;
  Temp := Last;
  repeat
    Inc(Result);
    Temp := Temp^.Next;
  until (Temp = P) or (Temp = Last);
  if Temp <> P then
    Result := 0;
end;

procedure TGroup.Insert(P: PView);
begin
  InsertBefore(P, First);
end;

procedure TGroup.InsertBefore(P, Target: PView);
var
  SaveState: Word;
begin
  if (P <> nil) and (P^.Owner = nil) and ((Target = nil) or (Target^.Owner = @Self)) then
  begin
    if (P^.Options and ofCenterX) <> 0 then
      P^.Origin.X := (Size.X - P^.Size.X) div 2;
    if (P^.Options and ofCenterY) <> 0 then
      P^.Origin.Y := (Size.Y - P^.Size.Y) div 2;
    SaveState := P^.State;
    P^.Hide;
    InsertView(P, Target);
    if (SaveState and sfVisible) <> 0 then
      P^.Show;
    if (SaveState and sfActive) <> 0 then
      P^.SetState(sfActive, True);
  end;
end;

procedure TGroup.InsertView(P, Target: PView);
begin
  P^.Owner := @Self;
  if Target <> nil then
  begin
    Target := Target^.Prev;
    P^.Next := Target^.Next;
    Target^.Next := P;
  end
  else
  begin
    if Last = nil then
      P^.Next := P
    else
    begin
      P^.Next := Last^.Next;
      Last^.Next := P;
    end;
    Last := P;
  end;
end;

procedure TGroup.Lock;
begin
  if (Buffer <> nil) or (LockFlag <> 0) then
    Inc(LockFlag);
end;

procedure TGroup.Redraw;
begin
  DrawSubViews(First, nil);
end;

procedure TGroup.RemoveView(P: PView);
var
  S: PView;
begin
  if Last <> nil then
  begin
    S := Last;
    while S^.Next <> P do
    begin
      if S^.Next = Last then
        Exit;
      S := S^.Next;
    end;
    S^.Next := P^.Next;
    if P = Last then
    begin
      if P = P^.Next then
        Last := nil
      else
        Last := S;
    end;
  end;
end;

procedure TGroup.ResetCurrent;
begin
  SetCurrent(FirstMatch(sfVisible, ofSelectable), normalSelect);
end;

procedure TGroup.ResetCursor;
begin
  if Current <> nil then
    Current^.ResetCursor;
end;

procedure TGroup.SelectNext(Forwards: Boolean);
var
  P: PView;
begin
  if Current <> nil then
  begin
    P := FindNext(Forwards);
    if P <> nil then
      P^.Select;
  end;
end;

procedure TGroup.SelectView(P: PView; Enable: Boolean);
begin
  if P <> nil then
    P^.SetState(sfSelected, Enable);
end;

procedure TGroup.FocusView(P: PView; Enable: Boolean);
begin
  if ((State and sfFocused) <> 0) and (P <> nil) then
    P^.SetState(sfFocused, Enable);
end;

procedure TGroup.SetCurrent(P: PView; Mode: TSelectMode);
begin
  if Current <> P then
  begin
    Lock;
    FocusView(Current, False);
    if Mode <> enterSelect then
      if Current <> nil then
        Current^.SetState(sfSelected, False);
    if Mode <> leaveSelect then
      if P <> nil then
        P^.SetState(sfSelected, True);
    if ((State and sfFocused) <> 0) and (P <> nil) then
      P^.SetState(sfFocused, True);
    Current := P;
    Unlock;
  end;
end;

procedure TGroup.SetData(var Rec);
var
  I: Integer;
  V: PView;
begin
  I := 0;
  if Last <> nil then
  begin
    V := Last;
    repeat
      V^.SetData((PByte(@Rec) + I)^);
      Inc(I, V^.DataSize);
      V := V^.Prev;
    until V = Last;
  end;
end;

procedure DoExpose(P: PView; Enable: Pointer);
begin
  if (P^.State and sfVisible) <> 0 then
    P^.SetState(sfExposed, PBoolean(Enable)^);
end;

type
  TSetBlock = record
    St: Word;
    En: Boolean;
  end;
  PSetBlock = ^TSetBlock;

procedure DoSetState(P: PView; B: Pointer);
begin
  P^.SetState(PSetBlock(B)^.St, PSetBlock(B)^.En);
end;

procedure TGroup.SetState(AState: Word; Enable: Boolean);
var
  SB: TSetBlock;
begin
  SB.St := AState;
  SB.En := Enable;
  inherited SetState(AState, Enable);
  if (AState and (sfActive or sfDragging)) <> 0 then
  begin
    Lock;
    ForEach(@DoSetState, @SB);
    Unlock;
  end;
  if (AState and sfFocused) <> 0 then
  begin
    if Current <> nil then
      Current^.SetState(sfFocused, Enable);
  end;
  if (AState and sfExposed) <> 0 then
  begin
    ForEach(@DoExpose, @Enable);
    if not Enable then
      FreeBuffer;
  end;
end;

procedure TGroup.Unlock;
begin
  if LockFlag <> 0 then
  begin
    Dec(LockFlag);
    if LockFlag = 0 then
      DrawView;
  end;
end;

function IsInvalid(P: PView; Command: Pointer): Boolean;
begin
  Result := not P^.Valid(PWord(Command)^);
end;

function TGroup.Valid(Command: Word): Boolean;
begin
  if Command = cmReleasedFocus then
  begin
    if (Current <> nil) and ((Current^.Options and ofValidate) <> 0) then
      Result := Current^.Valid(Command)
    else
      Result := True;
  end
  else
    Result := FirstThat(@IsInvalid, @Command) = nil;
end;

function TGroup.GetHelpCtx: Word;
var
  H: Word;
begin
  H := hcNoContext;
  if Current <> nil then
    H := Current^.GetHelpCtx;
  if H = hcNoContext then
    H := inherited GetHelpCtx;
  Result := H;
end;


{ --- Streams ------------------------------------------------------------------ }

type
  TViewStore = packed record
    Origin, Size, Cursor: TPoint;
    GrowMode, DragMode: Byte;
    HelpCtx, State, Options, EventMask: Word;
  end;

  TFixup = record
    Target: PPointer;
    Index: Integer;
  end;

var
  Fixups: array of TFixup;

constructor TView.Load(var S: TStream);
var
  R: TViewStore;
begin
  inherited Init;
  S.Read(R, SizeOf(R));
  Origin := R.Origin;
  Size := R.Size;
  Cursor := R.Cursor;
  GrowMode := R.GrowMode;
  DragMode := R.DragMode;
  HelpCtx := R.HelpCtx;
  State := R.State;
  Options := R.Options;
  EventMask := R.EventMask;
  Owner := nil;
  Next := nil;
  ResizeBalance.X := 0;
  ResizeBalance.Y := 0;
end;

procedure TView.Store(var S: TStream);
var
  R: TViewStore;
begin
  R.Origin := Origin;
  R.Size := Size;
  R.Cursor := Cursor;
  R.GrowMode := GrowMode;
  R.DragMode := DragMode;
  R.HelpCtx := HelpCtx;
  R.State := State and not (sfActive or sfSelected or sfFocused or sfExposed);
  R.Options := Options;
  R.EventMask := EventMask;
  S.Write(R, SizeOf(R));
end;

procedure TView.GetSubViewPtr(var S: TStream; var P);
var
  Index: Word;
begin
  S.Read(Index, SizeOf(Index));
  Pointer(P) := nil;
  if Index = 0 then
    Exit;
  SetLength(Fixups, Length(Fixups) + 1);
  Fixups[High(Fixups)].Target := @Pointer(P);
  Fixups[High(Fixups)].Index := Index;
end;

procedure TView.PutSubViewPtr(var S: TStream; P: PView);
var
  Index: Word;
begin
  if (P = nil) or (P^.Owner = nil) then
    Index := 0
  else
    Index := P^.Owner^.IndexOf(P);
  S.Write(Index, SizeOf(Index));
end;

procedure TView.GetPeerViewPtr(var S: TStream; var P);
begin
  GetSubViewPtr(S, P);
end;

procedure TView.PutPeerViewPtr(var S: TStream; P: PView);
begin
  PutSubViewPtr(S, P);
end;

procedure TView.Update;
begin
end;

constructor TGroup.Load(var S: TStream);
var
  Base, I: Integer;
  Count: Word;
  P: PView;
begin
  inherited Load(S);
  Last := nil;
  Current := nil;
  Phase := phFocused;
  Buffer := nil;
  LockFlag := 0;
  EndState := 0;
  Clip := GetExtent;
  Base := Length(Fixups);
  S.Read(Count, SizeOf(Count));
  for I := 1 to Count do
  begin
    P := PView(S.Get);
    if P <> nil then
      InsertView(P, nil);
  end;
  { as in Borland (SetCurrent(V, NormalSelect)): the current view is selected, else it does not take the keys (a dialog loaded from a
    resource: the input line had the focus but not sfSelected) }
  SetCurrent(ReadChildPtr(S), NormalSelect);
  { the views of this group that pointed to each other get their pointers }
  for I := Base to High(Fixups) do
    if (Fixups[I].Index >= 1) and (Fixups[I].Index <= Count) then
      Fixups[I].Target^ := At(Fixups[I].Index);
  SetLength(Fixups, Base);
  Awaken;
end;

function TGroup.ReadChildPtr(var S: TStream): PView;
var
  Index: Word;
begin
  S.Read(Index, SizeOf(Index));
  if Index = 0 then
    Result := nil
  else
    Result := At(Index);
end;

procedure TGroup.GetSubViewPtr(var S: TStream; var P);
begin
  Pointer(P) := ReadChildPtr(S);
end;

procedure TGroup.Store(var S: TStream);
var
  Count: Word;
  P: PView;
begin
  inherited Store(S);
  Count := 0;
  if Last <> nil then
  begin
    P := Last;
    repeat
      Inc(Count);
      P := P^.Next;
    until P = Last;
  end;
  S.Write(Count, SizeOf(Count));
  if Last <> nil then
  begin
    P := Last^.Next;                   { the first view: the lowest }
    repeat
      S.Put(P);
      P := P^.Next;
    until P = Last^.Next;
  end;
  PutSubViewPtr(S, Current);
end;

{ the stream records of the types (the numbers are those of Turbo Vision) }
function BuildView(var S: TStream): PObject;
begin
  Result := New(PView, Load(S));
end;

procedure StoreView(P: PObject; var S: TStream);
begin
  PView(P)^.Store(S);
end;

function BuildGroup(var S: TStream): PObject;
begin
  Result := New(PGroup, Load(S));
end;

procedure StoreGroup(P: PObject; var S: TStream);
begin
  PGroup(P)^.Store(S);
end;

initialization
  RView.ObjType := 1;
  RView.VmtLink := PtrUInt(TypeOf(TView));
  RView.Load := @BuildView;
  RView.Store := @StoreView;
  RGroup.ObjType := 6;
  RGroup.VmtLink := PtrUInt(TypeOf(TGroup));
  RGroup.Load := @BuildGroup;
  RGroup.Store := @StoreGroup;
  InitCommands;
  ErrorAttr := AttrFromBIOS($CF);
end.
