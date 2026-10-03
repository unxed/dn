{ TvUnix: the terminal backend for Unix (the Linux console, xterm and the like): the screen is drawn with ANSI
  sequences, keys and the mouse come from the terminal, a change of the size of the terminal is an event.

  Translated from magiblot/tvision @ b4831e2 (the parts that matter without ncurses):
    source/platform/unixcon.cpp, linuxcon.cpp   (the raw mode of the terminal, the size, the start and the end),
    source/platform/sigwinch.cpp                (the change of the size),
    source/platform/dispbuff.cpp, ncurdisp.cpp  (the cells that changed are drawn: the shadow of the screen),
    source/platform/events.cpp, platform.cpp    (the wait for input, the mouse timers),
    source/platform/termio.cpp                  (the sequences that start and stop the reporting: in TvTermIO).
  Borland disclaimer and MIT notice: tv/COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/DESIGN.md):
    - one thread: the wait for input and the drawing are in PollEvent;
    - the colors, the quirks of terminals and the keys are guessed from TERM and COLORTERM (TvAnsi, TvTermIO), not
      read from terminfo; TV_COLORS forces the colors, TV_MOUSE=0 switches the mouse off, ESCDELAY is the time
      that an Esc waits for the rest of a sequence (ms, default 25);
    - not done yet: the clipboard (OSC 52), the suspend of the program (Ctrl+Z, a shell), GPM, far2l.

  Use: UnixInit before the application is created, UnixDone after it is destroyed. }
unit TvUnix;

{$I tvdefs.inc}

interface

{ Puts the terminal in the raw mode, creates the screen (the size of the terminal) and sets the hooks of TvSys,
  TvScreen. False if the input is not a terminal. }
function UnixInit: Boolean;
procedure UnixDone;
function UnixActive: Boolean;
{ The terminal is given back for a while (a program is run that uses it): the alternate screen is left and the mode of the
  terminal is restored; UnixResume takes the terminal again and the whole screen is drawn again at the next update. }
procedure UnixSuspend;
procedure UnixResume;

{ For tests: the bytes of the output that were not written yet, and writing them. }
procedure UnixFlush;

implementation

{$IF DEFINED(UNIX) OR DEFINED(WINDOWS)}

uses
  SysUtils, TvTermOs, TvGeom, TvCell, TvColors, TvScreen, TvEvents, TvSys, TvMouse, TvViews, TvTermIO, TvAnsi, TvCodePg;

const
  AutoSliceMs = 20;           { the wait between the checks of the mouse timers while a button is down }

var
  Active: Boolean = False;
  Cols, Rows: Integer;
  Writer: TAnsiWriter;
  Shown: PScreenCell = nil;   { the cells that the terminal shows }
  Input: TTermInput;
  InState: TInputState;
  MState: TMouseState;
  MouseOn: Boolean = False;
  InBuf: array[0..1023] of Byte;
  InPos, InLen: Integer;
  Dirty: Boolean = False;     { cells were written after the last flush: the caret is hidden }
  CaretMoved: Boolean = True;
  CaretShape: Integer = -1;
  ExitProcSet: Boolean = False;

{ --- output ------------------------------------------------------------------------------------------------- }

procedure WriteAll(P: PByte; Len: Integer);
begin
  OsWrite(P, Len);
end;

procedure UnixFlush;
var
  Shape: Integer;
