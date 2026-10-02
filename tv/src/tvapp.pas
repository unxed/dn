{ TvApp: the application: desktop, background, TProgram and TApplication.

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/app.h, source/tvision/tprogram.cpp, tapplica.cpp, tdesktop.cpp,
    tbkgrnd.cpp, tvtext2.cpp (defaultBkgrnd, exitText)
  Borland disclaimer and MIT notice: tv/COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/DESIGN.md):
    - the desktop, menu bar and status line are created by the virtual methods
      InitDeskTop, InitMenuBar and InitStatusLine, which set the variables DeskTop,
      MenuBar and StatusLine (as in the Pascal Turbo Vision);
    - the variables of the class (Application, StatusLine, ...) are variables of the unit;
    - events come from the hooks of TvSys (a backend) instead of TEventQueue; the screen
      and the clock too;
    - there is no LowMemory check (an allocation that fails raises an exception);
    - the dialog of ExecuteDialog is any view (TDialog is not translated yet);
    - streams are not translated yet. }
unit TvApp;

{$I tvdefs.inc}

interface

uses
  SysUtils, TvGeom, TvColors, TvCell, TvKeys, TvEvents, TvDrawBuf, TvScreen, TvViews,
  TvWindow, TvMenus, TvUtil, TvSys, TvTimer;

const
  { help contexts of the standard commands }
  hcNew       = $FF01;
  hcOpen      = $FF02;
  hcSave      = $FF03;
  hcSaveAs    = $FF04;
  hcSaveAll   = $FF05;
  hcChangeDir = $FF06;
  hcDosShell  = $FF07;
  hcExit      = $FF08;
  hcUndo      = $FF10;
  hcCut       = $FF11;
  hcCopy      = $FF12;
  hcPaste     = $FF13;
  hcClear     = $FF14;
  hcTile      = $FF20;
  hcCascade   = $FF21;
  hcCloseAll  = $FF22;
  hcResize    = $FF23;
  hcZoom      = $FF24;
  hcNext      = $FF25;
  hcPrev      = $FF26;
  hcClose     = $FF27;

  { application palettes }
  apColor      = 0;
  apBlackWhite = 1;
  apMonochrome = 2;

  ExitText = '~Alt-X~ Exit';
  DefaultBackground = $B0;     { CP437 light shade }

type
  PBackground = ^TBackground;
  PDeskTop = ^TDeskTop;
  PProgram = ^TProgram;

  { Palette: 1 = background }
  TBackground = object(TView)
    Pattern: Byte;
    constructor Init(const Bounds: TRect; APattern: Byte);
    procedure Draw; virtual;
    function GetPalette: TPalette; virtual;
  end;

  TDeskTop = object(TGroup)
    Background: PBackground;
    TileColumnsFirst: Boolean;
    constructor Init(const Bounds: TRect);
    destructor Done; virtual;
    procedure Cascade(const R: TRect);
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure InitBackground; virtual;
    procedure Tile(const R: TRect);
    { Called when the windows do not fit the rectangle. }
    procedure TileError; virtual;
  end;

  TProgram = object(TGroup)
    constructor Init;
    destructor Done; virtual;
    function CanMoveFocus: Boolean; virtual;
    function ExecuteDialog(P: PView; Data: Pointer): Word; virtual;
    procedure GetEvent(var Event: TEvent); virtual;
    function GetPalette: TPalette; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure Idle; virtual;
    procedure InitDeskTop; virtual;
    procedure InitMenuBar; virtual;
    procedure InitScreen; virtual;
    procedure InitStatusLine; virtual;
    procedure OutOfMemory; virtual;
    procedure PutEvent(var Event: TEvent); virtual;
    procedure Run; virtual;
    function InsertWindow(P: PWindow): PWindow; virtual;
    procedure SetScreenMode(Mode: Word);
    function ValidView(P: PView): PView;
    { Timers send cmTimerExpired (InfoPtr = the timer id) to the program. }
    function SetTimer(TimeoutMs: LongWord; PeriodMs: Integer = -1): TTimerId; virtual;
    procedure KillTimer(Id: TTimerId); virtual;
    procedure Suspend; virtual;
    procedure Resume; virtual;
  end;

  PApplication = ^TApplication;
  TApplication = object(TProgram)
    constructor Init;
    destructor Done; virtual;
    procedure Suspend; virtual;
    procedure Resume; virtual;
    procedure Cascade;
    procedure DosShell;
    function GetTileRect: TRect; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure Tile;
    procedure WriteShellMsg; virtual;
  end;

