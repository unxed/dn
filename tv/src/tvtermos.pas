{ TvTermOs: what the terminal backend (TvUnix) needs from the operating system: the raw mode, the output, the wait for input, the size of
  the terminal, the end of the program. Unix: termios, poll, ioctl, signals. Windows (10 and newer; Wine): the console in the mode of
  virtual terminal sequences, in and out (so that the same sequences as on Unix are used: TvAnsi, TvTermIO); the input is read as
  console records (key events carry the characters of the sequences), a change of the size of the window is a record too.

  Written for this port. MIT, see tv/LICENSE. }
unit TvTermOs;

{$I tvdefs.inc}

interface

type
  TOsHook = procedure;

{ Both the input and the output are a terminal (a console). }
function OsIsTerminal: Boolean;
{ The raw mode (no echo, no line editing, no processing of the keys; the sequences of the terminal are on); the old state is kept. }
procedure OsRawOn;
{ The state that OsRawOn kept. }
procedure OsRawOff;
procedure OsWrite(P: PByte; Len: Integer);
{ True if a byte can be read within TimeoutMs. }
function OsInputReady(TimeoutMs: Integer): Boolean;
{ Reads up to Size bytes that are ready; <= 0 if there is nothing. }
function OsRead(var Buf; Size: Integer): Integer;
procedure OsSize(out W, H: Integer);
{ Sets OsResizeFlag when the size of the terminal changes; ends the program with the terminal in order when it is killed. }
procedure OsHandlersOn(AfterDeath: TOsHook);
procedure OsHandlersOff;
{ Ends the program at once with the code (in a handler). }
procedure OsExit(Code: Integer);

var
  OsResizeFlag: LongInt = 0;

implementation

uses
  SysUtils,
{$IFDEF UNIX}
  BaseUnix, termio;
{$ENDIF}
{$IFDEF WINDOWS}
  Windows, TvUtf8;
{$ENDIF}

{$IFDEF UNIX}

var
  SavedTios: Termios;
  OldWinch, OldTerm, OldHup: SigActionRec;
  DeathProc: TOsHook = nil;

function OsIsTerminal: Boolean;
begin
  Result := (IsATTY(0) <> 0) and (IsATTY(1) <> 0);
end;

procedure OsRawOn;
var
  Raw: Termios;
begin
  TCGetAttr(0, SavedTios);
  Raw := SavedTios;
  CFMakeRaw(Raw);
  Raw.c_cc[VMIN] := 1;
  Raw.c_cc[VTIME] := 0;
  TCSetAttr(0, TCSANOW, Raw);
end;

procedure OsRawOff;
begin
  TCSetAttr(0, TCSANOW, SavedTios);
end;

procedure OsWrite(P: PByte; Len: Integer);
var
  N: TSsize;
begin
  while Len > 0 do
  begin
    N := FpWrite(1, P^, Len);
    if N < 0 then
    begin
      if fpgeterrno = ESysEINTR then
        Continue;
      if fpgeterrno = ESysEAGAIN then
      begin
        Sleep(1);
        Continue;
      end;
      Exit;
    end;
    Inc(P, N);
    Dec(Len, N);
  end;
end;

function OsInputReady(TimeoutMs: Integer): Boolean;
var
  P: TPollFd;
  R: cint;
begin
  P.fd := 0;
  P.events := POLLIN;
  P.revents := 0;
  R := FpPoll(@P, 1, TimeoutMs);
  Result := (R > 0) and ((P.revents and (POLLIN or POLLHUP)) <> 0);
end;

function OsRead(var Buf; Size: Integer): Integer;
begin
  Result := FpRead(0, Buf, Size);
end;

procedure OsSize(out W, H: Integer);
var
  Ws: TWinSize;
begin
  W := 0;
  H := 0;
  FillChar(Ws, SizeOf(Ws), 0);
  if FpIoctl(1, TIOCGWINSZ, @Ws) = 0 then
  begin
    W := Ws.ws_col;
    H := Ws.ws_row;
  end;
  if W <= 0 then
    W := StrToIntDef(GetEnvironmentVariable('COLUMNS'), 80);
  if H <= 0 then
    H := StrToIntDef(GetEnvironmentVariable('LINES'), 25);
end;

procedure WinchHandler(Sig: cint); cdecl;
begin
  OsResizeFlag := 1;
end;

procedure DeathHandler(Sig: cint); cdecl;
begin
  if Assigned(DeathProc) then
    DeathProc;
  FpExit(128 + Sig);
end;

procedure OsHandlersOn(AfterDeath: TOsHook);
var
  Act: SigActionRec;
begin
  DeathProc := AfterDeath;
  FillChar(Act, SizeOf(Act), 0);
  Act.sa_handler := SigActionHandler(@WinchHandler);
  FpSigAction(SIGWINCH, @Act, @OldWinch);
  Act.sa_handler := SigActionHandler(@DeathHandler);
  FpSigAction(SIGTERM, @Act, @OldTerm);
  FpSigAction(SIGHUP, @Act, @OldHup);
