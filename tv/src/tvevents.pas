{ TvEvents: the event record and the event constants.

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/system.h (event codes and masks, mouse button/wheel/flag
                              constants, MouseEventType, KeyDownEvent,
                              MessageEvent, TEvent)
  The event queue, mouse and screen classes of system.h are platform code and
  are replaced by the backends (tv/DESIGN.md). Borland disclaimer and MIT
  notice: tv/COPYRIGHT.magiblot.

  TEvent is one flat record (as in the Pascal Turbo Vision) instead of nested
  structs: What, ControlKeyState, then the part of the event kind:
    mouse    Where, EventFlags, Buttons, Wheel
    key down KeyCode (= CharCode + ScanCode shl 8), Text/TextLength (UTF-8)
    message  Command and Info* (several views of the same bytes)
  ControlKeyState is shared by mouse and keyboard events. }
unit TvEvents;

{$I tvdefs.inc}

interface

uses
  TvGeom, TvKeys, TvUtf8;

const
  { event codes }
  evMouseDown = $0001;
  evMouseUp   = $0002;
  evMouseMove = $0004;
  evMouseAuto = $0008;
  evMouseWheel = $0020;
  evKeyDown   = $0010;
  evCommand   = $0100;
  evBroadcast = $0200;

  { event masks }
  evNothing   = $0000;
  evMouse     = $002F;
  evKeyboard  = $0010;
  evMessage   = $FF00;

  { mouse button state masks }
  mbLeftButton   = $01;
  mbRightButton  = $02;
  mbMiddleButton = $04;

  { mouse wheel state masks }
  mwUp    = $01;
  mwDown  = $02;
  mwLeft  = $04;
  mwRight = $08;

  { mouse event flags }
  meMouseMoved  = $01;
  meDoubleClick = $02;
  meTripleClick = $04;

type
  TEvent = record
    What: Word;
    ControlKeyState: Word;
    case Integer of
      0: (Where: TPoint; EventFlags: Word; Buttons: Byte; Wheel: Byte);
      1: (Text: array[0..MaxCharSize - 1] of Char;    { UTF-8, not NUL-terminated }
          TextLength: Byte;
          case Integer of
            0: (KeyCode: Word);
            1: (CharCode, ScanCode: Byte));
      2: (Command: Word;
          case Integer of
            0: (InfoPtr: Pointer);
            1: (InfoLong: LongInt);
            2: (InfoWord: Word);
            3: (InfoInt: SmallInt);
            4: (InfoByte: Byte);
            5: (InfoChar: Char));
  end;

{ All zero: What = evNothing. }
procedure ClearEvent(out Event: TEvent);
{ The text of a key down event. }
function EventText(const Event: TEvent): ShortString;
{ The normalized key combination of a key down event. }
function EventKey(const Event: TEvent): TKey;
{ A key down event for a key code; the text is the character for printable ASCII. }
procedure MakeKeyEvent(out Event: TEvent; KeyCode, ControlKeyState: Word);

implementation

procedure ClearEvent(out Event: TEvent);
begin
  FillChar(Event, SizeOf(Event), 0);
end;

function EventText(const Event: TEvent): ShortString;
var
  N: Integer;
begin
  N := Event.TextLength;
  if N > MaxCharSize then
    N := MaxCharSize;
  SetLength(Result, N);
  if N > 0 then
    Move(Event.Text[0], Result[1], N);
end;

function EventKey(const Event: TEvent): TKey;
begin
  Result := KeyMake(Event.KeyCode, Event.ControlKeyState);
end;

procedure MakeKeyEvent(out Event: TEvent; KeyCode, ControlKeyState: Word);
begin
  ClearEvent(Event);
  Event.What := evKeyDown;
  Event.KeyCode := KeyCode;
  Event.ControlKeyState := ControlKeyState;
  if (Event.CharCode >= $20) and (Event.CharCode < $7F) then
  begin
    Event.Text[0] := Char(Event.CharCode);
    Event.TextLength := 1;
  end;
end;

end.
