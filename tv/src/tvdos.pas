{ TvDos: the DOS backend (FPC target go32v2): text mode screen in video memory,
  keyboard through BIOS int 16h, mouse through int 33h, clock from the BIOS tick counter.

  Written for this port (the original has THardwareInfo, TScreen and TEventQueue for this).
  It sets the hooks of TvScreen and TvSys. Characters in the cells are shown through the
  current code page of TvCodePg, which must be the one of the video font: DosInit selects it
  from the DOS code page (437 and 866 are known) unless it is given.

  The system clipboard is WinOldAp (INT 2Fh AX=17xxh), text only (CF_OEMTEXT).

  Not done yet: video modes with more lines,
  graphics fonts for code pages other than the hardware one. }
unit TvDos;

{$I tvdefs.inc}

interface

{$IFDEF GO32V2}
uses
  Go32, Dos, TvGeom, TvColors, TvCell, TvCodePg, TvUtf8, TvKeys, TvEvents, TvScreen,
  TvSys, TvMouse, TvClip;

{ Takes over the screen, the keyboard and the mouse: the screen of TvScreen has the size
  of the current text mode. CodePage = 0 detects it. }
procedure DosInit(CodePage: Integer = 0);
{ Gives the screen back. }
procedure DosDone;

{ Writes the screen as it is in video memory to a file: width and height (words), then
  width * height words (character and attribute). Used by the tests and the demo. }
procedure DosDumpScreen(const FileName: string);

{ The Windows clipboard through WinOldAp (INT 2Fh, AX=17xxh): available when Windows (3.x,
  9x, XP DOS box) or an emulator has it. DosInit connects it to TvClip. Text is UTF-8 in the
  program and CF_OEMTEXT in the current code page in the clipboard. }
function DosClipboardAvailable: Boolean;
function DosClipSet(const Text: AnsiString): Boolean;
function DosClipGet(out Text: AnsiString): Boolean;

{ Reads a row of video memory: the characters (code page bytes). }
function DosReadRow(Y: Integer; X0, X1: Integer): ShortString;
function DosReadAttr(X, Y: Integer): Byte;

{ Puts a key into the BIOS keyboard buffer (for the tests, the demo and macros). }
procedure DosStuffKey(KeyCode: Word);
function DosKeyBufferEmpty: Boolean;

{ The state of the mouse driver, in cells; False if there is no driver. }
function DosMouseState(out State: TMouseState): Boolean;
function DosMousePresent: Boolean;

{ The key that the BIOS has, as an event (Event.What = evNothing if none). }
procedure DosReadKey(var Event: TEvent);
{ A BIOS key code (scan code and character) and the shift flags as an event. }
procedure DosKeyToEvent(Ax: Word; Shifts: Byte; var Event: TEvent);
{ The character and attribute word of a cell (code page bytes in video memory). }
function DosCellToVga(const C: TScreenCell): Word;

var
  { milliseconds spent in the last PollEvent waiting loops (for the tests) }
  DosYields: Integer = 0;
{$ENDIF}

implementation

{$IFDEF GO32V2}
const
  BiosSeg = $40;

var
  VideoSeg: Word = $B800;
  Cols, Rows, CharHeight: Integer;
  OldCursor: Word;
  OldMode: Byte;
  MouseOk: Boolean = False;
  WheelOk: Boolean = False;
  Active: Boolean = False;
  LastTicks: LongWord = 0;
  TickWraps: Int64 = 0;

function BiosByte(Ofs: Word): Byte;
begin
  dosmemget(BiosSeg, Ofs, Result, 1);
end;

function BiosWord(Ofs: Word): Word;
begin
  dosmemget(BiosSeg, Ofs, Result, 2);
end;

procedure SetBiosWord(Ofs: Word; V: Word);
begin
  dosmemput(BiosSeg, Ofs, V, 2);
end;

{ --- clock ------------------------------------------------------------------- }

{ the BIOS counts 18.2065 ticks a second (65536 / 3600 ticks an hour: 54.9254 ms a
  tick); it restarts at midnight }
function BiosClockMs: Int64;
var
  T: LongWord;
begin
  dosmemget(BiosSeg, $6C, T, 4);
  if T < LastTicks then
    Inc(TickWraps);
  LastTicks := T;
  Result := (TickWraps * 1573040 + T) * 54925 div 1000;
end;

{ --- screen ------------------------------------------------------------------ }

function CellAttrByte(const A: TColorAttr): Byte;
begin
  Result := ColorToBIOS(AttrFg(A), True) or (ColorToBIOS(AttrBg(A), False) shl 4);
end;

function DosCellToVga(const C: TScreenCell): Word;
var
  Ch: Byte;
  S: ShortString;
  Cp: LongWord;
  Used: Integer;
