{ Drivers: the helpers of DN that lie between its sources and the units of tv/ (it replaces
  drivers.pas of the archive, which was the event manager and the screen of DN, based on Borland TV).

  Events, the mouse and the screen are done by tv/ (TvSys, TvScreen): the routines of the old event manager
  are here only because DN calls them, and do nothing (marked TODO where DN's logic may be needed). What
  is real here: the string and cell routines of 16-bit cells (Move*, FormatStr), the keys (GetAltChar...).
  The names and the initial values are those of the sources of DN. }
{$mode objfpc}{$H-}
unit Drivers;

interface

uses
  SysUtils, TvGeom, TvEvents, TvScreen, TvUtil, TvViews, TvSys, TvCell, TvColors, TvDrawBuf, TvText, TvUtf8, TvCodePg, TvFormat;

type
  TEvent = TvEvents.TEvent;
  PEvent = ^TEvent;
  CharDef = array[0..15] of Byte;

var
  LSliceTimer: TEventTimer;
  LSliceCnt: LongInt;

{ Called by DN where the program may give time to others; nothing to do here. }
procedure SliceAwake;

const
  AltCodes1: array[$10..$34] of Char =
    'QWERTYUIOP'#0#0#0#0'ASDFGHJKL'#0#0#0#0#0'ZXCVBNM'#0#0;
  mbLeftButton = $01;
  mbRightButton = $02;
  { the state of the shift keys of the last event (the bits of the BIOS: right shift 1, left shift 2, ctrl 4,
    alt 8...), and the second byte (left/right ctrl and alt, DN); set by TProgram.GetEvent of mainapp }
  ShiftState: Byte = 0;
  ShiftState2: Byte = 0;
  OldShiftState: Byte = 0;
  DoubleAltUnlock: Boolean = True;
  DoubleCtrlUnlock: Boolean = True;
  ButtonCount: Byte = 0;
  MouseEvents: Boolean = False;
  MouseButtons: Byte = 0;
  RepeatDelay: Word = 8;
  AutoRepeat: Word = 1;
  UserScreen: Pointer = nil;
  CharHeight: Byte = 16;
  ScreenSaved: Boolean = False;
  NeedAbort: Boolean = False;
  StdMouse: Boolean = False;
  XSens: Byte = 11;
  YSens: Byte = 11;
  CLSAct: Boolean = True;
  CurrentBlink: Boolean = False;
  MouseWhere: TPoint = (X: 0; Y: 0);
  WheelEvent: Boolean = False;
  StartupMode: Word = $FFFF;
  SkyEnabled: Integer = 0;
  TottalExit: Boolean = False;
  Exiting: Boolean = False;
  MouseVisible: Boolean = True;
  ScreenMode: Word = $92;

var
  OldBlink: Boolean;
  MouseIntFlag: Byte;
  UserScreenSize: Word;
  UserScreenWidth: Word;
  MouseX, MouseY, OldMouseX, OldMouseY: Word;
  ShowMouseProc, HideMouseProc: Pointer;
  HiResScreen: Boolean;
  CheckSnow: Boolean;
  OldCursorShape: Word;
  OldCursorPos: Word;
  DownButtons: Byte;
  { the size of the screen: the low halves of the variables of TvScreen (little endian) }
  ScreenWidth: Word absolute TvScreen.TScreen.ScreenWidth;
  ScreenHeight: Word absolute TvScreen.TScreen.ScreenHeight;
  { TODO: DN reads and writes the screen as an array of 16-bit cells; the buffer of tv/ has other cells }
  { the screen of DN: 16-bit cells (character + attribute), a copy of the screen of tv/ that SysTvGetSrcBuf (osdep) makes and
    mainapp refreshes at every idle; DN reads it (user screen, screen savers) and writes back with SysTvShowBuf. NOT the buffer of
    TvScreen (that one has the cells of tv/) }
  ScreenBuffer: Pointer = nil;
  CursorLines: Word absolute TvScreen.TScreen.CursorLines;

{ The key code of an event in the form of DN: the low word is the code of Turbo Vision (scan code * 256 + character),
  bits 16..19 are the state of the shift keys (1 and 2: shift, 4: ctrl, 8: alt; the shifts together are 3), as in
  the constants kbLeft, kbShiftLeft, kbAltLeft... of DN. tv/ keeps the shift state in ControlKeyState. }
function DNKeyCode(const Event: TEvent): LongInt;
{ The reverse: the code in the form of DN goes into KeyCode and ControlKeyState of the event. }
procedure SetDNKeyCode(var Event: TEvent; Code: LongInt);

{ Sends a key press (the code in the form of DN, with the shift bits: kbCtrlPgDn = $047600) to a view, as a person would press it. Message(R, evKeyDown, Code, nil)
  of the Borland TV put the code into the field that is the key code there; in tv/ the fields Command and KeyCode of TEvent are not the same
  place and the old call did nothing. }
function MessageKey(Receiver: TView; Code: LongInt): Pointer;

{ A double click: a flag of the mouse event in tv/ (EventFlags bit 2); DN has the field Double. }
procedure SetEventDouble(var Event: TEvent; Value: Boolean);

var
  { where a fatal error happened (DN: the source file and the line of the error, set by the error handler) }
  SourceFileName: PShortString = nil;
  SourceLineNo: LongInt = 0;

{ The end of the program after a fatal error: the place of the error (ErrorAddr, SourceFileName, SourceLineNo) is
  written to the error output, the program stops with ExitCode. }
procedure EndFatalError;

procedure InitDrivers;
procedure DoneDrivers;
procedure InitEvents;
procedure DoneEvents;
procedure ShowMouse;
procedure HideMouse;
procedure UpdateMouseWhere;
procedure GetMouseEvent(var Event: TEvent);
procedure GetKeyEvent(var Event: TEvent);
procedure SetMouseSpeed(XS, YS: Byte);

type
  TSysErrorFunc = function(ErrorCode: Integer; Drive: Byte): Integer;

{ The red dialog of a system error: 3 (Abort), no dialog yet. TODO }
function SystemError(ErrorCode: Integer; Drive: Byte): Integer;

const
  SysErrorFunc: TSysErrorFunc = @SystemError;
  SysColorAttr: Word = $4E4F;
  SysColorButtonAttr: Word = $0E0F;
  SysMonoAttr: Word = $7070;
  CtrlBreakHit: Boolean = False;
  SaveCtrlBreak: Boolean = False;
  SysErrActive: Boolean = False;
  SysErrStopButton: Boolean = False;

procedure InitSysError;
procedure DoneSysError;

function GetAltChar(KeyCode: LongInt): Char;
{ UTF-8 inside: Alt and a character that is not Latin (a letter of the code page, KeyCode = $0000xx with the Alt bit in the high word) gives that character }
function GetAltCode(Ch: Char): Word;
function GetCtrlChar(KeyCode: Word): Char;
function GetCtrlCode(Ch: Char): Word;

{ Result := Format with its % items filled from Params, an array of pointer-sized slots (converted for TvFormat.FormatStr). }
procedure FormatStr(var Result: String; const Format: String; var Params);
procedure PrintStr(const S: String);

{ Cells of 16 bits: the low byte is the character, the high byte is the attribute (0 = leave as it is). }
procedure MoveColor(var Buf; Num: Word; Attr: Byte); overload;
procedure MoveBuf(var Dest; var Source; Attr: Byte; Count: Word); overload;
procedure MoveChar(var Dest; C: Char; Attr: Byte; Count: LongInt); overload;
procedure MoveCStr(var Dest; const Str: String; Attrs: Word); overload;
procedure MoveStr(var Dest; const Str: String; Attr: Byte); overload;
{ The same for the cells of tv/ (TScreenCell: TDrawBuffer of DN is an array of them, or an element of it: the cells from there on, or any array
  of TScreenCell). The text is put by the text functions of tv/ (TvText): code page bytes while TvUtf8.Utf8Enabled is False, else UTF-8. }
procedure MoveColor(var Buf: TScreenCell; Num: Word; Attr: Byte); overload;
procedure MoveBuf(var Dest: TScreenCell; var Source; Attr: Byte; Count: Word); overload;
procedure MoveChar(var Dest: TScreenCell; C: Char; Attr: Byte; Count: LongInt); overload;
procedure MoveCStr(var Dest: TScreenCell; const Str: String; Attrs: Word); overload;
procedure MoveStr(var Dest: TScreenCell; const Str: String; Attr: Byte); overload;
procedure MoveColor(var Buf: array of TScreenCell; Num: Word; Attr: Byte); overload;
procedure MoveBuf(var Dest: array of TScreenCell; var Source; Attr: Byte; Count: Word); overload;
procedure MoveChar(var Dest: array of TScreenCell; C: Char; Attr: Byte; Count: LongInt); overload;
{ Count cells from Dest on with the glyph (a Unicode code point, TvGlyphs: gl*) and the BIOS attribute Attr; the cell holds its UTF-8. }
procedure MoveGlyph(var Dest: TScreenCell; CodePoint: LongWord; Attr: Byte; Count: LongInt); overload;
procedure MoveGlyph(var Dest: array of TScreenCell; CodePoint: LongWord; Attr: Byte; Count: LongInt); overload;
procedure MoveCStr(var Dest: array of TScreenCell; const Str: String; Attrs: Word); overload;
procedure MoveStr(var Dest: array of TScreenCell; const Str: String; Attr: Byte); overload;

type
  TCellArray = array[0..65534] of TScreenCell;
  PCellArray = ^TCellArray;

{ The parts of a cell, with the BIOS attribute and the byte of the code page as DN has them. }
procedure SetCellChar(var Cell: TScreenCell; Ch: Byte);
procedure SetCellAttr(var Cell: TScreenCell; Attr: Byte);
function CellChar(const Cell: TScreenCell): Byte;
function CellAttr(const Cell: TScreenCell): Byte;
{ Count cells from words of the DOS text mode (the character in the low byte, the BIOS attribute in the high byte), as the video memory has them. }
procedure WordsToCells(var Dest: TScreenCell; const Source; Count: Integer);
function CStrLen(const S: String): Integer;

{ The text cursor: the size in lines (0 = hidden), show, hide; the size of the screen in characters (True when it is as asked: it is not changed here). }
function GetCursorSize: Word;
procedure ShowCursor;
procedure HideCursor;
function SetVideoMode(Cols, Rows: Word): Boolean;

implementation

function GetCursorSize: Word;
begin
  Result := THardwareInfo.GetCaretSize;
end;

procedure ShowCursor;
begin
  THardwareInfo.SetCaretSize(CursorLines);
end;

procedure HideCursor;
begin
  THardwareInfo.SetCaretSize(0);
end;

function SetVideoMode(Cols, Rows: Word): Boolean;
begin
  Result := (ScreenWidth = Cols) and (ScreenHeight = Rows);
end;


type
  PWordArr = ^TWordArr;
  TWordArr = array[0..65534] of Word;
  PLongArr = ^TLongArr;
  TLongArr = array[0..255] of LongInt;

procedure SliceAwake;
begin
end;

const
  { the scan codes of the keys A..Z (DOS): DN has Ctrl-letter as scan code and the control character (kbCtrlS = $041F13), tv/ as the character only }
  CtrlScan: array[1..26] of Byte = (
    $1E, $30, $2E, $20, $12, $21, $22, $23, $17, $24, $25, $26, $32,
    $31, $18, $19, $10, $13, $1F, $14, $16, $2F, $11, $2D, $15, $2C);

type
  TPunctKey = record
    Plain, Shifted: Char;
    Scan: Byte;
  end;

const
  { the keys of punctuation of the US layout and their scan codes }
  PunctScan: array[0..8] of TPunctKey = (
    (Plain: '['; Shifted: '{'; Scan: $1A), (Plain: ']'; Shifted: '}'; Scan: $1B), (Plain: ';'; Shifted: ':'; Scan: $27),
    (Plain: ''''; Shifted: '"'; Scan: $28), (Plain: '`'; Shifted: '~'; Scan: $29), (Plain: '\'; Shifted: '|'; Scan: $2B),
    (Plain: ','; Shifted: '<'; Scan: $33), (Plain: '.'; Shifted: '>'; Scan: $34), (Plain: '/'; Shifted: '?'; Scan: $35));

function DNKeyCode(const Event: TEvent): LongInt;
var
  Shift: LongInt;
  Key: LongInt;
  I: Integer;
begin
  Shift := 0;
  if (Event.KeyDown.ControlKeyState and 3) <> 0 then
    Shift := 3;
  Shift := Shift or (Event.KeyDown.ControlKeyState and 12);
  Key := Event.KeyDown.KeyCode;
  { tv/ has its own codes for these four (magiblot: kbCtrlIns $0400, kbShiftIns $0500, kbCtrlDel $0600, kbShiftDel $0700); DN knows the scan codes of the BIOS:
    without this Ctrl+Ins (copy), Shift+Ins (paste), Ctrl+Del and Shift+Del were not the keys DN looks for (the menu hotkeys, the editor) }
  case Key of
    $0400: Key := $9200;
    $0500: Key := $5200;
    $0600: Key := $9300;
    $0700: Key := $5300;
  end;
  if  ((Event.KeyDown.ControlKeyState and 4) <> 0) and ((Event.KeyDown.ControlKeyState and 8) = 0) and (Key >= 1) and (Key <= 26)
      and not (Key in [8, 9, 13]) then
    Key := Key or (LongInt(CtrlScan[Key]) shl 8);
  { Alt and a key of punctuation: tv/ gives the character (a terminal sends ESC and the character), DN looks for the scan code of the key
    (kbAltQuote = $082800); the character of the key with Shift adds Shift }
  if ((Event.KeyDown.ControlKeyState and 8) <> 0) and (Key > $20) and (Key < $7F) then
    for I := Low(PunctScan) to High(PunctScan) do
      if Chr(Key) = PunctScan[I].Plain then
      begin
        Key := LongInt(PunctScan[I].Scan) shl 8;
        Break;
      end
      else if Chr(Key) = PunctScan[I].Shifted then
      begin
        Key := LongInt(PunctScan[I].Scan) shl 8;
        Shift := Shift or 3;
        Break;
      end;
  Result := Key or (Shift shl 16);
end;

procedure SetEventDouble(var Event: TEvent; Value: Boolean);
begin
  if Value then
    Event.Mouse.EventFlags := Event.Mouse.EventFlags or 2
  else
    Event.Mouse.EventFlags := Event.Mouse.EventFlags and not Word(2);
end;

procedure SetDNKeyCode(var Event: TEvent; Code: LongInt);
begin
  Event.KeyDown.KeyCode := Word(Code);
  Event.KeyDown.ControlKeyState := (Event.KeyDown.ControlKeyState and not Word($F)) or Word((Code shr 16) and $F);
end;

function MessageKey(Receiver: TView; Code: LongInt): Pointer;
var
  Event: TEvent;
begin
  Result := nil;
  if Receiver = nil then
    Exit;
  ClearEvent(Event);
  Event.What := evKeyDown;
  SetDNKeyCode(Event, Code);
  Receiver.HandleEvent(Event);
  if Event.What = evNothing then
    Result := Event.Message.InfoPtr;
end;

procedure InitDrivers;
begin
end;

procedure EndFatalError;
begin
  Write(StdErr, 'Fatal error ', ExitCode);
  if (SourceFileName <> nil) and (SourceLineNo <> 0) then
    Write(StdErr, ' in ', SourceFileName^, ' line ', SourceLineNo);
  Writeln(StdErr);
  Halt(ExitCode);
end;

procedure DoneDrivers;
begin
end;

procedure InitEvents;
begin
end;

procedure DoneEvents;
begin
end;

procedure ShowMouse;
begin
end;

procedure HideMouse;
begin
end;

procedure UpdateMouseWhere;
begin
end;

procedure GetMouseEvent(var Event: TEvent);
begin
  Event.What := evNothing;
end;

{ The next key event of the system without waiting (DN: the loops that can be stopped by Esc ask for it); the other events that come
  before it (the mouse) are dropped. }
procedure GetKeyEvent(var Event: TEvent);
begin
  TEventQueue.GetKeyEvent(Event);
end;

procedure SetMouseSpeed(XS, YS: Byte);
begin
  XSens := XS;
  YSens := YS;
end;

function SystemError(ErrorCode: Integer; Drive: Byte): Integer;
begin
  Result := 3;
end;

procedure InitSysError;
begin
end;

procedure DoneSysError;
begin
end;

{ --- keys --------------------------------------------------------------------- }

function GetAltChar(KeyCode: LongInt): Char;
begin
  Result := TvUtil.GetAltChar(Word(KeyCode));
  if Utf8Enabled and (Result = #0) and ((KeyCode shr 16) and 8 <> 0) and (KeyCode and $FF00 = 0) and (KeyCode and $FF >= $80) then
    Result := Char(KeyCode and $FF);
end;

function GetAltCode(Ch: Char): Word;
begin
  Result := TvUtil.GetAltCode(Ch);
end;

function GetCtrlChar(KeyCode: Word): Char;
begin
  Result := TvUtil.GetCtrlChar(KeyCode);
end;

function GetCtrlCode(Ch: Char): Word;
begin
  Result := TvUtil.GetCtrlCode(Ch);
end;

{ --- strings ------------------------------------------------------------------ }

{ The slots become an array of const for TvFormat.FormatStr: each % item of Format is written again as an item of
  SysUtils.Format with its argument. What Format cannot write the same way is passed as text: %c as a string, %x and %X
  as the digits (Format has no lower case hex and fills hex with at most 31 zeros), an unknown item as itself. }
procedure FormatStr(var Result: String; const Format: String; var Params);
type
  TSlots = array[0..(MaxInt div SizeOf(PtrInt)) - 1] of PtrInt;
var
  Slots: ^TSlots;
  Next, I, Start, Width, N: Integer;
  Left, Zero: Boolean;
  Conv: Char;
  Fmt: AnsiString;
  Args: array of TVarRec;
  Texts: array of ShortString;
  Nums: array of Int64;
  V: LongInt;
  P: PShortString;
  Hex: AnsiString;

  function Take: PtrInt;
  begin
    Result := Slots^[Next];
    Inc(Next);
  end;

  function Literal(const S: AnsiString): AnsiString;
  begin
    Result := StringReplace(S, '%', '%%', [rfReplaceAll]);
  end;

  procedure AddText(const S: ShortString);
  begin
    Texts[N] := S;
    Args[N].VType := vtString;
    Args[N].VString := @Texts[N];
    Inc(N);
  end;

  procedure AddNum(X: Int64);
  begin
    Nums[N] := X;
    Args[N].VType := vtInt64;
    Args[N].VInt64 := @Nums[N];
    Inc(N);
  end;

  { the item %[-][width]Spec; Format fills at most 255 characters, the rest of a wider item is a literal text of spaces }
  procedure Item(const Spec: ShortString);
  var
    W: Integer;
  begin
    W := Width;
    if W > 255 then
      W := 255;
    if not Left then
      Fmt := Fmt + StringOfChar(' ', Width - W);
    Fmt := Fmt + '%';
    if Left then
      Fmt := Fmt + '-';
    if W > 0 then
      Fmt := Fmt + IntToStr(W);
    Fmt := Fmt + Spec;
    if Left then
      Fmt := Fmt + StringOfChar(' ', Width - W);
  end;

begin
  Slots := @Params;
  Next := 0;
  N := 0;
  SetLength(Args, Length(Format));
  SetLength(Texts, Length(Format));
  SetLength(Nums, Length(Format));
  Fmt := '';
  I := 1;
  while I <= Length(Format) do
  begin
    if Format[I] <> '%' then
    begin
      Fmt := Fmt + Format[I];
      Inc(I);
      Continue;
    end;
    Start := I;
    Inc(I);
    Left := (I <= Length(Format)) and (Format[I] = '-');
    if Left then
      Inc(I);
    Zero := (I <= Length(Format)) and (Format[I] = '0');
    if Zero then
      Inc(I);
    Zero := Zero and not Left;
    Width := 0;
    while (I <= Length(Format)) and (Format[I] in ['0'..'9']) do
    begin
      if Width < 1000 then
        Width := Width * 10 + Ord(Format[I]) - Ord('0');
      Inc(I);
    end;
    if I > Length(Format) then
    begin
      Fmt := Fmt + Literal(Copy(Format, Start, MaxInt));
      Break;
    end;
    Conv := Format[I];
    Inc(I);
    case Conv of
      '%':
        Fmt := Fmt + '%%';
      's':
        begin
          P := PShortString(Pointer(Take));
          if P = nil then
            AddText('')
          else
            AddText(P^);
          Item('s');
        end;
      'c':
        begin
          AddText(Chr(Byte(Take)));
          Item('s');
        end;
      'd', 'u':
        begin
          if Conv = 'd' then
          begin
            V := LongInt(Take);
            AddNum(V);
          end
          else
          begin
            V := 0;
            AddNum(LongWord(Take));
          end;
          if Zero and (Width > 0) then
          begin
            if V < 0 then
              Fmt := Fmt + '%.' + IntToStr(Width - 1) + 'd'
            else
              Fmt := Fmt + '%.' + IntToStr(Width) + 'd';
          end
          else
            Item('d');
        end;
      'x', 'X':
        begin
          Hex := IntToHex(LongWord(Take), 1);
          if Conv = 'x' then
            Hex := LowerCase(Hex);
          if Zero and (Length(Hex) < Width) then
            Hex := StringOfChar('0', Width - Length(Hex)) + Hex;
          AddText(Hex);
          if Zero then
            Fmt := Fmt + '%s'
          else
            Item('s');
        end;
    else
      Fmt := Fmt + Literal(Copy(Format, Start, I - Start));
    end;
  end;
  SetLength(Args, N);
  Result := TvFormat.FormatStr(Fmt, Args);
end;

procedure PrintStr(const S: String);
begin
  Write(S);
end;

{ --- cells -------------------------------------------------------------------- }

procedure MoveColor(var Buf; Num: Word; Attr: Byte);
var
  I: Integer;
begin
  for I := 0 to Num - 1 do
    PWordArr(@Buf)^[I] := (PWordArr(@Buf)^[I] and $FF) or (Word(Attr) shl 8);
end;

procedure MoveBuf(var Dest; var Source; Attr: Byte; Count: Word);
var
  I: Integer;
begin
  if Attr = 0 then
    Move(Source, Dest, Count * 2)
  else
    for I := 0 to Count - 1 do
      PWordArr(@Dest)^[I] := PByte(@Source)[I] or (Word(Attr) shl 8);
end;

{ The 16-bit buffers (a character of the code page and an attribute) hold one byte per cell. With UTF-8 inside DN a text that is put into
  such a buffer is turned into the bytes of the current code page: the characters that the page has; whatever the page does not have
  (and the bytes that are not UTF-8: the frame characters of DN are bytes of the page) stay as they are. }
function LegacyText(const S: String): String;
var
  I, L: Integer;
  Cp: LongWord;
  Used: Integer;
  B: Byte;
begin
  if not Utf8Enabled then
    Exit(S);
  Result := '';
  I := 1;
  while I <= Length(S) do
  begin
    if (Byte(S[I]) >= $C0) and Utf8Decode(@S[I], Length(S) - I + 1, Cp, Used) and (Used > 1) then
    begin
      B := CpFromUnicode(Cp);
      if B <> 0 then
      begin
        Result := Result + Chr(B);
        Inc(I, Used);
        Continue;
      end;
    end;
    Result := Result + S[I];
    Inc(I);
  end;
end;

procedure MoveChar(var Dest; C: Char; Attr: Byte; Count: LongInt);
var
  I: Integer;
  W: PWordArr;
begin
  W := @Dest;
  for I := 0 to Count - 1 do
    if C = #0 then
      W^[I] := (W^[I] and $FF) or (Word(Attr) shl 8)
    else if Attr = 0 then
      W^[I] := (W^[I] and $FF00) or Ord(C)
    else
      W^[I] := Ord(C) or (Word(Attr) shl 8);
end;

procedure MoveStr(var Dest; const Str: String; Attr: Byte);
var
  I: Integer;
  W: PWordArr;
  S: String;
begin
  W := @Dest;
  S := LegacyText(Str);
  for I := 1 to Length(S) do
    if Attr = 0 then
      W^[I - 1] := (W^[I - 1] and $FF00) or Ord(S[I])
    else
      W^[I - 1] := Ord(S[I]) or (Word(Attr) shl 8);
end;

procedure MoveCStr(var Dest; const Str: String; Attrs: Word);
var
  I, J: Integer;
  W: PWordArr;
  Hi: Boolean;
  A: Byte;
  S: String;
begin
  W := @Dest;
  S := LegacyText(Str);
  J := 0;
  Hi := False;
  for I := 1 to Length(S) do
    if S[I] = '~' then
      Hi := not Hi
    else
    begin
      if Hi then A := Attrs shr 8 else A := Attrs and $FF;
      W^[J] := Ord(S[I]) or (Word(A) shl 8);
      Inc(J);
    end;
end;

{ --- cells of tv/ ---------------------------------------------------------------- }

procedure MoveColor(var Buf: TScreenCell; Num: Word; Attr: Byte);
var
  I: Integer;
  P: PScreenCell;
begin
  P := @Buf;
  for I := 0 to Num - 1 do
  begin
    P^.Attribute := TColorAttr(LongInt(Attr));
    Inc(P);
  end;
end;

procedure MoveBuf(var Dest: TScreenCell; var Source; Attr: Byte; Count: Word);
var
  S: String;
begin
  if Count = 0 then
    Exit;
  SetLength(S, Count);
  Move(Source, S[1], Count);
  MoveStr(Dest, S, Attr);
end;

procedure MoveChar(var Dest: TScreenCell; C: Char; Attr: Byte; Count: LongInt);
var
  I: Integer;
  P: PScreenCell;
begin
  P := @Dest;
  for I := 0 to Count - 1 do
  begin
    if C <> #0 then
      P^.Character.InitWithChar(Ord(C));
    if Attr <> 0 then
      P^.Attribute := TColorAttr(LongInt(Attr));
    Inc(P);
  end;
end;

procedure MoveStr(var Dest: TScreenCell; const Str: String; Attr: Byte);
var
  B: TvDrawBuf.TDrawBuffer;
  N: Integer;
begin
  B := TvDrawBuf.TDrawBuffer.Create(Length(Str));
  N := B.MoveStrS(0, Str, TColorAttr(LongInt(Attr)), Length(Str));
  if N > 0 then
    Move(B.Data^, Dest, N * SizeOf(TScreenCell));
  B.Free;
end;

procedure MoveCStr(var Dest: TScreenCell; const Str: String; Attrs: Word);
var
  B: TvDrawBuf.TDrawBuffer;
  P: TAttrPair;
  N: Integer;
begin
  B := TvDrawBuf.TDrawBuffer.Create(Length(Str));
  P[0] := TColorAttr(LongInt(Attrs and $FF));
  P[1] := TColorAttr(LongInt(Attrs shr 8));
  N := B.MoveCStrS(0, Str, P, Length(Str));
  if N > 0 then
    Move(B.Data^, Dest, N * SizeOf(TScreenCell));
  B.Free;
end;

procedure MoveColor(var Buf: array of TScreenCell; Num: Word; Attr: Byte);
begin
  MoveColor(Buf[0], Num, Attr);
end;

procedure MoveBuf(var Dest: array of TScreenCell; var Source; Attr: Byte; Count: Word);
begin
  MoveBuf(Dest[0], Source, Attr, Count);
end;

procedure MoveChar(var Dest: array of TScreenCell; C: Char; Attr: Byte; Count: LongInt);
begin
  MoveChar(Dest[0], C, Attr, Count);
end;

procedure MoveGlyph(var Dest: TScreenCell; CodePoint: LongWord; Attr: Byte; Count: LongInt);
var
  I: Integer;
  P: PScreenCell;
  A: TColorAttr;
  Buf: array[0..7] of Byte;
begin
  P := @Dest;
  A := TColorAttr(LongInt(Attr));
  for I := 0 to Count - 1 do
  begin
    P^.Character.InitWithMultiByteChar(@Buf[0], Utf8Encode(CodePoint, @Buf[0]), False);
    P^.Attribute := A;
    Inc(P);
  end;
end;

procedure MoveGlyph(var Dest: array of TScreenCell; CodePoint: LongWord; Attr: Byte; Count: LongInt);
begin
  MoveGlyph(Dest[0], CodePoint, Attr, Count);
end;

procedure MoveStr(var Dest: array of TScreenCell; const Str: String; Attr: Byte);
begin
  MoveStr(Dest[0], Str, Attr);
end;

procedure MoveCStr(var Dest: array of TScreenCell; const Str: String; Attrs: Word);
begin
  MoveCStr(Dest[0], Str, Attrs);
end;

procedure SetCellChar(var Cell: TScreenCell; Ch: Byte);
begin
  Cell.Character.InitWithChar(Ch);
end;

procedure SetCellAttr(var Cell: TScreenCell; Attr: Byte);
begin
  Cell.Attribute := TColorAttr(LongInt(Attr));
end;

function CellChar(const Cell: TScreenCell): Byte;
var
  S: ShortString;
  CP: LongWord;
  Used: Integer;
begin
  { the cell holds UTF-8 (TScreenCharacter.InitWithChar turns a byte of the code page into its character): DN asks for the byte of the page (a line character, a letter) }
  Result := Ord(Cell.Character.GetText[1]);
  if Length(Cell.Character.GetText) > 1 then
  begin
    S := Cell.Character.GetText;
    Result := Ord('?');
    if Utf8Decode(@S[1], Length(S), CP, Used) and (CpFromUnicode(CP) <> 0) then
      Result := CpFromUnicode(CP);
  end;
end;

function CellAttr(const Cell: TScreenCell): Byte;
begin
  Result := Byte(Cell.Attribute);
end;

procedure WordsToCells(var Dest: TScreenCell; const Source; Count: Integer);
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    PScreenCell(@Dest)[I] := TScreenCell(Word(PWord(@Source)[I]));
end;

function CStrLen(const S: String): Integer;
begin
  Result := TvUtil.CStrLen(S);
end;

end.
