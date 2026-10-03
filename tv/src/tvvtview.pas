{ TvVtView: a view of Turbo Vision with a terminal in it: a program on a pty (TvPty), its screen kept by the emulator (TvVt), the keys and the mouse turned into what
  the program expects (TvVtKeys) (PLAN.md item 8.3). Shift-PgUp, Shift-PgDn and the mouse wheel scroll the history when the program does not ask for the mouse.

  Written for this port (the original is TTermView/TerminalWindow of tvterm: termview.cc, termwnd.cc, termctrl.cc). The view reads the program on a timer (cmTimerExpired of the
  program, every 20 ms); when the program ends it sends cmVtEnded to the application. Linux only for now (TvPty). }
unit TvVtView;

{$I tvdefs.inc}

interface

{$IFDEF LINUX}
uses
  TvGeom, TvColors, TvCell, TvEvents, TvKeys, TvViews, TvApp, TvTimer, TvClip, TvVt, TvVtKeys, TvPty;

const
  cmVtEnded = 5100;            { broadcast to the application: the program of the view (InfoPtr = the view) has ended }

type
  { True: the key is not for the terminal (the owner handles it: the hotkeys of the application) }
  TVtKeyFilter = function(const Event: TEvent): Boolean;

  PVtView = ^TVtView;
  TVtView = object(TView)
    Emu: TVtEmu;
    Pty: TPty;
    Back: Integer;             { how many lines the view is scrolled back into the history (0: the live screen) }
    Ended: Boolean;
    KeyFilter: TVtKeyFilter;
    constructor Init(const Bounds: TRect; const Prog: AnsiString; const Args: array of AnsiString; const Cwd: AnsiString);
    destructor Done; virtual;
    procedure Draw; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure ChangeBounds(const Bounds: TRect); virtual;
    procedure SetState(AState: Word; Enable: Boolean); virtual;
    { reads what the program wrote; True when the screen changed }
    function Pump: Boolean;
    { sends bytes to the program }
    procedure SendBytes(const S: AnsiString);
    function Title: AnsiString;
  private
    Timer: TTimerId;
    PasteOpen: Boolean;
    Cells: array of TScreenCell;
    procedure ClosePaste;
    procedure ScrollBack(Delta: Integer);
    procedure Mouse(var Event: TEvent);
    procedure CheckEnd;
  end;
{$ENDIF}

implementation

{$IFDEF LINUX}
uses
  BaseUnix;

procedure VtClipboard(Data: Pointer; const Text: AnsiString);
begin
  ClipboardSetText(Text);
end;

constructor TVtView.Init(const Bounds: TRect; const Prog: AnsiString; const Args: array of AnsiString; const Cwd: AnsiString);
begin
  inherited Init(Bounds);
  GrowMode := gfGrowHiX or gfGrowHiY;
  Options := Options or ofSelectable or ofFirstClick;
  EventMask := EventMask or evMouseWheel or evBroadcast;
  Emu.Init(Size.X, Size.Y, 2000);
  Emu.OnClip := @VtClipboard;
  Emu.Data := @Self;
  Back := 0;
  Ended := False;
  KeyFilter := nil;
  PasteOpen := False;
  Timer := nil;
  if not Pty.Open(Size.X, Size.Y, Prog, Args, Cwd) then
    Ended := True
  else if Application <> nil then
    Timer := Application^.SetTimer(20, 20);
end;

destructor TVtView.Done;
begin
  if (Timer <> nil) and (Application <> nil) then
    Application^.KillTimer(Timer);
  Pty.Close;
  Emu.Done;
  Cells := nil;
  inherited Done;
end;

function TVtView.Title: AnsiString;
begin
  Result := Emu.Title;
end;

procedure TVtView.Draw;
var
  X, Y, V, H: Integer;
  C: TScreenCell;
begin
  if Length(Cells) < Size.X then
    SetLength(Cells, Size.X);
  H := Emu.HistoryCount;
  for Y := 0 to Size.Y - 1 do
  begin
    V := H + Y - Back;
    for X := 0 to Size.X - 1 do
    begin
      if V < H then
        C := Emu.HistoryCell(V, X)
      else
        C := Emu.CellAt(X, V - H);
      Cells[X] := C;
    end;
    WriteBuf(0, Y, Size.X, 1, @Cells[0]);
  end;
  Emu.ClearDirty;
  if (Back = 0) and Emu.CursorVisible and GetState(sfFocused) and not Ended then
  begin
    SetCursor(Emu.CursorX, Emu.CursorY);
    ShowCursor;
  end
  else
    HideCursor;
end;

procedure TVtView.SendBytes(const S: AnsiString);
begin
  if (Length(S) > 0) and not Ended then
    Pty.Write(S[1], Length(S));
end;

procedure TVtView.CheckEnd;
begin
  if not Ended and Pty.Wait(False) then
  begin
    Ended := True;
    if Application <> nil then
      Message(Application, evBroadcast, cmVtEnded, @Self);
  end;
end;

function TVtView.Pump: Boolean;
var
  Buf: array[0..8191] of Byte;
  N, Total: Integer;
  Reply: AnsiString;
  Dirty: Boolean;
  Y: Integer;