var
  Application: PProgram = nil;
  StatusLine: PStatusLine = nil;
  MenuBar: PMenuBar = nil;
  DeskTop: PDeskTop = nil;
  AppPalette: Integer = apColor;
  { DN: the palettes of the program by AppPalette (apColor, apBlackWhite, apMonochrome) as strings of attributes; the
    program can change them (the colors dialog); they start as the palettes of Turbo Vision }
  SystemColors: array[0..2] of ShortString;
  { how long the program waits for an event before it calls Idle, in ms (-1: until
    something happens) }
  EventTimeoutMs: Integer = 20;

implementation

const
  BackgroundPalette = #1;

{$I tvapppal.inc}

var
  Pending: TEvent;
  TimerQueue: TTimerQueue;

{ --- TBackground ------------------------------------------------------------- }

constructor TBackground.Init(const Bounds: TRect; APattern: Byte);
begin
  inherited Init(Bounds);
  Pattern := APattern;
  GrowMode := gfGrowHiX or gfGrowHiY;
end;

procedure TBackground.Draw;
var
  B: TDrawBuffer;
begin
  B.Init(Size.X);
  B.MoveChar(0, Pattern, GetColor($01).Lo, Size.X);
  WriteLineD(0, 0, Size.X, Size.Y, B);
  B.Done;
end;

function TBackground.GetPalette: TPalette;
begin
  Result := MakePalette(BackgroundPalette);
end;

{ --- TDeskTop ---------------------------------------------------------------- }

constructor TDeskTop.Init(const Bounds: TRect);
begin
  inherited Init(Bounds);
  GrowMode := gfGrowHiX or gfGrowHiY;
  TileColumnsFirst := False;
  Background := nil;
  InitBackground;
  if Background <> nil then
    Insert(Background);
end;

destructor TDeskTop.Done;
begin
  Background := nil;
  inherited Done;
end;

procedure TDeskTop.InitBackground;
var
  R: TRect;
begin
  R := GetExtent;
  New(Background, Init(R, DefaultBackground));
end;

function Tileable(P: PView): Boolean;
begin
  Result := ((P^.Options and ofTileable) <> 0) and ((P^.State and sfVisible) <> 0);
end;

var
  CascadeNum: Integer;
  LastView: PView;

procedure DoCount(P: PView; Args: Pointer);
begin
  if Tileable(P) then
  begin
    Inc(CascadeNum);
    LastView := P;
  end;
end;

procedure DoCascade(P: PView; R: Pointer);
var
  NR: TRect;
begin
  if Tileable(P) and (CascadeNum >= 0) then
  begin
    NR := PRect(R)^;
    Inc(NR.A.X, CascadeNum);
    Inc(NR.A.Y, CascadeNum);
    P^.Locate(NR);
    Dec(CascadeNum);
  end;
end;

procedure TDeskTop.Cascade(const R: TRect);
var
  Min, Max: TPoint;
begin
  CascadeNum := 0;
  ForEach(@DoCount, nil);
  if CascadeNum > 0 then
  begin
    LastView^.SizeLimits(Min, Max);
    if (Min.X > R.B.X - R.A.X - CascadeNum) or (Min.Y > R.B.Y - R.A.Y - CascadeNum) then
      TileError
    else
    begin
      Dec(CascadeNum);
      Lock;
      ForEach(@DoCascade, @R);
      Unlock;
    end;
  end;
end;

procedure TDeskTop.HandleEvent(var Event: TEvent);
begin
  inherited HandleEvent(Event);
  if Event.What = evCommand then
  begin
    case Event.Command of
      cmNext:
        if Valid(cmReleasedFocus) then
          SelectNext(False);
      cmPrev:
        if Valid(cmReleasedFocus) then
          Current^.PutInFrontOf(Background);
    else
      Exit;
    end;
    ClearEvent(Event);
  end;
end;

function ISqr(I: Integer): Integer;
var
  Res1, Res2: Integer;