begin
  if ScIsWideTrail(C.Character) then
    Ch := Ord(' ')
  else
  begin
    S := ScText(C.Character);
    if Length(S) = 1 then
    begin
      Ch := Byte(S[1]);
      if Ch = 0 then
        Ch := Ord(' ');
    end
    else if Utf8Decode(@S[1], Length(S), Cp, Used) then
    begin
      Ch := CpFromUnicode(Cp);
      if Ch = 0 then
        Ch := Ord('?');
    end
    else
      Ch := Ord('?');
  end;
  Result := Ch or (Word(CellAttrByte(C.Attribute)) shl 8);
end;

type
  TWordRow = array[0..511] of Word;

procedure MouseHide; forward;
procedure MouseShow; forward;

procedure DosScreenWrite(X, Y: Integer; Cells: PScreenCell; Count: Integer);
var
  Buf: TWordRow;
  I, N: Integer;
begin
  if (Y < 0) or (Y >= Rows) then
    Exit;
  MouseHide;
  while Count > 0 do
  begin
    N := Count;
    if N > 512 then
      N := 512;
    for I := 0 to N - 1 do
      Buf[I] := DosCellToVga((Cells + I)^);
    dosmemput(VideoSeg, (Y * Cols + X) * 2, Buf, N * 2);
    Inc(X, N);
    Inc(Cells, N);
    Dec(Count, N);
  end;
  MouseShow;
end;

procedure SetCursorShape(Start, Finish: Byte);
var
  R: Registers;
begin
  R.ah := 1;
  R.ch := Start;
  R.cl := Finish;
  Intr($10, R);
end;

procedure DosCaretPosition(X, Y: Integer);
var
  R: Registers;
begin
  R.ah := 2;
  R.bh := 0;
  R.dh := Y;
  R.dl := X;
  Intr($10, R);
end;

procedure DosCaretSize(Size: Integer);
var
  Lines: Integer;
begin
  if Size <= 0 then
    SetCursorShape($20, 0)     { bit 5: the cursor is hidden }
  else
  begin
    Lines := CharHeight * Size div 100;
    if Lines < 1 then
      Lines := 1;
    if Lines > CharHeight then
      Lines := CharHeight;
    SetCursorShape(CharHeight - Lines, CharHeight - 1);
  end;
end;

function DosReadRow(Y: Integer; X0, X1: Integer): ShortString;
var
  W: Word;
  X: Integer;
begin
  Result := '';
  for X := X0 to X1 do
  begin
    dosmemget(VideoSeg, (Y * Cols + X) * 2, W, 2);
    Result := Result + Chr(Lo(W));
  end;
end;

function DosReadAttr(X, Y: Integer): Byte;
var
  W: Word;
begin
  dosmemget(VideoSeg, (Y * Cols + X) * 2, W, 2);
  Result := Hi(W);
end;

procedure DosDumpScreen(const FileName: string);
var
  F: file;
  W: Word;
  Buf: TWordRow;
  Y: Integer;
begin
  Assign(F, FileName);
  Rewrite(F, 1);
  W := Cols;
  BlockWrite(F, W, 2);
  W := Rows;
  BlockWrite(F, W, 2);
  for Y := 0 to Rows - 1 do
  begin
    dosmemget(VideoSeg, Y * Cols * 2, Buf, Cols * 2);
    BlockWrite(F, Buf, Cols * 2);
  end;
  Close(F);
end;

{ --- keyboard ---------------------------------------------------------------- }

procedure DosKeyToEvent(Ax: Word; Shifts: Byte; var Event: TEvent);
var
  Ascii, Scan: Byte;
  Buf: array[0..3] of Byte;
  N: Integer;
begin
  Ascii := Lo(Ax);
  Scan := Hi(Ax);
  { extended keys of the enhanced keyboard come with $E0 (or $F0) as the character }
  if ((Ascii = $E0) or (Ascii = $F0)) and (Scan <> 0) then
    Ascii := 0;
  MakeKeyEvent(Event, (Word(Scan) shl 8) or Ascii, Shifts);
  { a character above $7F is a letter of the code page: the text is its UTF-8 }
  if Ascii >= $80 then
  begin
    N := CpToUtf8(Ascii, @Buf[0]);
    Move(Buf[0], Event.Text[0], N);
    Event.TextLength := N;
  end;
end;

procedure DosReadKey(var Event: TEvent);
var
  R: Registers;
  Ax: Word;
  Shifts: Byte;