end;

procedure OsHandlersOff;
begin
  FpSigAction(SIGWINCH, @OldWinch, nil);
  FpSigAction(SIGTERM, @OldTerm, nil);
  FpSigAction(SIGHUP, @OldHup, nil);
end;

procedure OsExit(Code: Integer);
begin
  FpExit(Code);
end;

{$ENDIF UNIX}

{$IFDEF WINDOWS}

const
  ENABLE_PROCESSED_INPUT = $0001;
  ENABLE_MOUSE_INPUT = $0010;
  ENABLE_WINDOW_INPUT = $0008;
  ENABLE_EXTENDED_FLAGS = $0080;
  ENABLE_VIRTUAL_TERMINAL_INPUT = $0200;
  ENABLE_PROCESSED_OUTPUT = $0001;
  ENABLE_VIRTUAL_TERMINAL_PROCESSING = $0004;
  DISABLE_NEWLINE_AUTO_RETURN = $0008;
  CP_UTF8_ = 65001;

var
  HIn, HOut: THandle;
  SavedIn, SavedOut: DWORD;
  SavedCpIn, SavedCpOut: UINT;
  Queue: array[0..8191] of Byte;
  QHead, QTail: Integer;
  HighSurrogate: Word = 0;
  CtrlProc: TOsHook = nil;


