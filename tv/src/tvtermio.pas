{ TvTermIO: the bytes that a terminal sends (keys, mouse reports) turned into events, and the sequences that
  switch the reporting on and off. Nothing here talks to a terminal: the bytes come through a reader that the
  backend (TvUnix) or a test gives, so all of it can be tested with strings.

  Translated from magiblot/tvision @ b4831e2:
    source/platform/termio.cpp   (TermIO: parseEvent, parseEscapeSeq, parseCSIKey, parseSS3Key, parseKittyKey,
                                  parseX10Mouse, parseSGRMouse, keyFromCodepoint, keyFromLetter, normalizeKey,
                                  mouseOn/mouseOff/keyModsOn/keyModsOff; CSIData, GetChBuf),
    source/platform/ncursinp.cpp (NcursesInput::getEvent: the keys that are not escape sequences: control
                                  characters, Alt = ESC + key, UTF-8 text),
    include/tvision/internal/termio.h.
  Borland disclaimer and MIT notice: tv/COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/DESIGN.md):
    - no ncurses: the keys that its terminfo database gives (arrows, F1-F12 and others without modifiers) come
      here as the plain xterm / VT sequences (CSI A, SS3 P, CSI 15 ~) and as those of the Linux console
      (CSI [ A for F1-F5): parseSS3Key and parseEscapeSeq were extended for that;
    - not translated: far2l extensions, the win32 input mode, the answers to the queries (OSC 52, DCS, DSR): they
      are skipped (their bytes are consumed);
    - the left and right modifiers are one bit each (TvKeys). }
unit TvTermIO;

{$I tvdefs.inc}

interface

uses
  TvEvents, TvKeys, TvUtf8, TvCodePg;

type
  { The next byte, or -1 when none comes within TimeoutMs (0: only if it is there already). }
  TRawReader = function(TimeoutMs: Integer): Integer;

  PTermInput = ^TTermInput;
  TTermInput = object
    Reader: TRawReader;
    ReadTimeoutMs: Integer;          { how long a byte of a sequence is waited for (ESC alone is a key after it) }
    Pending: array[0..63] of Integer;
    PendingCount: Integer;
    procedure Init(AReader: TRawReader; ATimeoutMs: Integer = 25);
    function Get: Integer;           { waits ReadTimeoutMs }
    function GetNb: Integer;         { does not wait }
    procedure Unget(K: Integer);
    function HasPending: Boolean;
  end;

  TInputState = record
    Buttons: Byte;                   { the mouse buttons that are down }
    BracketedPaste: Boolean;
  end;

  TParseResult = (prRejected, prAccepted, prIgnored);

const
  { The text a terminal has to be sent to start and stop reporting the mouse, the modifiers of keys and pasting. }
  SeqMouseOn = #27'[?1001s'#27'[?1000h'#27'[?1002h'#27'[?1006h';
  SeqMouseOff = #27'[?1006l'#27'[?1002l'#27'[?1000l'#27'[?1001r';
  SeqKeyModsOn = #27'[?1036s'#27'[?1036h'#27'[?2004s'#27'[?2004h'#27'[>4;1m'#27'[>5u'#27'[2J';
  SeqKeyModsOff = #27'[<u'#27'[>4m'#27'[?2004l'#27'[?2004r'#27'[?1036r';

{ Reads one event from the input. True: Event is a key down event or a mouse event (What = evMouse: the raw report,
  Where, Buttons, Wheel and ControlKeyState are set; TvMouse makes the real events). False: nothing (the bytes were
  an answer of the terminal, an unknown sequence, or there were none). }
function ParseEvent(var Input: TTermInput; var Event: TEvent; var State: TInputState): Boolean;

{ The key code that a key gets with Shift (0), Ctrl (1) or Alt (2) held (the largest modifier counts), 0 if none. }
function ModdedKeyCode(KeyCode: Word; Largest: Integer): Word;
{ Makes key combinations canonical (Ctrl+A is kbCtrlA; with Ctrl and Alt it is the key of Alt). }
procedure NormalizeKey(var Event: TEvent);

implementation

const
  XTermModDefault = 1;
  MaxBuf = 31;
  MaxCsi = 6;
  NoValue = $FFFFFFFF;

procedure TTermInput.Init(AReader: TRawReader; ATimeoutMs: Integer);
begin
  Reader := AReader;
  ReadTimeoutMs := ATimeoutMs;
  PendingCount := 0;
end;

function TTermInput.Get: Integer;
begin
  if PendingCount > 0 then
  begin
    Dec(PendingCount);
    Exit(Pending[PendingCount]);
  end;
  if Assigned(Reader) then
    Result := Reader(ReadTimeoutMs)
  else
    Result := -1;
end;

function TTermInput.GetNb: Integer;
begin
  if PendingCount > 0 then
    Exit(Get);
  if Assigned(Reader) then
    Result := Reader(0)
  else
    Result := -1;
