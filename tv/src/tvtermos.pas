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
  Windows;
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
  { no quick edit (it takes the mouse), no echo and no line input; the keys come as sequences }
  SetConsoleMode(HIn, ENABLE_VIRTUAL_TERMINAL_INPUT or ENABLE_WINDOW_INPUT or ENABLE_EXTENDED_FLAGS);
  SetConsoleMode(HOut, ENABLE_PROCESSED_OUTPUT or ENABLE_VIRTUAL_TERMINAL_PROCESSING or DISABLE_NEWLINE_AUTO_RETURN);
  SetConsoleCP(CP_UTF8_);
  SetConsoleOutputCP(CP_UTF8_);
  QHead := 0;
  QTail := 0;
end;

procedure OsRawOff;
begin
  SetConsoleMode(HIn, SavedIn);
  SetConsoleMode(HOut, SavedOut);
  SetConsoleCP(SavedCpIn);
  SetConsoleOutputCP(SavedCpOut);
end;

procedure OsWrite(P: PByte; Len: Integer);
var
  Done: DWORD;
begin
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
      KEY_EVENT:
        if Recs[I].Event.KeyEvent.bKeyDown then
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
  if GetConsoleScreenBufferInfo(HOut, Info) then
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