begin
  if not Active then
    Exit;
  if Dirty or CaretMoved then
  begin
    if CaretSize > 0 then
    begin
      Writer.SetCaretPosition(CaretX, CaretY);
      Shape := 2;                       { steady block }
      if CaretSize < 50 then
        Shape := 4;                     { steady underline }
      if Shape <> CaretShape then
      begin
        Writer.WriteRaw(#27'[' + IntToStr(Shape) + ' q');
        CaretShape := Shape;
      end;
      Writer.WriteRaw(#27'[?25h');
    end
    else if not Dirty then
      Writer.WriteRaw(#27'[?25l');
    Dirty := False;
    CaretMoved := False;
  end;
  if Writer.Length > 0 then
  begin
    WriteAll(Writer.Data, Writer.Length);
    Writer.Clear;
  end;
end;

procedure BeginDraw;
begin
  if not Dirty then
  begin
    Writer.WriteRaw(#27'[?25l');
    Dirty := True;
  end;
end;

{ the text of a cell as UTF-8: a character of the code page (one byte, $80 and up, or a control one) is converted }
function CellText(const Ch: TScreenCharacter): string;
var
  Buf: array[0..7] of Byte;
  N: Integer;
begin
  Result := ScText(Ch);
  if (Result = '') or (Result = #0) then
    Exit(' ');
  if (Length(Result) = 1) and ((Byte(Result[1]) >= $80) or (Byte(Result[1]) < $20)) then
  begin
    N := CpToUtf8(Byte(Result[1]), @Buf[0]);
    SetLength(Result, N);
    Move(Buf[0], Result[1], N);
  end;
end;

procedure DrawCell(CX, Y: Integer);
var
  Row, C: PScreenCell;
  Idx: Integer;
  Text: string;
begin
  Row := ScreenBuffer + Y * Cols;
  C := Row + CX;
  Idx := Y * Cols + CX;
  if ScIsWideTrail(C^.Character) then
  begin
    if (CX > 0) and ScIsWide(Row[CX - 1].Character) then
      DrawCell(CX - 1, Y)               { the lead draws both }
    else
      Writer.WriteCell(CX, Y, ' ', C^.Attribute, False);   { a trail with no lead }
    Shown[Idx] := C^;
    Exit;
  end;
  { a wide character that was shown here, and this cell is not its trail any more: it is gone from the screen }
  if (CX > 0) and ScIsWide(Shown[Idx - 1].Character) and not ScIsWide(Row[CX - 1].Character) then
  begin
    Writer.WriteCell(CX - 1, Y, ' ', Shown[Idx - 1].Attribute, False);
    Shown[Idx - 1] := Row[CX - 1];
  end;
  if ScIsWide(C^.Character) then
  begin
    if (CX + 1 < Cols) and ScIsWideTrail(Row[CX + 1].Character) then
    begin
      Writer.WriteCell(CX, Y, CellText(C^.Character), C^.Attribute, True);
      Shown[Idx] := C^;
      Shown[Idx + 1] := Row[CX + 1];
      Exit;
    end;
    Writer.WriteCell(CX, Y, ' ', C^.Attribute, False);     { the trail is missing: the character is overlapped }
    Shown[Idx] := C^;
    Exit;
  end;
  Text := CellText(C^.Character);
  Writer.WriteCell(CX, Y, Text, C^.Attribute, False);
  Shown[Idx] := C^;
end;

procedure UnixScreenWrite(X, Y: Integer; Cells: PScreenCell; Count: Integer);
var
  I, CX, Idx: Integer;
  Row: PScreenCell;
  Differs: Boolean;
begin
  if (Y < 0) or (Y >= Rows) or (Shown = nil) then
    Exit;
  Row := ScreenBuffer + Y * Cols;
  for I := 0 to Count - 1 do
  begin
    CX := X + I;
    if (CX < 0) or (CX >= Cols) then
      Continue;
    Idx := Y * Cols + CX;
    Differs := not CellEq(Row[CX], Shown[Idx]);
    { a wide lead is drawn again when its trail changed }
    if (not Differs) and ScIsWide(Row[CX].Character) and (CX + 1 < Cols) and not CellEq(Row[CX + 1], Shown[Idx + 1]) then
      Differs := True;
    if Differs then
    begin
      BeginDraw;
      DrawCell(CX, Y);
    end;
  end;
end;

procedure UnixCaretPosition(X, Y: Integer);
begin
  CaretMoved := True;
end;

procedure UnixCaretSize(Size: Integer);
begin
  CaretMoved := True;
end;

{ --- input -------------------------------------------------------------------------------------------------- }

{ True if a byte can be read within TimeoutMs. }
function InputReady(TimeoutMs: Integer): Boolean;
begin
  if InPos < InLen then
    Exit(True);
  Result := OsInputReady(TimeoutMs);
end;

function RawRead(TimeoutMs: Integer): Integer;
var
  N: Integer;
begin
  if InPos >= InLen then
  begin
    if not InputReady(TimeoutMs) then
      Exit(-1);
    N := OsRead(InBuf, SizeOf(InBuf));
    if N <= 0 then
      Exit(-1);
    InPos := 0;
    InLen := N;
  end;
  Result := InBuf[InPos];
  Inc(InPos);
end;

function UnixClock: Int64;
begin
  Result := Int64(GetTickCount64);
end;

procedure UnixPollEvent(TimeoutMs: Integer; var Event: TEvent);
var
  Start, Now_: Int64;
  Raw: TEvent;
  Wait: Integer;
begin
  UnixFlush;
  Start := UnixClock;
  repeat
    if OsResizeFlag <> 0 then
    begin
      OsResizeFlag := 0;
      ClearEvent(Event);
      Event.What := evCommand;
      Event.Command := cmScreenChanged;
      Exit;
    end;
    { the timers of the mouse: the up that is pending, the auto repeat }
    if MouseOn then
    begin
      MState.Wheel := 0;
      MouseStep(MState, UnixClock, Event);
      if Event.What <> evNothing then
        Exit;
    end;
    if Input.HasPending or InputReady(0) then
    begin
      if ParseEvent(Input, Raw, InState) then
      begin
        if Raw.What = evMouse then
        begin
          MState.Where := Raw.Where;
          MState.Buttons := Raw.Buttons;
          MState.Wheel := Raw.Wheel;
          MState.ControlKeyState := Raw.ControlKeyState;
          MouseStep(MState, UnixClock, Event);
          MState.Wheel := 0;
          if Event.What <> evNothing then
            Exit;
        end
        else
        begin
          Event := Raw;
          Exit;
        end;
      end;
      Continue;                          { the bytes were an answer or part of one: look again }
    end;
    if TimeoutMs = 0 then
      Break;
    Now_ := UnixClock;
    if TimeoutMs < 0 then
      Wait := 1000
    else
    begin
      Wait := TimeoutMs - Integer(Now_ - Start);
      if Wait <= 0 then
        Break;
    end;
    if (MState.Buttons <> 0) and (Wait > AutoSliceMs) then
      Wait := AutoSliceMs;               { a button is down: the timers of the mouse must be looked at }
    if Wait > 1000 then
      Wait := 1000;
    InputReady(Wait);
  until (TimeoutMs >= 0) and (UnixClock - Start >= TimeoutMs);
  ClearEvent(Event);
end;

{ --- the screen --------------------------------------------------------------------------------------------- }

procedure ReadSize(out W, H: Integer);
begin
  OsSize(W, H);
  if W < 20 then
    W := 20;
  if H < 5 then
    H := 5;
  if W > 1000 then
    W := 1000;
  if H > 1000 then
    H := 1000;
end;

procedure NewScreen;
var
  N: Integer;
begin
  ReadSize(Cols, Rows);
  ScreenCreate(Cols, Rows);
  if Shown <> nil then
    FreeMem(Shown);
  N := Cols * Rows * SizeOf(TScreenCell);
  GetMem(Shown, N);
  FillChar(Shown^, N, $FF);              { nothing is known: every cell will be drawn }
  Writer.ClearScreen;
  Writer.Reset;
  Dirty := False;
  CaretMoved := True;
  CaretShape := -1;
end;

procedure UnixSetVideoMode(Mode: Word);
begin
  { Mode is smUpdate when the size of the terminal changed: the screen is made again }
  NewScreen;
end;

{ the terminal is put back also when the program dies by a signal }
procedure RestoreTerminal;
const
  Tail = #27'[0m'#27'[?25h'#27'[0 q'#27'[?7h'#27'[?1049l';
begin
  if not Active then
    Exit;
  if MouseOn then
    OsWrite(@SeqMouseOff[1], Length(SeqMouseOff));
  OsWrite(@SeqKeyModsOff[1], Length(SeqKeyModsOff));
  OsWrite(@Tail[1], Length(Tail));
  OsRawOff;
end;

{ called when the program is killed (the terminal in order, then the end) }
procedure DeathHandler;
begin
  RestoreTerminal;
end;

procedure AtExitRestore;
begin
  if Active then
  begin
    RestoreTerminal;
    Active := False;
  end;
end;

function UnixActive: Boolean;
begin
  Result := Active;
end;

procedure UnixSuspend;
begin
  if not Active then
    Exit;
  UnixFlush;
  RestoreTerminal;
end;

procedure UnixResume;
var
  Seq: string;
begin
  if not Active then
    Exit;
  OsRawOn;
  Seq := #27'[?1049h'#27'[?7l';
  WriteAll(@Seq[1], Length(Seq));
  Seq := SeqKeyModsOn;
  WriteAll(@Seq[1], Length(Seq));
  if MouseOn then
  begin
    Seq := SeqMouseOn;
    WriteAll(@Seq[1], Length(Seq));
  end;
  InPos := 0;
  InLen := 0;
  FillChar(InState, SizeOf(InState), 0);
  FillChar(MState, SizeOf(MState), 0);
  MouseQueueReset;
  NewScreen;                              { the size may have changed; nothing is known on the screen: all is drawn }
  Dirty := True;
end;

function UnixInit: Boolean;
var
  Seq, Delay: string;
  Ms: Integer;
begin
  Result := False;
  if Active then
    Exit(True);
  if not OsIsTerminal then
    Exit;
  OsRawOn;

  Writer.Init(TermCapFromEnv);
  InPos := 0;
  InLen := 0;
  Delay := GetEnvironmentVariable('ESCDELAY');
  Ms := StrToIntDef(Delay, 25);
  Input.Init(@RawRead, Ms);
  FillChar(InState, SizeOf(InState), 0);
  FillChar(MState, SizeOf(MState), 0);
  MouseQueueReset;
  OsResizeFlag := 0;

  { the alternate screen, no wrapping at the end of a row }
  Seq := #27'[?1049h'#27'[?7l';
  WriteAll(@Seq[1], Length(Seq));
  Seq := SeqKeyModsOn;
  WriteAll(@Seq[1], Length(Seq));
  MouseOn := GetEnvironmentVariable('TV_MOUSE') <> '0';
  if MouseOn then
  begin
    Seq := SeqMouseOn;
    WriteAll(@Seq[1], Length(Seq));
  end;

  OsHandlersOn(@DeathHandler);
  if not ExitProcSet then
  begin
    AddExitProc(@AtExitRestore);
    ExitProcSet := True;
  end;

  Active := True;
  NewScreen;
  OnScreenWrite := @UnixScreenWrite;
  OnCaretPosition := @UnixCaretPosition;
  OnCaretSize := @UnixCaretSize;
  OnPollEvent := @UnixPollEvent;
  GetClockMs := @UnixClock;
  OnSetVideoMode := @UnixSetVideoMode;
  Result := True;
end;

procedure UnixDone;
begin
  if not Active then
    Exit;
  UnixFlush;
  OnScreenWrite := nil;
  OnCaretPosition := nil;
  OnCaretSize := nil;
  OnPollEvent := nil;
  GetClockMs := nil;
  OnSetVideoMode := nil;
  OsHandlersOff;
  RestoreTerminal;
  Active := False;
  Writer.Done;
  if Shown <> nil then
    FreeMem(Shown);
  Shown := nil;
  ScreenDestroy;
end;

{$ELSE}

procedure UnixSuspend;
begin
end;

procedure UnixResume;
begin
end;

function UnixInit: Boolean;
begin
  Result := False;
end;

procedure UnixDone;
begin
end;

function UnixActive: Boolean;
begin
  Result := False;
end;

procedure UnixFlush;
begin
end;

{$ENDIF}

end.