end;

procedure TTermInput.Unget(K: Integer);
begin
  if PendingCount <= High(Pending) then
  begin
    Pending[PendingCount] := K;
    Inc(PendingCount);
  end;
end;

function TTermInput.HasPending: Boolean;
begin
  Result := PendingCount > 0;
end;

{ --- GetChBuf: what was read by a parser, to be given back when it rejects the input --------------------------- }

type
  PGetChBuf = ^TGetChBuf;
  TGetChBuf = object
    Size: Integer;
    Keys: array[0..MaxBuf - 1] of Integer;
    In_: PTermInput;
    procedure Init(AIn: PTermInput);
    function Get(KeepErr: Boolean = False): Integer;
    function Last(I: Integer = 0): Integer;
    procedure Unget;
    procedure Reject;
    function GetNum(out Value: LongWord): Boolean;
    function GetInt(out Value: Integer): Boolean;
    function ReadStr(const S: string): Boolean;
  end;

procedure TGetChBuf.Init(AIn: PTermInput);
begin
  In_ := AIn;
  Size := 0;
end;

function TGetChBuf.Get(KeepErr: Boolean): Integer;
begin
  if Size < MaxBuf then
  begin
    Result := In_^.Get;
    if KeepErr or (Result <> -1) then
    begin
      Keys[Size] := Result;
      Inc(Size);
    end;
  end
  else
    Result := -1;
end;

function TGetChBuf.Last(I: Integer): Integer;
begin
  if (I >= 0) and (I < Size) then
    Result := Keys[Size - 1 - I]
  else
    Result := -1;
end;

procedure TGetChBuf.Unget;
var
  K: Integer;
begin
  if Size > 0 then
  begin
    Dec(Size);
    K := Keys[Size];
    if K <> -1 then
      In_^.Unget(K);
  end;
end;

procedure TGetChBuf.Reject;
begin
  while Size > 0 do
    Unget;
end;

{ INVARIANT of GetNum and GetInt: the last key that is not a digit (or -1) can be had with Last and given back. }
function TGetChBuf.GetNum(out Value: LongWord): Boolean;
var
  Num, Digits: LongWord;
  K: Integer;
begin
  Num := 0;
  Digits := 0;
  K := Get(True);
  while (K >= Ord('0')) and (K <= Ord('9')) do
  begin
    Num := 10 * Num + LongWord(K - Ord('0'));
    Inc(Digits);
    K := Get(True);
  end;
  Value := Num;
  Result := Digits > 0;
end;

function TGetChBuf.GetInt(out Value: Integer): Boolean;
var
  Num, Digits, Sign, K: Integer;
begin
  Num := 0;
  Digits := 0;
  Sign := 1;
  K := Get(True);
  if K = Ord('-') then
  begin
    Sign := -1;
    K := Get(True);
  end;
  while (K >= Ord('0')) and (K <= Ord('9')) do
  begin
    Num := 10 * Num + (K - Ord('0'));
    Inc(Digits);
    K := Get(True);
  end;
  Value := Sign * Num;
  Result := Digits > 0;
end;

function TGetChBuf.ReadStr(const S: string): Boolean;
var
  OrigSize, I: Integer;
begin
  OrigSize := Size;
  I := 1;
  while (I <= Length(S)) and (Get = Ord(S[I])) do
    Inc(I);
  if I > Length(S) then
    Exit(True);
  while OrigSize < Size do
    Unget;
  Result := False;
end;

{ --- CSIData ------------------------------------------------------------------------------------------------ }
{ The data of a sequence such as "ESC [ 123 :: 456 ; 789 u": Length 5 is not it: the values are 123, (none), 456,
  789 (Length 4), the separators ':' ':' ';', the terminator 'u'. }

type
  TCsiData = record
    Length: Integer;
    Values: array[0..MaxCsi - 1] of LongWord;
    Separators: array[0..MaxCsi - 2] of Char;
    Terminator: Char;
  end;

function CsiValue(const C: TCsiData; I: Integer; Default: LongWord = 1): LongWord;
begin
  if (I < C.Length) and (C.Values[I] <> NoValue) then
    Result := C.Values[I]
  else
    Result := Default;
end;

function CsiSeparator(const C: TCsiData; I: Integer): Char;
begin
  if (C.Length > 0) and (I < C.Length - 1) then
    Result := C.Separators[I]
  else
    Result := #0;
end;

{ Pre: "ESC [" has just been read. }
function CsiRead(var Buf: TGetChBuf; out C: TCsiData): Boolean;
var
  I, K: Integer;