begin
  ClearEvent(Event);
  R.ah := $11;
  Intr($16, R);
  if (R.flags and fZero) <> 0 then
    Exit;
  R.ah := $10;
  Intr($16, R);
  Ax := R.ax;
  R.ah := $12;
  Intr($16, R);
  Shifts := R.al;
  DosKeyToEvent(Ax, Shifts, Event);
end;

function DosKeyBufferEmpty: Boolean;
begin
  Result := BiosWord($1A) = BiosWord($1C);
end;

procedure DosStuffKey(KeyCode: Word);
var
  Tail, NewTail, Start, Finish: Word;
begin
  Start := BiosWord($80);
  Finish := BiosWord($82);
  Tail := BiosWord($1C);
  NewTail := Tail + 2;
  if NewTail >= Finish then
    NewTail := Start;
  if NewTail = BiosWord($1A) then
    Exit;                       { full }
  dosmemput(BiosSeg, Tail, KeyCode, 2);
  SetBiosWord($1C, NewTail);
end;

{ --- mouse ------------------------------------------------------------------- }

function DosMousePresent: Boolean;
begin
  Result := MouseOk;
end;

procedure MouseHide;
var
  R: Registers;
begin
  if MouseOk then
  begin
    R.ax := 2;
    Intr($33, R);
  end;
end;

procedure MouseShow;
var
  R: Registers;
begin
  if MouseOk then
  begin
    R.ax := 1;
    Intr($33, R);
  end;
end;

function DosMouseState(out State: TMouseState): Boolean;
var
  R: Registers;
begin
  FillChar(State, SizeOf(State), 0);
  Result := MouseOk;
  if not MouseOk then
    Exit;
  R.ax := 3;
  Intr($33, R);
  State.Buttons := R.bl and 7;
  State.Where.X := R.cx div 8;
  State.Where.Y := R.dx div 8;
  if State.Where.X >= Cols then State.Where.X := Cols - 1;
  if State.Where.Y >= Rows then State.Where.Y := Rows - 1;
  if WheelOk then
  begin
    { CuteMouse: BH is the wheel movement since the last call (signed) }
    if ShortInt(R.bh) < 0 then
      State.Wheel := mwUp
    else if ShortInt(R.bh) > 0 then
      State.Wheel := mwDown;
  end;
  R.ah := $02;
  Intr($16, R);
  State.ControlKeyState := R.al;
end;

procedure InitMouse;
var
  R: Registers;
begin
  R.ax := 0;
  Intr($33, R);
  MouseOk := R.ax = $FFFF;
  WheelOk := False;
  if MouseOk then
  begin
    R.ax := $0011;
    Intr($33, R);
    WheelOk := (R.ax = $574D) and ((R.cx and 1) <> 0);
    MouseShow;
    MouseQueueReset;
  end;
end;

{ --- clipboard (WinOldAp) --------------------------------------------------------------- }

const
  CF_OEMTEXT = 7;
  ClipMax = 262144;     { the largest text taken or given (conventional memory) }

function ClipCall(Ax, Dx: Word; var R: TRealRegs): Boolean;
begin
  FillChar(R, SizeOf(R), 0);
  R.ax := Ax;
  R.dx := Dx;
  realintr($2F, R);
  Result := R.ax <> 0;
end;

function DosClipboardAvailable: Boolean;
var
  R: TRealRegs;
begin
  FillChar(R, SizeOf(R), 0);
  R.ax := $1700;
  realintr($2F, R);
  Result := R.ax <> $1700;
end;

function DosClipSet(const Text: AnsiString): Boolean;
var
  R: TRealRegs;
  Data: AnsiString;
  L: LongInt;
  Seg: Word;
  Size: LongInt;
  Opened: Boolean;
begin
  Result := False;
  Data := ToCrLf(Utf8ToOem(Text));
  if Length(Data) > ClipMax then
    SetLength(Data, ClipMax);
  Size := Length(Data) + 1;                  { the text ends with a NUL }
  L := global_dos_alloc(Size);
  if L = 0 then
    Exit;
  Seg := L and $FFFF;
  Data := Data + #0;
  dosmemput(Seg, 0, Data[1], Size);
  Opened := ClipCall($1701, 0, R);
  if Opened then
  begin
    ClipCall($1702, 0, R);                    { empty }
    FillChar(R, SizeOf(R), 0);
    R.ax := $1703;
    R.dx := CF_OEMTEXT;
    R.es := Seg;
    R.bx := 0;
    R.si := Size shr 16;
    R.cx := Size and $FFFF;
    realintr($2F, R);
    Result := R.ax <> 0;
    ClipCall($1708, 0, R);                    { close }
  end;
  global_dos_free(L shr 16);
end;

function DosClipGet(out Text: AnsiString): Boolean;
var
  R: TRealRegs;
  L: LongInt;
  Seg: Word;
  Size: LongInt;
  Data: AnsiString;