{ --- the console mode (the default; DN_WIN_OUTPUT=vt turns it off) -------------------------------------------
  The console of an old Windows and of Wine does not understand the sequences, or not all of them. TvUnix still writes them (TvAnsi);
  here they are read and drawn with the console API into a screen buffer of our own (the user's screen comes back at the end), the keys
  and the mouse are turned into the same sequences that a terminal sends. Understood: CUP, CHA, CUU/CUD/CUF/CUB, ED, EL, SGR (16, 256 and
  RGB colors go to the 16 of the console), the private modes 25 (caret), 1000/1002/1006 (the mouse), the caret shape (CSI Ps SP q);
  the other sequences are skipped. }

type
  TCon = record
    On: Boolean;
    H, Orig: THandle;
    W, Hh: Integer;
    Cells: ^CHAR_INFO;
    X, Y: Integer;
    Fg, Bg: Byte;
    Rev: Boolean;
    CaretOn: Boolean;
    CaretSize: DWORD;
    Dx0, Dy0, Dx1, Dy1: Integer;
    CarryLen: Integer;
    Carry: array[0..63] of Byte;
    Mouse: Boolean;
    LastButtons: DWORD;
    DimBg: Boolean;               { the background has no intensity bit (the terminal of Wine draws it unevenly) }
  end;

var
  Con: TCon;

const
  VgaRgb: array[0..15] of LongWord = (
    $000000, $0000AA, $00AA00, $00AAAA, $AA0000, $AA00AA, $AA5500, $AAAAAA,
    $555555, $5555FF, $55FF55, $55FFFF, $FF5555, $FF55FF, $FFFF55, $FFFFFF);   { index: bit0 blue, bit1 green, bit2 red, bit3 bright; $BBGGRR }

function AnsiToCon(N: Integer): Byte;      { ANSI 0..15 (bit0 red, bit2 blue) -> the console (bit0 blue, bit2 red) }
begin
  Result := (N and 8) or ((N and 1) shl 2) or (N and 2) or ((N and 4) shr 2);
end;

function RgbToCon(R, G, B: Integer): Byte;
var
  I, D, Best, BestD, VR, VG, VB: Integer;
begin
  Best := 0;
  BestD := MaxInt;
  for I := 0 to 15 do
  begin
    VB := (VgaRgb[I] shr 16) and $FF;
    VG := (VgaRgb[I] shr 8) and $FF;
    VR := VgaRgb[I] and $FF;
    D := Sqr(R - VR) + Sqr(G - VG) + Sqr(B - VB);
    if D < BestD then
    begin
      BestD := D;
      Best := I;
    end;
  end;
  Result := Best;
end;

function XtermToCon(N: Integer): Byte;
var
  L: Integer;
begin
  if N < 16 then
    Exit(AnsiToCon(N));
  if N >= 232 then
  begin
    L := 8 + (N - 232) * 10;
    Exit(RgbToCon(L, L, L));
  end;
  Dec(N, 16);
  Result := RgbToCon(((N div 36) mod 6) * 51, ((N div 6) mod 6) * 51, (N mod 6) * 51);
end;

procedure ConAlloc;
var
  Info: CONSOLE_SCREEN_BUFFER_INFO;
  I: Integer;
  Sz: COORD;
begin
  Con.W := 80;
  Con.Hh := 25;
  if GetConsoleScreenBufferInfo(Con.H, Info) then
  begin
    Con.W := Info.srWindow.Right - Info.srWindow.Left + 1;
    Con.Hh := Info.srWindow.Bottom - Info.srWindow.Top + 1;
    if (Info.dwSize.X <> Con.W) or (Info.dwSize.Y <> Con.Hh) then
    begin
      Sz.X := Con.W;
      Sz.Y := Con.Hh;
      SetConsoleScreenBufferSize(Con.H, Sz);      { no scroll bars: the buffer is as large as the window }
    end;
  end;
  if Con.Cells <> nil then
    FreeMem(Con.Cells);
  GetMem(Con.Cells, Con.W * Con.Hh * SizeOf(CHAR_INFO));
  for I := 0 to Con.W * Con.Hh - 1 do
  begin
    Con.Cells[I].UnicodeChar := ' ';
    Con.Cells[I].Attributes := 7;
  end;
  Con.Dx0 := 0;
  Con.Dy0 := 0;
  Con.Dx1 := Con.W - 1;
  Con.Dy1 := Con.Hh - 1;
end;

procedure ConMark(X, Y: Integer);
begin
  if X < Con.Dx0 then Con.Dx0 := X;
  if X > Con.Dx1 then Con.Dx1 := X;
  if Y < Con.Dy0 then Con.Dy0 := Y;
  if Y > Con.Dy1 then Con.Dy1 := Y;
end;

function ConAttr: Word;
var
  Bg: Byte;
begin
  Bg := Con.Bg;
  if Con.DimBg then
    Bg := Bg and 7;
  if Con.Rev then
    Result := Bg or (Word(Con.Fg) shl 4)
  else
    Result := Con.Fg or (Word(Bg) shl 4);
end;

function RunsOnWine: Boolean;
var
  H: HMODULE;
begin
  H := GetModuleHandle('ntdll.dll');
  Result := (H <> 0) and (GetProcAddress(H, 'wine_get_version') <> nil);
end;

procedure ConPutChar(CP: LongWord);
var
  Wd: Integer;
  I: Integer;
  Ch: WideChar;
begin
  if CP >= $10000 then
    CP := Ord('?');                         { the console cell holds a UTF-16 unit: no character beyond the plane 0 }
  Ch := WideChar(CP);
  Wd := CharWidth(CP);
  if Wd < 1 then
    Wd := 1;
  if (Con.Y < 0) or (Con.Y >= Con.Hh) or (Con.X < 0) or (Con.X + Wd > Con.W) then
  begin
    Inc(Con.X, Wd);
    Exit;
  end;
  I := Con.Y * Con.W + Con.X;
  Con.Cells[I].UnicodeChar := Ch;
  Con.Cells[I].Attributes := ConAttr;
  if Wd = 2 then
  begin
    Con.Cells[I].Attributes := ConAttr or $0100;       { COMMON_LVB_LEADING_BYTE }
    Con.Cells[I + 1].UnicodeChar := Ch;
    Con.Cells[I + 1].Attributes := ConAttr or $0200;   { COMMON_LVB_TRAILING_BYTE }
  end;
  ConMark(Con.X, Con.Y);
  ConMark(Con.X + Wd - 1, Con.Y);
  Inc(Con.X, Wd);
end;

{ for the tests: when the variable TV_CONDUMP names a file, the cells (the character and the attribute in hex) are written there after each flush }
procedure ConDump;
var
  Path: string;
  F: TextFile;
  X, Y: Integer;
begin
  Path := SysUtils.GetEnvironmentVariable('TV_CONDUMP');
  if Path = '' then
    Exit;
  AssignFile(F, Path);
  {$I-}
  Rewrite(F);
  {$I+}
  if IOResult <> 0 then
    Exit;
  for Y := 0 to Con.Hh - 1 do
  begin
    for X := 0 to Con.W - 1 do
      Write(F, IntToHex(Ord(Con.Cells[Y * Con.W + X].UnicodeChar), 4), ':', IntToHex(Con.Cells[Y * Con.W + X].Attributes, 2), ' ');
    Writeln(F);
  end;
  CloseFile(F);
end;

procedure ConFlush;
var
  Rect: SMALL_RECT;
  Sz, Org, Pos: COORD;
  Ci: CONSOLE_CURSOR_INFO;
begin
  if Con.Dx0 <= Con.Dx1 then
  begin
    Rect.Left := Con.Dx0;
    Rect.Top := Con.Dy0;
    Rect.Right := Con.Dx1;
    Rect.Bottom := Con.Dy1;
    Sz.X := Con.W;
    Sz.Y := Con.Hh;
    Org.X := Con.Dx0;
    Org.Y := Con.Dy0;
    WriteConsoleOutputW(Con.H, Con.Cells, Sz, Org, Rect);
    Con.Dx0 := Con.W;
    Con.Dy0 := Con.Hh;
    Con.Dx1 := -1;
    Con.Dy1 := -1;
  end;
  Pos.X := Con.X;
  Pos.Y := Con.Y;
  if Pos.X >= Con.W then
    Pos.X := Con.W - 1;
  if Pos.X < 0 then
    Pos.X := 0;
  if Pos.Y < 0 then
    Pos.Y := 0;
  SetConsoleCursorPosition(Con.H, Pos);
  Ci.dwSize := Con.CaretSize;
  Ci.bVisible := Con.CaretOn;
  SetConsoleCursorInfo(Con.H, Ci);
  ConDump;
end;

procedure ConErase(X0, Y0, X1, Y1: Integer);   { cells of the rectangle become spaces of the current color }
var
  X, Y: Integer;
begin
  for Y := Y0 to Y1 do
    for X := X0 to X1 do
      if (X >= 0) and (X < Con.W) and (Y >= 0) and (Y < Con.Hh) then
      begin
        Con.Cells[Y * Con.W + X].UnicodeChar := ' ';
        Con.Cells[Y * Con.W + X].Attributes := ConAttr;
      end;
  ConMark(Max(X0, 0), Max(Y0, 0));
  ConMark(Min(X1, Con.W - 1), Min(Y1, Con.Hh - 1));
end;

procedure ConSgr(const P: array of Integer; N: Integer);
var
  I: Integer;
begin
  if N = 0 then
  begin
    Con.Fg := 7;
    Con.Bg := 0;
    Con.Rev := False;
    Exit;
  end;
  I := 0;
  while I < N do
  begin
    case P[I] of
      0: begin Con.Fg := 7; Con.Bg := 0; Con.Rev := False; end;
      7: Con.Rev := True;
      27: Con.Rev := False;
      30..37: Con.Fg := AnsiToCon(P[I] - 30);
      90..97: Con.Fg := AnsiToCon(P[I] - 90 + 8);
      39: Con.Fg := 7;
      40..47: Con.Bg := AnsiToCon(P[I] - 40);
      100..107: Con.Bg := AnsiToCon(P[I] - 100 + 8);
      49: Con.Bg := 0;
      38, 48:
        begin
          if (I + 2 < N) and (P[I + 1] = 5) then
          begin
            if P[I] = 38 then Con.Fg := XtermToCon(P[I + 2]) else Con.Bg := XtermToCon(P[I + 2]);
            Inc(I, 2);
          end
          else if (I + 4 < N) and (P[I + 1] = 2) then
          begin
            if P[I] = 38 then Con.Fg := RgbToCon(P[I + 2], P[I + 3], P[I + 4])
            else Con.Bg := RgbToCon(P[I + 2], P[I + 3], P[I + 4]);
            Inc(I, 4);
          end;
        end;
    end;
    Inc(I);
  end;
end;

{ one CSI sequence: Priv is the character after '[' if it is one of <=>?, Inter the intermediate byte, Final the last one }
procedure ConCsi(Priv, Inter, Final: Char; const P: array of Integer; N: Integer);
var
  A, B, I: Integer;
begin
  A := 1;
  B := 1;
  if N > 0 then
    A := P[0];
  if N > 1 then
    B := P[1];
  if Priv = '?' then
  begin
    if (Final = 'h') or (Final = 'l') then
      for I := 0 to N - 1 do
        case P[I] of
          25: Con.CaretOn := Final = 'h';
          1000, 1002, 1003, 1006: if Final = 'h' then Con.Mouse := True else Con.Mouse := False;
        end;
    Exit;
  end;
  if Priv <> #0 then
    Exit;
  if (Inter = ' ') and (Final = 'q') then
  begin
    if (N = 0) or (P[0] in [0, 1, 2]) then
      Con.CaretSize := 100                    { block }
    else
      Con.CaretSize := 15;                    { underline }
    Exit;
  end;
  case Final of
    'H', 'f':
      begin
        if A < 1 then A := 1;
        if B < 1 then B := 1;
        Con.Y := A - 1;
        Con.X := B - 1;
      end;
    'G': Con.X := Max(A, 1) - 1;
    'A': Dec(Con.Y, Max(A, 1));
    'B': Inc(Con.Y, Max(A, 1));
    'C': Inc(Con.X, Max(A, 1));
    'D': Dec(Con.X, Max(A, 1));
    'J':
      begin
        if (N = 0) or (P[0] = 0) then
        begin
          ConErase(Con.X, Con.Y, Con.W - 1, Con.Y);
          ConErase(0, Con.Y + 1, Con.W - 1, Con.Hh - 1);
        end
        else if P[0] = 1 then
        begin
          ConErase(0, 0, Con.W - 1, Con.Y - 1);
          ConErase(0, Con.Y, Con.X, Con.Y);
        end
        else
        begin
          ConAlloc;                           { the size of the window may have changed }
          ConErase(0, 0, Con.W - 1, Con.Hh - 1);
        end;
      end;
    'K':
      if (N = 0) or (P[0] = 0) then
        ConErase(Con.X, Con.Y, Con.W - 1, Con.Y)
      else if P[0] = 1 then
        ConErase(0, Con.Y, Con.X, Con.Y)
      else
        ConErase(0, Con.Y, Con.W - 1, Con.Y);
    'm': ConSgr(P, N);
  end;
end;

{ takes the bytes that TvAnsi wrote; what is not complete (an escape sequence, a UTF-8 character) waits for the next call }
procedure ConFeed(Data: PByte; Len: Integer);
var
  Buf: array[0..65535] of Byte;
  Total, I, J, N, Used: Integer;
  Prm: array[0..15] of Integer;
  Priv, Inter: Char;
  CP: LongWord;
  Num: Integer;
  Have: Boolean;
begin
  Total := 0;
  if Con.CarryLen > 0 then
  begin
    Move(Con.Carry[0], Buf[0], Con.CarryLen);
    Total := Con.CarryLen;
    Con.CarryLen := 0;
  end;
  while Len > 0 do
  begin
    N := Len;
    if N > SizeOf(Buf) - Total then
      N := SizeOf(Buf) - Total;
    Move(Data^, Buf[Total], N);
    Inc(Total, N);
    Inc(Data, N);
    Dec(Len, N);
    I := 0;
    while I < Total do
    begin
      if Buf[I] = 27 then
      begin
        if I + 1 >= Total then
          Break;
        if Buf[I + 1] <> Ord('[') then
        begin
          Inc(I, 2);                          { another escape sequence of two bytes: skipped }
          Continue;
        end;
        J := I + 2;
        Priv := #0;
        Inter := #0;
        N := 0;
        Num := 0;
        Have := False;
        if (J < Total) and (Buf[J] in [Ord('<'), Ord('='), Ord('>'), Ord('?')]) then
        begin
          Priv := Char(Buf[J]);
          Inc(J);
        end;
        while (J < Total) and (Buf[J] in [Ord('0')..Ord('9'), Ord(';'), Ord(':')]) do
        begin
          if Buf[J] in [Ord(';'), Ord(':')] then
          begin
            if N < High(Prm) then
            begin
              Prm[N] := Num;
              Inc(N);
            end;
            Num := 0;
            Have := True;
          end
          else
          begin
            Num := Num * 10 + (Buf[J] - Ord('0'));
            if Num > 100000 then
              Num := 100000;
            Have := True;
          end;
          Inc(J);
        end;
        if Have and (N < High(Prm)) then
        begin
          Prm[N] := Num;
          Inc(N);
        end;
        while (J < Total) and (Buf[J] in [$20..$2F]) do
        begin
          Inter := Char(Buf[J]);
          Inc(J);
        end;
        if J >= Total then
          Break;                              { the sequence is not complete }
        ConCsi(Priv, Inter, Char(Buf[J]), Prm, N);
        I := J + 1;
      end
      else if Buf[I] < $20 then
      begin
        case Buf[I] of
          13: Con.X := 0;
          10: Inc(Con.Y);
          8: if Con.X > 0 then Dec(Con.X);
        end;
        Inc(I);
      end
      else if Buf[I] < $80 then
      begin
        ConPutChar(Buf[I]);
        Inc(I);
      end
      else
      begin
        if (Utf8BytesLeft(Buf[I]) >= 0) and (I + Utf8BytesLeft(Buf[I]) >= Total) then
          Break;                              { the character is not complete }
        if Utf8Decode(@Buf[I], Total - I, CP, Used) then
        begin
          ConPutChar(CP);
          Inc(I, Used);
        end
        else
        begin
          ConPutChar(Ord('?'));
          Inc(I);
        end;
      end;
    end;
    { what is left (not complete) goes to the beginning of the buffer }
    Total := Total - I;
    if Total > SizeOf(Con.Carry) then
      Total := 0                               { too long to be a sequence: dropped }
    else if Total > 0 then
      Move(Buf[I], Buf[0], Total);
    if Len = 0 then
    begin
      Move(Buf[0], Con.Carry[0], Total);
      Con.CarryLen := Total;
    end;
  end;
  ConFlush;
end;

procedure ConEnter;
var
  Sa: SECURITY_ATTRIBUTES;
  Path: string;
begin
  Con.On := True;
  Con.Orig := HOut;
  FillChar(Sa, SizeOf(Sa), 0);
  Sa.nLength := SizeOf(Sa);
  Con.H := CreateConsoleScreenBuffer(GENERIC_READ or GENERIC_WRITE, FILE_SHARE_READ or FILE_SHARE_WRITE, Sa, CONSOLE_TEXTMODE_BUFFER, nil);
  if Con.H = INVALID_HANDLE_VALUE then
    Con.H := HOut                              { no buffer of our own: the screen of the console is used }
  else
    SetConsoleActiveScreenBuffer(Con.H);
  Con.X := 0;
  Con.Y := 0;
  Con.Fg := 7;
  Con.Bg := 0;
  Con.Rev := False;
  Con.CaretOn := False;
  Con.CaretSize := 25;
  Con.CarryLen := 0;
  Con.Mouse := False;
  Con.LastButtons := 0;
  { DN_WIN_BRIGHT_BG=1: backgrounds 8..15 as they are; 0: without the intensity bit; not set: 0 on Wine (the terminal of Wine loses the bright
    background of some cells: two shades on one panel), 1 on Windows }
  Path := SysUtils.GetEnvironmentVariable('DN_WIN_BRIGHT_BG');
  Con.DimBg := (Path = '0') or ((Path = '') and RunsOnWine);
  Con.Cells := nil;
  ConAlloc;
end;

procedure ConLeave;
begin
  if not Con.On then
    Exit;
  if Con.H <> Con.Orig then
  begin
    SetConsoleActiveScreenBuffer(Con.Orig);
    CloseHandle(Con.H);
  end;
  if Con.Cells <> nil then
    FreeMem(Con.Cells);
  Con.Cells := nil;
  Con.On := False;
end;

function OsIsTerminal: Boolean;
var
  M: DWORD;
begin
  HIn := GetStdHandle(STD_INPUT_HANDLE);
  HOut := GetStdHandle(STD_OUTPUT_HANDLE);
  Result := GetConsoleMode(HIn, M) and GetConsoleMode(HOut, M);
end;

procedure OsRawOn;
begin
  GetConsoleMode(HIn, SavedIn);
  GetConsoleMode(HOut, SavedOut);
  SavedCpIn := GetConsoleCP;
  SavedCpOut := GetConsoleOutputCP;
  QHead := 0;
  QTail := 0;
  if SysUtils.GetEnvironmentVariable('DN_WIN_OUTPUT') <> 'vt' then
  begin
    { the console mode: no quick edit (it takes the mouse), no echo, no line input; the records of the keys and the mouse are read }
    SetConsoleMode(HIn, ENABLE_MOUSE_INPUT or ENABLE_WINDOW_INPUT or ENABLE_EXTENDED_FLAGS);
    SetConsoleMode(HOut, ENABLE_PROCESSED_OUTPUT);
    ConEnter;
    Exit;
  end;
  { no quick edit (it takes the mouse), no echo and no line input; the keys come as sequences }
  SetConsoleMode(HIn, ENABLE_VIRTUAL_TERMINAL_INPUT or ENABLE_WINDOW_INPUT or ENABLE_EXTENDED_FLAGS);
  SetConsoleMode(HOut, ENABLE_PROCESSED_OUTPUT or ENABLE_VIRTUAL_TERMINAL_PROCESSING or DISABLE_NEWLINE_AUTO_RETURN);
  SetConsoleCP(CP_UTF8_);
  SetConsoleOutputCP(CP_UTF8_);
end;

procedure OsRawOff;
begin
  ConLeave;
  SetConsoleMode(HIn, SavedIn);
  SetConsoleMode(HOut, SavedOut);
  SetConsoleCP(SavedCpIn);
  SetConsoleOutputCP(SavedCpOut);
end;

procedure OsWrite(P: PByte; Len: Integer);
var
  Done: DWORD;
begin
  if Con.On then
  begin
    ConFeed(P, Len);
    Exit;
  end;
  while Len > 0 do
  begin
    Done := 0;
    if not WriteFile(HOut, P^, Len, Done, nil) or (Done = 0) then
      Exit;
    Inc(P, Done);
    Dec(Len, Integer(Done));
  end;
end;

procedure Put(B: Byte);
begin
  if QTail < SizeOf(Queue) then
  begin
    Queue[QTail] := B;
    Inc(QTail);
  end;
end;

procedure PutUtf8(CP: LongWord);
begin
  if CP < $80 then
    Put(CP)
  else if CP < $800 then
  begin
    Put($C0 or (CP shr 6));
    Put($80 or (CP and $3F));
  end
  else if CP < $10000 then
  begin
    Put($E0 or (CP shr 12));
    Put($80 or ((CP shr 6) and $3F));
    Put($80 or (CP and $3F));
  end
  else
  begin
    Put($F0 or (CP shr 18));
    Put($80 or ((CP shr 12) and $3F));
    Put($80 or ((CP shr 6) and $3F));
    Put($80 or (CP and $3F));
  end;
end;

procedure PutStr(const S: string);
var
  I: Integer;
begin
  for I := 1 to Length(S) do
    Put(Byte(S[I]));
end;

{ the key of the console mode as the sequence that a terminal sends (xterm: CSI 1;m X, CSI n;m ~, SS3 P..S) }
procedure ConKey(const K: KEY_EVENT_RECORD);
var
  Cs: DWORD;
  Alt, Ctrl, Shift, AltGr: Boolean;
  Md, R, N: Integer;
  C: Word;
  T: string;

  function Pre(const Base: string; const Fin: Char): string;      { CSI [1;m] Fin }
  begin
    if Md > 1 then
      Result := #27'[1;' + IntToStr(Md) + Fin
    else
      Result := #27'[' + Base + Fin;
  end;

  function Tilde(Num: Integer): string;                            { CSI n [;m] ~ }
  begin
    Result := #27'[' + IntToStr(Num);
    if Md > 1 then
      Result := Result + ';' + IntToStr(Md);
    Result := Result + '~';
  end;

begin
  Cs := K.dwControlKeyState;
  Shift := (Cs and SHIFT_PRESSED) <> 0;
  AltGr := ((Cs and RIGHT_ALT_PRESSED) <> 0) and ((Cs and LEFT_CTRL_PRESSED) <> 0);
  Alt := ((Cs and (LEFT_ALT_PRESSED or RIGHT_ALT_PRESSED)) <> 0) and not AltGr;
  Ctrl := ((Cs and (LEFT_CTRL_PRESSED or RIGHT_CTRL_PRESSED)) <> 0) and not AltGr;
  Md := 1 + Ord(Shift) + 2 * Ord(Alt) + 4 * Ord(Ctrl);
  T := '';
  case K.wVirtualKeyCode of
    VK_BACK: T := #$7F;
    VK_TAB: if Shift and not Alt and not Ctrl then T := #27'[Z' else T := #9;
    VK_RETURN: T := #13;
    VK_ESCAPE: T := #27;
    VK_PRIOR: T := Tilde(5);
    VK_NEXT: T := Tilde(6);
    VK_END: T := Pre('', 'F');
    VK_HOME: T := Pre('', 'H');
    VK_LEFT: T := Pre('', 'D');
    VK_UP: T := Pre('', 'A');
    VK_RIGHT: T := Pre('', 'C');
    VK_DOWN: T := Pre('', 'B');
    VK_INSERT: T := Tilde(2);
    VK_DELETE: T := Tilde(3);
    VK_F1..VK_F4:
      if Md > 1 then
        T := #27'[1;' + IntToStr(Md) + Chr(Ord('P') + K.wVirtualKeyCode - VK_F1)
      else
        T := #27'O' + Chr(Ord('P') + K.wVirtualKeyCode - VK_F1);
    VK_F5: T := Tilde(15);
    VK_F6: T := Tilde(17);
    VK_F7: T := Tilde(18);
    VK_F8: T := Tilde(19);
    VK_F9: T := Tilde(20);
    VK_F10: T := Tilde(21);
    VK_F11: T := Tilde(23);
    VK_F12: T := Tilde(24);
  end;
  for R := 1 to Max(1, K.wRepeatCount) do
  begin
    if T <> '' then
    begin
      if Alt and (K.wVirtualKeyCode in [VK_BACK, VK_TAB, VK_RETURN, VK_ESCAPE]) then
        Put(27);
      PutStr(T);
    end
    else
    begin
      C := Word(K.UnicodeChar);
      if C = 0 then
        Continue;
      if (C >= $D800) and (C < $DC00) then
        HighSurrogate := C
      else if (C >= $DC00) and (C < $E000) and (HighSurrogate <> 0) then
      begin
        PutUtf8($10000 + ((LongWord(HighSurrogate) - $D800) shl 10) + (C - $DC00));
        HighSurrogate := 0;
      end
      else
      begin
        if Alt then
          Put(27);
        PutUtf8(C);
      end;
    end;
  end;
  N := 0;
  if N <> 0 then
    Exit;
end;

{ the mouse of the console mode as the SGR report of a terminal (CSI < b ; x ; y M or m), when the program asked for the mouse }
procedure ConMouse(const M: MOUSE_EVENT_RECORD);
const
  Codes: array[0..2] of Integer = (0, 2, 1);        { the buttons of the console: left, right, middle -> 0, 2, 1 of the terminal }
  Bits: array[0..2] of DWORD = (1, 2, 4);
var
  Cs, Cur, Changed: DWORD;
  Md, I, B: Integer;
  Delta: SmallInt;

  procedure Report(Code: Integer; Press: Boolean);
  begin
    PutStr(#27'[<' + IntToStr(Code + Md) + ';' + IntToStr(M.dwMousePosition.X + 1) + ';' + IntToStr(M.dwMousePosition.Y + 1) +
      Chr(Ord('m') - Ord(Press) * (Ord('m') - Ord('M'))));
  end;

begin
  Cs := M.dwControlKeyState;
  Md := 0;
  if (Cs and SHIFT_PRESSED) <> 0 then Inc(Md, 4);
  if (Cs and (LEFT_ALT_PRESSED or RIGHT_ALT_PRESSED)) <> 0 then Inc(Md, 8);
  if (Cs and (LEFT_CTRL_PRESSED or RIGHT_CTRL_PRESSED)) <> 0 then Inc(Md, 16);
  Cur := M.dwButtonState and 7;
  if not Con.Mouse then
  begin
    Con.LastButtons := Cur;
    Exit;
  end;
  if (M.dwEventFlags and MOUSE_WHEELED) <> 0 then
  begin
    Delta := SmallInt(M.dwButtonState shr 16);
    if Delta > 0 then Report(64, True) else Report(65, True);
    Exit;
  end;
  if (M.dwEventFlags and 8) <> 0 then            { horizontal wheel: not used }
    Exit;
  Changed := Cur xor Con.LastButtons;
  for I := 0 to 2 do
    if (Changed and Bits[I]) <> 0 then
      Report(Codes[I], (Cur and Bits[I]) <> 0);
  if (Changed = 0) and ((M.dwEventFlags and MOUSE_MOVED) <> 0) and (Cur <> 0) then
  begin
    B := 0;
    for I := 2 downto 0 do
      if (Cur and Bits[I]) <> 0 then
        B := Codes[I];
    Report(B + 32, True);
  end;
  Con.LastButtons := Cur;
end;

{ reads the console records that are there: the characters of the key events (they are the bytes of the sequences) go to the queue as UTF-8 }
procedure Pump;
var
  N, Got, I: DWORD;
  Recs: array[0..127] of INPUT_RECORD;
  C: Word;
begin
  N := 0;
  if not GetNumberOfConsoleInputEvents(HIn, N) or (N = 0) then
    Exit;
  if N > Length(Recs) then
    N := Length(Recs);
  Got := 0;
  if not ReadConsoleInputW(HIn, Recs[0], N, Got) then
    Exit;
  for I := 0 to Got - 1 do
    case Recs[I].EventType of
      2:                                        { MOUSE_EVENT }
        if Con.On then
          ConMouse(Recs[I].Event.MouseEvent);
      KEY_EVENT:
        if Con.On then
        begin
          if Recs[I].Event.KeyEvent.bKeyDown then
            ConKey(Recs[I].Event.KeyEvent);
        end
        else if Recs[I].Event.KeyEvent.bKeyDown then
        begin
          C := Word(Recs[I].Event.KeyEvent.UnicodeChar);
          if C = 0 then
            Continue;
          if (C >= $D800) and (C < $DC00) then
            HighSurrogate := C
          else if (C >= $DC00) and (C < $E000) and (HighSurrogate <> 0) then
          begin
            PutUtf8($10000 + ((LongWord(HighSurrogate) - $D800) shl 10) + (C - $DC00));
            HighSurrogate := 0;
          end
          else
            PutUtf8(C);
        end;
      WINDOW_BUFFER_SIZE_EVENT:
        OsResizeFlag := 1;
    end;
end;

function OsInputReady(TimeoutMs: Integer): Boolean;
var
  Start: Int64;
  W: DWORD;
begin
  if QHead < QTail then
    Exit(True);
  QHead := 0;
  QTail := 0;
  Start := GetTickCount64;
  repeat
    Pump;
    if QHead < QTail then
      Exit(True);
    if TimeoutMs = 0 then
      Exit(False);
    if TimeoutMs < 0 then
      W := 1000
    else
    begin
      if GetTickCount64 - Start >= TimeoutMs then
        Exit(False);
      W := TimeoutMs - (GetTickCount64 - Start);
    end;
    if OsResizeFlag <> 0 then
      Exit(False);
    WaitForSingleObject(HIn, W);
  until False;
end;

function OsRead(var Buf; Size: Integer): Integer;
begin
  if QHead >= QTail then
    OsInputReady(0);
  Result := QTail - QHead;
  if Result > Size then
    Result := Size;
  if Result > 0 then
  begin
    Move(Queue[QHead], Buf, Result);
    Inc(QHead, Result);
  end;
end;

procedure OsSize(out W, H: Integer);
var
  Info: CONSOLE_SCREEN_BUFFER_INFO;
begin
  W := 80;
  H := 25;
  if GetConsoleScreenBufferInfo(Con.H * Ord(Con.On) + HOut * Ord(not Con.On), Info) then
  begin
    W := Info.srWindow.Right - Info.srWindow.Left + 1;
    H := Info.srWindow.Bottom - Info.srWindow.Top + 1;
  end;
end;

function CtrlHandler(CtrlType: DWORD): WINBOOL; stdcall;
begin
  { the window is closed, the user logs off, the system shuts down: the terminal is put in order and the program ends }
  Result := False;
  if (CtrlType in [CTRL_CLOSE_EVENT, CTRL_LOGOFF_EVENT, CTRL_SHUTDOWN_EVENT]) and Assigned(CtrlProc) then
    CtrlProc;
end;

procedure OsHandlersOn(AfterDeath: TOsHook);
begin
  CtrlProc := AfterDeath;
  SetConsoleCtrlHandler(@CtrlHandler, True);
end;

procedure OsHandlersOff;
begin
  SetConsoleCtrlHandler(@CtrlHandler, False);
end;

procedure OsExit(Code: Integer);
begin
  ExitProcess(Code);
end;

{$ENDIF WINDOWS}

{$IF NOT DEFINED(UNIX) AND NOT DEFINED(WINDOWS)}
function OsIsTerminal: Boolean;
begin
  Result := False;
end;
procedure OsRawOn;
begin
end;
procedure OsRawOff;
begin
end;
procedure OsWrite(P: PByte; Len: Integer);
begin
end;
function OsInputReady(TimeoutMs: Integer): Boolean;
begin
  Result := False;
end;
function OsRead(var Buf; Size: Integer): Integer;
begin
  Result := 0;
end;
procedure OsSize(out W, H: Integer);
begin
  W := 80;
  H := 25;
end;
procedure OsHandlersOn(AfterDeath: TOsHook);
begin
end;
procedure OsHandlersOff;
begin
end;
procedure OsExit(Code: Integer);
begin
  Halt(Code);
end;
{$ENDIF}

end.