begin
  C.Length := 0;
  C.Terminator := #0;
  for I := 0 to MaxCsi - 1 do
  begin
    if not Buf.GetNum(C.Values[I]) then
      C.Values[I] := NoValue;
    K := Buf.Last;
    if K = -1 then
      Exit(False);                  { no more input and the sequence is not complete }
    if (K = Ord(';')) or (K = Ord(':')) then
    begin
      if I < MaxCsi - 1 then
        C.Separators[I] := Char(K);
    end
    else
    begin
      C.Terminator := Char(K);
      C.Length := I + 1;
      Exit(True);
    end;
  end;
  Result := False;                  { longer than the supported }
end;

{ --- keys -------------------------------------------------------------------------------------------------- }

function ModdedKeyCode(KeyCode: Word; Largest: Integer): Word;
const
  AltLetters: array[0..25] of Word = (kbAltA, kbAltB, kbAltC, kbAltD, kbAltE, kbAltF, kbAltG, kbAltH, kbAltI,
    kbAltJ, kbAltK, kbAltL, kbAltM, kbAltN, kbAltO, kbAltP, kbAltQ, kbAltR, kbAltS, kbAltT, kbAltU, kbAltV,
    kbAltW, kbAltX, kbAltY, kbAltZ);
  AltDigits: array[0..9] of Word = (kbAlt0, kbAlt1, kbAlt2, kbAlt3, kbAlt4, kbAlt5, kbAlt6, kbAlt7, kbAlt8, kbAlt9);

  { the three key codes (Shift, Ctrl, Alt) of a key; 0 is none }
  function Pick(S, C, A: Word): Word;
  begin
    case Largest of
      0: Result := S;
      1: Result := C;
    else
      Result := A;
    end;
  end;

begin
  Result := 0;
  case KeyCode of
    Ord('A')..Ord('Z'):
      Result := Pick(0, KeyCode - Ord('A') + 1, AltLetters[KeyCode - Ord('A')]);
    Ord('0')..Ord('9'):
      Result := Pick(0, 0, AltDigits[KeyCode - Ord('0')]);
    Ord(' '): Result := Pick(0, 0, kbAltSpace);
    Ord('-'): Result := Pick(0, 0, kbAltMinus);
    Ord('='): Result := Pick(0, 0, kbAltEqual);
    kbF1..kbF10: Result := Pick(KeyCode + $1900, KeyCode + $2300, KeyCode + $2D00);
    kbF11: Result := Pick(kbShiftF11, kbCtrlF11, kbAltF11);
    kbF12: Result := Pick(kbShiftF12, kbCtrlF12, kbAltF12);
    kbEsc: Result := Pick(0, 0, kbAltEsc);
    kbBack: Result := Pick(0, kbCtrlBack, kbAltBack);
    kbTab: Result := Pick(kbShiftTab, kbCtrlTab, kbAltTab);
    kbEnter: Result := Pick(0, kbCtrlEnter, kbAltEnter);
    kbHome: Result := Pick(0, kbCtrlHome, kbAltHome);
    kbUp: Result := Pick(0, kbCtrlUp, kbAltUp);
    kbPgUp: Result := Pick(0, kbCtrlPgUp, kbAltPgUp);
    kbLeft: Result := Pick(0, kbCtrlLeft, kbAltLeft);
    kbRight: Result := Pick(0, kbCtrlRight, kbAltRight);
    kbEnd: Result := Pick(0, kbCtrlEnd, kbAltEnd);
    kbDown: Result := Pick(0, kbCtrlDown, kbAltDown);
    kbPgDn: Result := Pick(0, kbCtrlPgDn, kbAltPgDn);
    kbIns: Result := Pick(kbShiftIns, kbCtrlIns, kbAltIns);
    kbDel: Result := Pick(kbShiftDel, kbCtrlDel, kbAltDel);
  end;
end;

procedure NormalizeKey(var Event: TEvent);
var
  K: TKey;
  NewMods, Orig, Code: Word;
  Largest: Integer;
begin
  K := KeyMake(Event.KeyCode, Event.ControlKeyState);
  NewMods := K.Mods and (kbShift or kbLeftCtrl or kbLeftAlt);
  if NewMods <> 0 then
  begin
    { Shift < Ctrl < Alt }
    if (NewMods and kbLeftAlt) <> 0 then
      Largest := 2
    else if (NewMods and kbLeftCtrl) <> 0 then
      Largest := 1
    else
      Largest := 0;
    Code := ModdedKeyCode(K.Code, Largest);
    if Code <> 0 then
    begin
      Event.KeyCode := Code;
      if Event.CharCode < Ord(' ') then
        Event.TextLength := 0;
    end;
  end;
  { TKey does not tell the left and right modifiers apart; in TvKeys they are one bit, so the union is it }
  Orig := Event.ControlKeyState;
  Event.ControlKeyState := Orig or NewMods;
end;

function PrintableFromCodepoint(CodePoint: LongWord): Byte;
begin
  if CodePoint < $80 then
    Result := Byte(CodePoint)
  else
    Result := CpFromUnicode(CodePoint);