begin
  Result := False;
  Text := '';
  if not ClipCall($1701, 0, R) then
    Exit;
  FillChar(R, SizeOf(R), 0);
  R.ax := $1704;
  R.dx := CF_OEMTEXT;
  realintr($2F, R);
  Size := (LongInt(R.dx) shl 16) or R.ax;     { DX:AX }
  if (Size > 0) and (Size <= ClipMax) then
  begin
    L := global_dos_alloc(Size);
    if L <> 0 then
    begin
      Seg := L and $FFFF;
      FillChar(R, SizeOf(R), 0);
      R.ax := $1705;
      R.dx := CF_OEMTEXT;
      R.es := Seg;
      R.bx := 0;
      realintr($2F, R);
      if R.ax <> 0 then
      begin
        SetLength(Data, Size);
        dosmemget(Seg, 0, Data[1], Size);
        { the text is NUL-terminated }
        if Pos(#0, Data) > 0 then
          SetLength(Data, Pos(#0, Data) - 1);
        Text := OemToUtf8(Data);
        Result := True;
      end;
      global_dos_free(L shr 16);
    end;
  end;
  ClipCall($1708, 0, R);
end;

{ --- events ------------------------------------------------------------------ }

procedure Yield;
var
  R: Registers;
begin
  R.ax := $1680;        { give the time slice away (DPMI/Windows/DOSBox) }
  Intr($2F, R);
  Inc(DosYields);
end;

procedure DosPollEvent(TimeoutMs: Integer; var Event: TEvent);
var
  Start: Int64;
  State: TMouseState;
begin
  Start := BiosClockMs;
  repeat
    if DosMouseState(State) then
    begin
      MouseStep(State, BiosClockMs, Event);
      if Event.What <> evNothing then
        Exit;
    end;
    DosReadKey(Event);
    if Event.What <> evNothing then
      Exit;
    if TimeoutMs = 0 then
      Break;
    Yield;
  until (TimeoutMs >= 0) and (BiosClockMs - Start >= TimeoutMs);
  ClearEvent(Event);
end;

function DosClock: Int64;
begin
  Result := BiosClockMs;
end;

{ --- start and end ---------------------------------------------------------------- }

procedure DosInit(CodePage: Integer);
var
  R: Registers;
begin
  R.ah := $0F;
  Intr($10, R);
  OldMode := R.al;
  { not a text mode: use 80x25 color }
  if not (OldMode in [0..3, 7]) then
  begin
    R.ax := $0003;
    Intr($10, R);
    R.ah := $0F;
    Intr($10, R);
  end;
  ScreenMode := R.al;
  if R.al = 7 then
    VideoSeg := $B000
  else
    VideoSeg := $B800;
  Cols := BiosWord($4A);
  Rows := BiosByte($84) + 1;
  if Rows < 2 then
    Rows := 25;
  CharHeight := BiosWord($85);
  if (CharHeight < 1) or (CharHeight > 32) then
    CharHeight := 16;
  R.ah := 3;
  R.bh := 0;
  Intr($10, R);
  OldCursor := R.cx;
  { 16 background colors instead of blinking }
  R.ax := $1003;
  R.bl := 0;
  Intr($10, R);

  { the code page of the font }
  if CodePage = 0 then
  begin
    R.ax := $6601;
    Intr($21, R);
    if (R.flags and fCarry) = 0 then
      CodePage := R.bx;
  end;
  if (CodePage = 0) or not CpSelect(CodePage) then
    CpSelect(cpIdCp437);

  ScreenCreate(Cols, Rows);
  OnScreenWrite := @DosScreenWrite;
  OnCaretPosition := @DosCaretPosition;
  OnCaretSize := @DosCaretSize;
  OnPollEvent := @DosPollEvent;
  GetClockMs := @DosClock;
  InitMouse;
  if DosClipboardAvailable then
  begin
    OnClipboardSet := @DosClipSet;
    OnClipboardGet := @DosClipGet;
  end;
  Active := True;
end;

procedure DosDone;
var
  R: Registers;
begin
  if not Active then
    Exit;
  Active := False;
  OnScreenWrite := nil;
  OnCaretPosition := nil;
  OnCaretSize := nil;
  OnPollEvent := nil;
  GetClockMs := nil;
  OnClipboardSet := nil;
  OnClipboardGet := nil;
  if MouseOk then
  begin
    R.ax := 2;
    Intr($33, R);
    MouseOk := False;
  end;
  SetCursorShape(Hi(OldCursor), Lo(OldCursor));
  ScreenDestroy;
end;
{$ELSE}
{$ENDIF}

end.