begin
  Res1 := 2;
  Res2 := I div Res1;
  while Abs(Res1 - Res2) > 1 do
  begin
    Res1 := (Res1 + Res2) div 2;
    Res2 := I div Res1;
  end;
  if Res1 < Res2 then
    Result := Res1
  else
    Result := Res2;
end;

procedure MostEqualDivisors(N: Integer; var X, Y: Integer; FavorY: Boolean);
var
  I: Integer;
begin
  I := ISqr(N);
  if N mod I <> 0 then
    if N mod (I + 1) = 0 then
      Inc(I);
  if I < (N div I) then
    I := N div I;
  if FavorY then
  begin
    X := N div I;
    Y := I;
  end
  else
  begin
    Y := N div I;
    X := I;
  end;
end;

var
  NumCols, NumRows, NumTileable, LeftOver, TileNum: Integer;

procedure DoCountTileable(P: PView; Args: Pointer);
begin
  if Tileable(P) then
    Inc(NumTileable);
end;

function DividerLoc(Lo, Hi, Num, Pos: Integer): Integer;
begin
  Result := Integer(Int64(Hi - Lo) * Pos div Num + Lo);
end;

function CalcTileRect(Pos: Integer; const R: TRect): TRect;
var
  X, Y, D: Integer;
begin
  D := (NumCols - LeftOver) * NumRows;
  if Pos < D then
  begin
    X := Pos div NumRows;
    Y := Pos mod NumRows;
  end
  else
  begin
    X := (Pos - D) div (NumRows + 1) + (NumCols - LeftOver);
    Y := (Pos - D) mod (NumRows + 1);
  end;
  Result.A.X := DividerLoc(R.A.X, R.B.X, NumCols, X);
  Result.B.X := DividerLoc(R.A.X, R.B.X, NumCols, X + 1);
  if Pos >= D then
  begin
    Result.A.Y := DividerLoc(R.A.Y, R.B.Y, NumRows + 1, Y);
    Result.B.Y := DividerLoc(R.A.Y, R.B.Y, NumRows + 1, Y + 1);
  end
  else
  begin
    Result.A.Y := DividerLoc(R.A.Y, R.B.Y, NumRows, Y);
    Result.B.Y := DividerLoc(R.A.Y, R.B.Y, NumRows, Y + 1);
  end;
end;

procedure DoTile(P: PView; LR: Pointer);
var
  R: TRect;
begin
  if Tileable(P) then
  begin
    R := CalcTileRect(TileNum, PRect(LR)^);
    P^.Locate(R);
    Dec(TileNum);
  end;
end;

procedure TDeskTop.Tile(const R: TRect);
begin
  NumTileable := 0;
  ForEach(@DoCountTileable, nil);
  if NumTileable > 0 then
  begin
    MostEqualDivisors(NumTileable, NumCols, NumRows, not TileColumnsFirst);
    if ((R.B.X - R.A.X) div NumCols = 0) or ((R.B.Y - R.A.Y) div NumRows = 0) then
      TileError
    else
    begin
      LeftOver := NumTileable mod NumCols;
      TileNum := NumTileable - 1;
      Lock;
      ForEach(@DoTile, @R);
      Unlock;
    end;
  end;
end;

procedure TDeskTop.TileError;
begin
end;

{ --- TProgram ---------------------------------------------------------------- }

constructor TProgram.Init;
var
  R: TRect;
begin
  R.Assign(0, 0, ScreenWidth, ScreenHeight);
  inherited Init(R);
  Application := @Self;
  InitScreen;
  State := sfVisible or sfSelected or sfFocused or sfModal or sfExposed;
  Options := 0;
  Buffer := ScreenBuffer;
  DeskTop := nil;
  StatusLine := nil;
  MenuBar := nil;
  InitDeskTop;
  if DeskTop <> nil then
    Insert(DeskTop);
  InitStatusLine;
  if StatusLine <> nil then
    Insert(StatusLine);
  InitMenuBar;
  if MenuBar <> nil then
    Insert(MenuBar);
end;

destructor TProgram.Done;
begin
  StatusLine := nil;
  MenuBar := nil;
  DeskTop := nil;
  inherited Done;
  Application := nil;
end;

function TProgram.CanMoveFocus: Boolean;
begin
  Result := DeskTop^.Valid(cmReleasedFocus);
end;

function EventWaitTimeout: Integer;
var
  TimerTimeout: Integer;