end;

{ the key code with the xterm modifier value (1 + shift 1 + alt 2 + ctrl 4); the text is not set }
procedure KeyWithXTermMods(var Event: TEvent; KeyCode: Word; Mods: LongWord);
var
  TvMods: Word;
begin
  Dec(Mods, XTermModDefault);
  TvMods := 0;
  if (Mods and 1) <> 0 then
    TvMods := TvMods or kbShift;
  if (Mods and 2) <> 0 then
    TvMods := TvMods or kbLeftAlt;
  if (Mods and 4) <> 0 then
    TvMods := TvMods or kbLeftCtrl;
  ClearEvent(Event);
  Event.KeyCode := KeyCode;
  Event.ControlKeyState := TvMods;
  NormalizeKey(Event);
end;

function IsAlpha(C: LongWord): Boolean;
begin
  Result := (C >= Ord(' ')) and (C < 127);
end;

function IsAsciiLetter(C: LongWord): Boolean;
begin
  Result := ((C >= Ord('A')) and (C <= Ord('Z'))) or ((C >= Ord('a')) and (C <= Ord('z')));
end;

function IsPrivate(CodePoint: LongWord): Boolean;
begin
  Result := (CodePoint >= 57344) and (CodePoint <= 63743);
end;

function KeyFromCodepoint(Value, Mods: LongWord; var Event: TEvent): Boolean;
var
  KeyCode: Word;
  CodePoint: LongWord;