begin
  Result := False;
  if Ended and not Pty.Running then
    Exit;
  Total := 0;
  while Total < 65536 do
  begin
    N := Pty.Read(Buf, SizeOf(Buf));
    if N < 0 then
    begin
      CheckEnd;
      if not Ended then
        Ended := True;
      Break;
    end;
    if N = 0 then
      Break;
    Inc(Total, N);
    Emu.Feed(@Buf[0], N);
  end;
  Reply := Emu.TakeReply;
  if Reply <> '' then
    SendBytes(Reply);
  if not Ended then
    CheckEnd;
  Dirty := False;
  for Y := 0 to Emu.RowCount - 1 do
    if Emu.RowDirty(Y) then
      Dirty := True;
  Result := Dirty;
end;

procedure TVtView.ScrollBack(Delta: Integer);
var
  Old: Integer;
begin
  Old := Back;
  Inc(Back, Delta);
  if Back > Emu.HistoryCount then
    Back := Emu.HistoryCount;
  if Back < 0 then
    Back := 0;
  if Back <> Old then
    DrawView;
end;

procedure TVtView.ClosePaste;
begin
  if PasteOpen then
  begin
    PasteOpen := False;
    SendBytes(#27'[201~');
  end;
end;

procedure TVtView.Mouse(var Event: TEvent);
var
  P: TPoint;
  B: Integer;
  S: AnsiString;
begin
  P := MakeLocal(Event.Where);
  if Emu.MouseMode = 0 then
  begin
    if (Event.What = evMouseWheel) then
    begin
      if (Event.Wheel and mwUp) <> 0 then
        ScrollBack(3)
      else if (Event.Wheel and mwDown) <> 0 then
        ScrollBack(-3);
      ClearEvent(Event);
    end
    else if Event.What = evMouseDown then
    begin
      Select;
      ClearEvent(Event);
    end;
    Exit;
  end;
  B := -1;
  if (Event.Buttons and mbLeftButton) <> 0 then B := 0
  else if (Event.Buttons and mbMiddleButton) <> 0 then B := 1
  else if (Event.Buttons and mbRightButton) <> 0 then B := 2;
  S := '';
  case Event.What of
    evMouseDown, evMouseAuto: S := VtMouseBytes(Emu.MouseMode, Emu.MouseEnc, P.X, P.Y, B, True, False, 0, Event.ControlKeyState);
    evMouseUp: S := VtMouseBytes(Emu.MouseMode, Emu.MouseEnc, P.X, P.Y, 0, False, False, 0, Event.ControlKeyState);
    evMouseMove: S := VtMouseBytes(Emu.MouseMode, Emu.MouseEnc, P.X, P.Y, B, False, True, 0, Event.ControlKeyState);
    evMouseWheel:
      if (Event.Wheel and mwUp) <> 0 then
        S := VtMouseBytes(Emu.MouseMode, Emu.MouseEnc, P.X, P.Y, 0, True, False, 1, Event.ControlKeyState)
      else if (Event.Wheel and mwDown) <> 0 then
        S := VtMouseBytes(Emu.MouseMode, Emu.MouseEnc, P.X, P.Y, 0, True, False, 2, Event.ControlKeyState);
  end;
  if (Event.What = evMouseDown) and not GetState(sfFocused) then
    Select;
  SendBytes(S);
  ClearEvent(Event);
end;

procedure TVtView.HandleEvent(var Event: TEvent);
var
  S: AnsiString;
begin
  inherited HandleEvent(Event);
  case Event.What of
    evKeyDown:
      begin
        if not GetState(sfFocused) then
          Exit;
        if Assigned(KeyFilter) and KeyFilter(Event) then
          Exit;
        if (Event.KeyCode = kbPgUp) and ((Event.ControlKeyState and kbShift) <> 0) then
        begin
          ScrollBack(Size.Y - 1);
          ClearEvent(Event);
          Exit;
        end;
        if (Event.KeyCode = kbPgDn) and ((Event.ControlKeyState and kbShift) <> 0) then
        begin
          ScrollBack(-(Size.Y - 1));
          ClearEvent(Event);
          Exit;
        end;
        if (Event.ControlKeyState and kbPaste) <> 0 then
        begin
          if Emu.BracketedPaste and not PasteOpen then
          begin
            PasteOpen := True;
            SendBytes(#27'[200~');
          end;
        end
        else
          ClosePaste;
        S := VtKeyBytes(Event, Emu.AppCursor);
        if S <> '' then
        begin
          SendBytes(S);
          if Back > 0 then
          begin
            Back := 0;
            DrawView;
          end;
        end;
        ClearEvent(Event);
      end;
    evMouseDown, evMouseUp, evMouseMove, evMouseAuto, evMouseWheel:
      Mouse(Event);
    evBroadcast:
      if (Event.Command = cmTimerExpired) and (Event.InfoPtr = Timer) then
      begin
        if Pump then
          DrawView;
        if PasteOpen then
          ClosePaste;
      end;
  end;
end;

procedure TVtView.ChangeBounds(const Bounds: TRect);
begin
  inherited ChangeBounds(Bounds);
  if (Size.X > 0) and (Size.Y > 0) then
  begin
    Emu.Resize(Size.X, Size.Y);
    if not Ended then
      Pty.Resize(Size.X, Size.Y);
  end;
  if Back > Emu.HistoryCount then
    Back := Emu.HistoryCount;
  DrawView;
end;

procedure TVtView.SetState(AState: Word; Enable: Boolean);
begin
  inherited SetState(AState, Enable);
  if (AState and sfFocused) <> 0 then
  begin
    if Emu.FocusEvents and not Ended then
      if Enable then
        SendBytes(#27'[I')
      else
        SendBytes(#27'[O');
    DrawView;
  end;
end;
{$ENDIF}

end.