begin
  TimerTimeout := TimerQueue.TimeUntilNextTimeout;
  if TimerTimeout < 0 then
    Exit(EventTimeoutMs);
  if EventTimeoutMs < 0 then
    Exit(TimerTimeout);
  if EventTimeoutMs < TimerTimeout then
    Result := EventTimeoutMs
  else
    Result := TimerTimeout;
end;

function TProgram.ExecuteDialog(P: PView; Data: Pointer): Word;
var
  C: Word;
begin
  C := cmCancel;
  if ValidView(P) <> nil then
  begin
    if Data <> nil then
      P^.SetData(Data^);
    C := DeskTop^.ExecView(P);
    if (C <> cmCancel) and (Data <> nil) then
      P^.GetData(Data^);
    Dispose(P, Done);
  end;
  Result := C;
end;

function ViewHasMouse(P: PView; S: Pointer): Boolean;
begin
  Result := ((P^.State and sfVisible) <> 0) and P^.MouseInView(PEvent(S)^.Where);
end;

procedure TProgram.GetEvent(var Event: TEvent);
begin
  if Pending.What <> evNothing then
  begin
    Event := Pending;
    Pending.What := evNothing;
  end
  else
  begin
    PollEvent(EventWaitTimeout, Event);
    if Event.What = evNothing then
      Idle;
  end;
  if StatusLine <> nil then
  begin
    if ((Event.What and evKeyDown) <> 0) or
      (((Event.What and evMouseDown) <> 0) and (FirstThat(@ViewHasMouse, @Event) = PView(StatusLine))) then
      StatusLine^.HandleEvent(Event);
  end;
  if (Event.What = evCommand) and (Event.Command = cmScreenChanged) then
  begin
    SetScreenMode(smUpdate);
    ClearEvent(Event);
  end;
end;

function TProgram.GetPalette: TPalette;
begin
  case AppPalette of
    apBlackWhite: Result := MakePalette(SystemColors[apBlackWhite]);
    apMonochrome: Result := MakePalette(SystemColors[apMonochrome]);
  else
    Result := MakePalette(SystemColors[apColor]);
  end;
end;

procedure TProgram.HandleEvent(var Event: TEvent);
var
  C: Char;
begin
  if Event.What = evKeyDown then
  begin
    C := GetAltChar(Event.KeyCode);
    if (C >= '1') and (C <= '9') then
    begin
      if CanMoveFocus then
      begin
        if Message(DeskTop, evBroadcast, cmSelectWindowNum, Pointer(PtrUInt(Ord(C) - Ord('0')))) <> nil then
          ClearEvent(Event);
      end
      else
        ClearEvent(Event);
    end;
  end;
  inherited HandleEvent(Event);
  if (Event.What = evCommand) and (Event.Command = cmQuit) then
  begin
    EndModal(cmQuit);
    ClearEvent(Event);
  end;
end;

procedure HandleTimeout(Id: TTimerId; Self: Pointer);
begin
  Message(PView(Self), evBroadcast, cmTimerExpired, Id);
end;

procedure TProgram.Idle;
begin
  if StatusLine <> nil then
    StatusLine^.Update;
  if CommandSetChanged then
  begin
    Message(@Self, evBroadcast, cmCommandSetChanged, nil);
    CommandSetChanged := False;
  end;
  TimerQueue.CollectExpiredTimers(@HandleTimeout, @Self);
end;

procedure TProgram.InitDeskTop;
var
  R: TRect;
begin
  R := GetExtent;
  Inc(R.A.Y);
  Dec(R.B.Y);
  New(DeskTop, Init(R));
end;

procedure TProgram.InitMenuBar;
var
  R: TRect;
begin
  R := GetExtent;
  R.B.Y := R.A.Y + 1;
  New(MenuBar, Init(R, nil));
end;

procedure TProgram.InitScreen;
begin
  if (ScreenMode and $00FF) <> smMono then
  begin
    if (ScreenMode and smFont8x8) <> 0 then
      ShadowSize.X := 1
    else
      ShadowSize.X := 2;
    ShadowSize.Y := 1;
    ShowMarkers := False;
    if (ScreenMode and $00FF) = smBW80 then
      AppPalette := apBlackWhite
    else
      AppPalette := apColor;
  end
  else
  begin
    ShadowSize.X := 0;
    ShadowSize.Y := 0;
    ShowMarkers := True;
    AppPalette := apMonochrome;
  end;