begin
  KeyCode := 0;
  case Value of
    8: KeyCode := kbBack;
    9: KeyCode := kbTab;
    13: KeyCode := kbEnter;
    27: KeyCode := kbEsc;
    127: KeyCode := kbBack;
    { the functional keys of Kitty's keyboard protocol: the keypad }
    57399..57408: KeyCode := Ord('0') + (Value - 57399);
    57409: KeyCode := Ord('.');
    57410: KeyCode := Ord('/');
    57411: KeyCode := Ord('*');
    57412: KeyCode := Ord('-');
    57413: KeyCode := Ord('+');
    57414: KeyCode := kbEnter;
    57415: KeyCode := Ord('=');
    57416: KeyCode := Ord(',');
    57417: KeyCode := kbLeft;
    57418: KeyCode := kbRight;
    57419: KeyCode := kbUp;
    57420: KeyCode := kbDown;
    57421: KeyCode := kbPgUp;
    57422: KeyCode := kbPgDn;
    57423: KeyCode := kbHome;
    57424: KeyCode := kbEnd;
    57425: KeyCode := kbIns;
    57426: KeyCode := kbDel;
  else
    if IsAlpha(Value) then
      KeyCode := Word(Value);
  end;
  KeyWithXTermMods(Event, KeyCode, Mods);
  Event.What := evKeyDown;
  if IsAlpha(Event.KeyCode) or ((Event.KeyCode = 0) and (Value >= Ord(' ')) and not IsPrivate(Value)) then
  begin
    if Event.KeyCode = 0 then
      CodePoint := Value
    else
      CodePoint := Event.KeyCode;
    Event.TextLength := Utf8Encode(CodePoint, PByte(@Event.Text[0]));
    Event.CharCode := PrintableFromCodepoint(CodePoint);
  end;
  Result := (Event.KeyCode <> 0) or (Event.TextLength <> 0);
end;

function KeyFromLetter(Letter, Mod_: LongWord; var Event: TEvent): Boolean;
var
  KeyCode: Word;
begin
  case Chr(Letter and $FF) of
    'A': KeyCode := kbUp;
    'B': KeyCode := kbDown;
    'C': KeyCode := kbRight;
    'D': KeyCode := kbLeft;
    'E': KeyCode := kbNoKey;        { numpad 5, "KP_Begin" }
    'F': KeyCode := kbEnd;
    'H': KeyCode := kbHome;
    'P': KeyCode := kbF1;
    'Q': KeyCode := kbF2;
    'R': KeyCode := kbF3;
    'S': KeyCode := kbF4;
    'Z': KeyCode := kbTab;
    { the keypad in XTerm (SS3) }
    'j': KeyCode := Ord('*');
    'k': KeyCode := Ord('+');
    'm': KeyCode := Ord('-');
    'M': KeyCode := kbEnter;
    'n': KeyCode := kbDel;
    'o': KeyCode := Ord('/');
    'p': KeyCode := kbIns;
    'q': KeyCode := kbEnd;
    'r': KeyCode := kbDown;
    's': KeyCode := kbPgDn;
    't': KeyCode := kbLeft;
    'u': KeyCode := kbNoKey;
    'v': KeyCode := kbRight;
    'w': KeyCode := kbHome;
    'x': KeyCode := kbUp;
    'y': KeyCode := kbPgUp;
  else
    Exit(False);
  end;
  if Letter > 255 then
    Exit(False);
  KeyWithXTermMods(Event, KeyCode, Mod_);
  if IsAlpha(Event.KeyCode) then
  begin
    Event.Text[0] := Char(Event.KeyCode);
    Event.TextLength := 1;
  end;
  Result := True;
end;

{ --- mouse reports ------------------------------------------------------------------------------------------ }

const
  mmAlt = $08;
  mmCtrl = $10;

procedure MouseKeys(var Event: TEvent; Mod_: LongWord);
begin
  Event.ControlKeyState := 0;
  if (Mod_ and mmAlt) <> 0 then
    Event.ControlKeyState := Event.ControlKeyState or kbLeftAlt;
  if (Mod_ and mmCtrl) <> 0 then
    Event.ControlKeyState := Event.ControlKeyState or kbLeftCtrl;
end;

{ Pre: "ESC [ M" has just been read; the rest is "abc": a is the button plus 32, b the column plus 32, c the row plus 32. }
function ParseX10Mouse(var Buf: TGetChBuf; var Event: TEvent; var State: TInputState): TParseResult;
var
  ButM, Mod_, But: LongWord;
  Col, Row, I, V: Integer;
begin
  ButM := LongWord(Buf.Get);
  Mod_ := ButM and (mmAlt or mmCtrl);
  But := (ButM and not LongWord(mmAlt or mmCtrl)) - 32;
  if 255 - 32 < But then
    Exit(prRejected);
  Col := 0;
  Row := 0;
  for I := 0 to 1 do
  begin
    V := Buf.Get;
    if (V < 0) or (V > 255) then
      Exit(prRejected);
    { Some terminals (urxvt) keep counting past 255: the value wraps. }
    if V > 32 then
      Dec(V, 32)
    else
      Inc(V, 256 - 32);
    Dec(V);
    if I = 0 then
      Col := V
    else
      Row := V;
  end;
  ClearEvent(Event);
  Event.What := evMouse;
  Event.Where.X := Col;
  Event.Where.Y := Row;
  MouseKeys(Event, Mod_);
  case But of
    0, 32: State.Buttons := State.Buttons or mbLeftButton;
    1, 33: State.Buttons := State.Buttons or mbMiddleButton;
    2, 34: State.Buttons := State.Buttons or mbRightButton;
    3: State.Buttons := 0;
    64: Event.Wheel := mwUp;
    65: Event.Wheel := mwDown;
    66: Event.Wheel := mwLeft;
    67: Event.Wheel := mwRight;
  end;
  Event.Buttons := State.Buttons;
  Result := prAccepted;
end;

{ Pre: "ESC [ <" has just been read; the rest is "a;b;cM" or "a;b;cm": the button, the column and the row (from 1),
  M is a press, wheel or drag, m a release. }
function ParseSgrMouse(var Buf: TGetChBuf; var Event: TEvent; var State: TInputState): TParseResult;
var
  ButM, Mod_, But: LongWord;
  Col, Row, T: Integer;
begin
  if not Buf.GetNum(ButM) then
    Exit(prRejected);
  Mod_ := ButM and (mmAlt or mmCtrl);
  But := ButM and not LongWord(mmAlt or mmCtrl);
  if not Buf.GetInt(Col) or not Buf.GetInt(Row) then
    Exit(prRejected);
  if Row < 1 then
    Row := 1;
  if Col < 1 then
    Col := 1;
  Dec(Row);
  Dec(Col);
  T := Buf.Last;
  if not ((T = Ord('M')) or (T = Ord('m'))) then
    Exit(prRejected);
  ClearEvent(Event);
  Event.What := evMouse;
  Event.Where.X := Col;
  Event.Where.Y := Row;
  MouseKeys(Event, Mod_);
  if T = Ord('M') then
    case But of
      0, 32: State.Buttons := State.Buttons or mbLeftButton;
      1, 33: State.Buttons := State.Buttons or mbMiddleButton;
      2, 34: State.Buttons := State.Buttons or mbRightButton;
      64: Event.Wheel := mwUp;
      65: Event.Wheel := mwDown;
      66: Event.Wheel := mwLeft;
      67: Event.Wheel := mwRight;
    end
  else
    case But of
      0: State.Buttons := State.Buttons and not mbLeftButton;
      1: State.Buttons := State.Buttons and not mbMiddleButton;
      2: State.Buttons := State.Buttons and not mbRightButton;
    end;
  Event.Buttons := State.Buttons;
  Result := prAccepted;
end;

{ --- sequences ---------------------------------------------------------------------------------------------- }

function SetKey(var Event: TEvent; KeyCode, Mods: Word): TParseResult;
begin
  ClearEvent(Event);
  Event.KeyCode := KeyCode;
  Event.ControlKeyState := Mods;
  Event.What := evKeyDown;
  Result := prAccepted;
end;

function ParseCsiKey(const Csi: TCsiData; var Event: TEvent; var State: TInputState): TParseResult;
var
  Term: Char;
  Mod_, Key: LongWord;
  KeyCode: Word;
begin
  Term := Csi.Terminator;
  if (Csi.Length = 1) and (Term = '~') then
  begin
    case CsiValue(Csi, 0) of
      1: Exit(SetKey(Event, kbHome, 0));
      2: Exit(SetKey(Event, kbIns, 0));
      3: Exit(SetKey(Event, kbDel, 0));
      4: Exit(SetKey(Event, kbEnd, 0));
      5: Exit(SetKey(Event, kbPgUp, 0));
      6: Exit(SetKey(Event, kbPgDn, 0));
      { these numbers can be understood as F1-F12 as well as F1-F10; Putty uses F1-F10 }
      11: Exit(SetKey(Event, kbF1, 0));
      12: Exit(SetKey(Event, kbF2, 0));
      13: Exit(SetKey(Event, kbF3, 0));
      14: Exit(SetKey(Event, kbF4, 0));
      15: Exit(SetKey(Event, kbF5, 0));
      17: Exit(SetKey(Event, kbF6, 0));
      18: Exit(SetKey(Event, kbF7, 0));
      19: Exit(SetKey(Event, kbF8, 0));
      20: Exit(SetKey(Event, kbF9, 0));
      21: Exit(SetKey(Event, kbF10, 0));
      23: Exit(SetKey(Event, kbShiftF1, kbShift));
      24: Exit(SetKey(Event, kbShiftF2, kbShift));
      25: Exit(SetKey(Event, kbShiftF3, kbShift));
      26: Exit(SetKey(Event, kbShiftF4, kbShift));
      28: Exit(SetKey(Event, kbShiftF5, kbShift));
      29: Exit(SetKey(Event, kbShiftF6, kbShift));
      31: Exit(SetKey(Event, kbShiftF7, kbShift));
      32: Exit(SetKey(Event, kbShiftF8, kbShift));
      33: Exit(SetKey(Event, kbShiftF9, kbShift));
      34: Exit(SetKey(Event, kbShiftF10, kbShift));
      200: begin State.BracketedPaste := True; Exit(prIgnored); end;
      201: begin State.BracketedPaste := False; Exit(prIgnored); end;
    else
      Exit(prRejected);
    end;
  end
  else if (Csi.Length = 1) and (Term = 'Z') and (Csi.Values[0] = NoValue) then
    Exit(SetKey(Event, kbShiftTab, kbShift))     { the back tab (terminfo kcbt: ncurses gave it) }
  else if (Csi.Length = 1) and (CsiValue(Csi, 0) = 1) then
  begin
    if not KeyFromLetter(Ord(Term), XTermModDefault, Event) then
      Exit(prRejected);
  end
  else if (Csi.Length = 2) and (CsiSeparator(Csi, 0) = ';') then
  begin
    Mod_ := CsiValue(Csi, 1);
    if CsiValue(Csi, 0) = 1 then
    begin
      if not KeyFromLetter(Ord(Term), Mod_, Event) then
        Exit(prRejected);
    end
    else if Term = '~' then
    begin
      case CsiValue(Csi, 0) of
        2: KeyCode := kbIns;
        3: KeyCode := kbDel;
        5: KeyCode := kbPgUp;
        6: KeyCode := kbPgDn;
        11: KeyCode := kbF1;
        12: KeyCode := kbF2;
        13: KeyCode := kbF3;
        14: KeyCode := kbF4;
        15: KeyCode := kbF5;
        17: KeyCode := kbF6;
        18: KeyCode := kbF7;
        19: KeyCode := kbF8;
        20: KeyCode := kbF9;
        21: KeyCode := kbF10;
        23: KeyCode := kbF11;
        24: KeyCode := kbF12;
        29: KeyCode := kbNoKey;     { the menu key (XTerm) }
      else
        Exit(prRejected);
      end;
      KeyWithXTermMods(Event, KeyCode, Mod_);
    end
    else
      Exit(prRejected);
  end
  else if (Csi.Length = 3) and (CsiValue(Csi, 0) = 27) and (CsiSeparator(Csi, 0) = ';') and
    (CsiSeparator(Csi, 1) = ';') and (Term = '~') then
  begin
    { the "modifyOtherKeys" mode of XTerm }
    Key := CsiValue(Csi, 2);
    Mod_ := CsiValue(Csi, 1);
    if not KeyFromCodepoint(Key, Mod_, Event) then
      Exit(prIgnored);
  end
  else
    Exit(prRejected);
  Event.What := evKeyDown;
  Result := prAccepted;
end;

{ Pre: "ESC O" has just been read: F1-F4 and the keypad, with or without the modifier ("ESC O 2 P"). }
function ParseSs3Key(var Buf: TGetChBuf; var Event: TEvent): TParseResult;
var
  Mod_: LongWord;
  Key: Integer;
begin
  { the extension: without digits the key is the one that ended the number }
  if not Buf.GetNum(Mod_) then
    Mod_ := XTermModDefault;
  Key := Buf.Last;
  if Key < 0 then
    Exit(prRejected);
  if not KeyFromLetter(LongWord(Key), Mod_, Event) then
    Exit(prRejected);
  Event.What := evKeyDown;
  Result := prAccepted;
end;

{ the keyboard protocol of Kitty: "ESC [ code : shifted : base ; modifiers : event type ; text u" }
function ParseKittyKey(const Csi: TCsiData; var Event: TEvent): TParseResult;
var
  KeyCode, Shifted, BaseLayout, Mods, EventType, Text, CodePoint: LongWord;
  I: Integer;
  Up, Big: Word;
begin
  if (Csi.Length < 1) or (Csi.Terminator <> 'u') then
    Exit(prRejected);
  Shifted := 0;
  BaseLayout := 0;
  Mods := 1;
  EventType := 1;
  Text := 0;
  I := 0;
  KeyCode := CsiValue(Csi, I, 0);
  Inc(I);
  if (I < Csi.Length) and (CsiSeparator(Csi, I - 1) = ':') then
  begin
    Shifted := CsiValue(Csi, I, 0);
    Inc(I);
  end;
  if (I < Csi.Length) and (CsiSeparator(Csi, I - 1) = ':') then
  begin
    BaseLayout := CsiValue(Csi, I, 0);
    Inc(I);
  end;
  if I < Csi.Length then
  begin
    Mods := CsiValue(Csi, I, 1);
    Inc(I);
  end;
  if (I < Csi.Length) and (CsiSeparator(Csi, I - 1) = ':') then
  begin
    EventType := CsiValue(Csi, I, 1);
    Inc(I);
  end;
  if I < Csi.Length then
    Text := CsiValue(Csi, I, 0);       { there could be more characters: the first is taken }
  if EventType <> 1 then
    Exit(prIgnored);                   { only the presses }
  CodePoint := KeyCode;
  if Text <> 0 then
    CodePoint := Text
  else if Shifted <> 0 then
    CodePoint := Shifted;
  if not KeyFromCodepoint(CodePoint, Mods, Event) then
    Exit(prIgnored);
  { a key of a non-Latin layout that is a Latin letter in the base layout (Ctrl+Ф is Ctrl+A) }
  if (not IsAsciiLetter(KeyCode)) and IsAsciiLetter(BaseLayout) and
    ((Event.ControlKeyState and (kbCtrlShift or kbAltShift)) <> 0) then
  begin
    Up := Word(BaseLayout - Ord('a') + Ord('A'));
    if (Event.ControlKeyState and kbAltShift) <> 0 then
      Big := 2
    else
      Big := 1;
    if ModdedKeyCode(Up, Big) <> 0 then
      Event.KeyCode := ModdedKeyCode(Up, Big);
  end;
  Event.What := evKeyDown;
  Result := prAccepted;
end;

{ the end of a string sequence: BEL or ESC \ }
procedure SkipUntilBelOrSt(var Buf: TGetChBuf);
var
  K: Integer;
  Count: Integer;
begin
  Count := 0;
  repeat
    K := Buf.Get;
    Inc(Count);
    if K = 27 then
    begin
      K := Buf.Get;
      if K = Ord('\') then
        Exit;
    end;
  until (K = -1) or (K = 7) or (Count > 4096);
end;

function ParseEscapeSeq(var Buf: TGetChBuf; var Event: TEvent; var State: TInputState): TParseResult;
var
  K: Integer;
  Csi: TCsiData;
  Res: TParseResult;
begin
  Res := prRejected;
  K := Buf.Get;
  case K of
    Ord('['):
      begin
        K := Buf.Get;
        case K of
          Ord('M'):
            if ParseX10Mouse(Buf, Event, State) = prAccepted then
              Exit(prAccepted)
            else
              Exit(prIgnored);
          Ord('<'):
            if ParseSgrMouse(Buf, Event, State) = prAccepted then
              Exit(prAccepted)
            else
              Exit(prIgnored);
          Ord('['):
            begin
              { the Linux console: F1-F5 are "ESC [ [ A" ... "ESC [ [ E" }
              K := Buf.Get;
              if (K >= Ord('A')) and (K <= Ord('E')) then
                Exit(SetKey(Event, kbF1 + (K - Ord('A')) * $100, 0));
            end;
        else
          begin
            if K < 0 then
              Exit(prRejected);
            Buf.Unget;
            if CsiRead(Buf, Csi) then
              case Csi.Terminator of
                'u': Exit(ParseKittyKey(Csi, Event));
                'R': Exit(prIgnored);          { the answer to a query of the cursor position }
                '_': Exit(prIgnored);          { the win32 input mode is not asked for }
              else
                Exit(ParseCsiKey(Csi, Event, State));
              end;
          end;
        end;
      end;
    Ord('O'):
      Exit(ParseSs3Key(Buf, Event));
    Ord('P'), Ord(']'), Ord('_'):
      begin
        { strings that the terminal answers to our questions (DCS, OSC) or sends by itself (far2l): not used }
        SkipUntilBelOrSt(Buf);
        Exit(prIgnored);
      end;
    27:
      begin
        Res := ParseEscapeSeq(Buf, Event, State);
        if (Res = prAccepted) and (Event.What = evKeyDown) then
        begin
          Event.ControlKeyState := Event.ControlKeyState or kbLeftAlt;
          NormalizeKey(Event);
        end;
      end;
  end;
  Result := Res;
end;

{ --- the plain keys ----------------------------------------------------------------------------------------- }

{ A byte below 32: the key that it is (the control character, Backspace, Tab, Enter, Esc). }
procedure FromNonPrintable(B: Byte; var Event: TEvent);
begin
  ClearEvent(Event);
  Event.What := evKeyDown;
  case B of
    0: begin Event.KeyCode := Ord('@'); Event.ControlKeyState := kbLeftCtrl; Event.Text[0] := '@'; Event.TextLength := 1; end;
    1..7, 11, 12, 14..26: begin Event.KeyCode := B; Event.ControlKeyState := kbLeftCtrl; end;
    8: Event.KeyCode := kbBack;
    9: Event.KeyCode := kbTab;
    10, 13: Event.KeyCode := kbEnter;
    27: Event.KeyCode := kbEsc;
    28: begin Event.KeyCode := Ord('\'); Event.ControlKeyState := kbLeftCtrl; Event.Text[0] := '\'; Event.TextLength := 1; end;
    29: begin Event.KeyCode := Ord(']'); Event.ControlKeyState := kbLeftCtrl; Event.Text[0] := ']'; Event.TextLength := 1; end;
    30: begin Event.KeyCode := Ord('^'); Event.ControlKeyState := kbLeftCtrl; Event.Text[0] := '^'; Event.TextLength := 1; end;
    31: begin Event.KeyCode := Ord('_'); Event.ControlKeyState := kbLeftCtrl; Event.Text[0] := '_'; Event.TextLength := 1; end;
  end;
end;

function ParseEvent(var Input: TTermInput; var Event: TEvent; var State: TInputState): Boolean;
var
  Buf: TGetChBuf;
  K, I, N: Integer;
  Alt: Boolean;
  CodePoint: LongWord;
  Used: Integer;
begin
  ClearEvent(Event);
  Buf.Init(@Input);
  { the escape sequences }
  if Buf.Get = 27 then
    case ParseEscapeSeq(Buf, Event, State) of
      prAccepted: Exit(True);
      prIgnored: begin ClearEvent(Event); Exit(False); end;
    end;
  Buf.Reject;
  ClearEvent(Event);

  K := Input.Get;
  if K < 0 then
    Exit(False);
  Alt := False;
  if K = 27 then
  begin
    { ESC with a key that follows at once is Alt + the key (what is not a sequence of the terminal) }
    N := Input.GetNb;
    if N >= 0 then
    begin
      K := N;
      Alt := True;
    end;
  end;

  if K < 32 then
    FromNonPrintable(Byte(K), Event)
  else if K = 127 then
  begin
    Event.What := evKeyDown;
    Event.KeyCode := kbBack;
  end
  else
  begin
    { a printable character: UTF-8 text }
    Event.What := evKeyDown;
    Event.Text[0] := Char(K);
    N := 1 + Utf8BytesLeft(Byte(K));
    for I := 1 to N - 1 do
    begin
      Used := Input.Get;
      if Used < 0 then
      begin
        N := I;
        Break;
      end;
      Event.Text[I] := Char(Used);
    end;
    Event.TextLength := N;
    if Utf8Decode(PByte(@Event.Text[0]), N, CodePoint, Used) then
      Event.CharCode := PrintableFromCodepoint(CodePoint)
    else
      Event.CharCode := 0;
    { text must not trigger the shortcuts of Ctrl+letter }
    if Event.KeyCode <= kbCtrlZ then
      Event.KeyCode := kbNoKey;
  end;

  if Alt then
  begin
    Event.ControlKeyState := Event.ControlKeyState or kbLeftAlt;
    NormalizeKey(Event);
  end;
  if State.BracketedPaste then
    Event.ControlKeyState := Event.ControlKeyState or kbPaste;
  Result := (Event.KeyCode <> kbNoKey) or (Event.TextLength <> 0);
end;

end.