end;

procedure TProgram.InitStatusLine;
var
  R: TRect;
begin
  R := GetExtent;
  R.A.Y := R.B.Y - 1;
  New(StatusLine, Init(R,
    NewStatusDef(0, $FFFF,
      NewStatusKey(ExitText, kbAltX, cmQuit,
      NewStatusKey('', kbF10, cmMenu,
      NewStatusKey('', kbAltF3, cmClose,
      NewStatusKey('', kbF5, cmZoom,
      NewStatusKey('', kbCtrlF5, cmResize, nil))))),
    nil)));
end;

function TProgram.InsertWindow(P: PWindow): PWindow;
begin
  Result := nil;
  if ValidView(P) <> nil then
  begin
    if CanMoveFocus then
    begin
      DeskTop^.Insert(P);
      Result := P;
    end
    else
      Dispose(P, Done);
  end;
end;

procedure TProgram.KillTimer(Id: TTimerId);
begin
  TimerQueue.KillTimer(Id);
end;

procedure TProgram.OutOfMemory;
begin
end;

procedure TProgram.PutEvent(var Event: TEvent);
begin
  Pending := Event;
end;

procedure TProgram.Resume;
begin
end;

procedure TProgram.Run;
begin
  Execute;
end;

procedure TProgram.SetScreenMode(Mode: Word);
var
  R: TRect;
begin
  if Assigned(OnSetVideoMode) then
    OnSetVideoMode(Mode);
  InitScreen;
  Buffer := ScreenBuffer;
  R.Assign(0, 0, ScreenWidth, ScreenHeight);
  ChangeBounds(R);
  SetState(sfExposed, False);
  SetState(sfExposed, True);
  Redraw;
end;

function TProgram.SetTimer(TimeoutMs: LongWord; PeriodMs: Integer): TTimerId;
begin
  Result := TimerQueue.SetTimer(TimeoutMs, PeriodMs);
end;

procedure TProgram.Suspend;
begin
end;

function TProgram.ValidView(P: PView): PView;
begin
  Result := nil;
  if P = nil then
    Exit;
  if not P^.Valid(cmValid) then
  begin
    Dispose(P, Done);
    Exit;
  end;
  Result := P;
end;

{ --- TApplication ------------------------------------------------------------ }

constructor TApplication.Init;
begin
  inherited Init;
end;

destructor TApplication.Done;
begin
  inherited Done;
end;

procedure TApplication.Suspend;
begin
  if Assigned(OnSuspend) then
    OnSuspend();
end;

procedure TApplication.Resume;
begin
  if Assigned(OnResume) then
    OnResume();
end;

procedure TApplication.Cascade;
begin
  if DeskTop <> nil then
    DeskTop^.Cascade(GetTileRect);
end;

procedure TApplication.DosShell;
var
  Shell: string;
begin
  Suspend;
  WriteShellMsg;
  Shell := GetEnvironmentVariable('COMSPEC');
  if Shell = '' then
    Shell := GetEnvironmentVariable('SHELL');
  if Shell <> '' then
    ExecuteProcess(Shell, '');
  Resume;
  Redraw;
end;

function TApplication.GetTileRect: TRect;
begin
  Result := DeskTop^.GetExtent;
end;

procedure TApplication.HandleEvent(var Event: TEvent);
begin
  inherited HandleEvent(Event);
  if Event.What = evCommand then
  begin
    case Event.Command of
      cmDosShell: DosShell;
      cmCascade: Cascade;
      cmTile: Tile;
    else
      Exit;
    end;
    ClearEvent(Event);
  end;
end;

procedure TApplication.Tile;
begin
  if DeskTop <> nil then
    DeskTop^.Tile(GetTileRect);
end;

procedure TApplication.WriteShellMsg;
begin
  WriteLn('Type EXIT to return...');
end;

initialization
  SystemColors[apColor] := AppColorPalette;
  SystemColors[apBlackWhite] := AppBlackWhitePalette;
  SystemColors[apMonochrome] := AppMonochromePalette;
  Pending.What := evNothing;
  TimerQueue.Init(nil);

finalization
  TimerQueue.Done;
end.
