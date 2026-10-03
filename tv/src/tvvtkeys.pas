{ TvVtKeys: what a terminal program must receive for a key or a mouse event (the input side of the terminal view, PLAN.md item 8.3): the bytes of a key
  (UTF-8 text, control characters, the sequences of the cursor keys and of the function keys with the modifiers of xterm) and the report of a mouse event
  (X10, UTF-8, SGR and urxvt encodings). The state of the modes comes from TvVt (application cursor keys, the mouse mode).

  Written for this port (the original has the same in termctrl.cc and in libvterm); the sequences are the ones that xterm sends (XTerm Control Sequences). }
unit TvVtKeys;

{$I tvdefs.inc}

interface

uses
  TvEvents;

{ the bytes for a key event; '' when the key has none (a modifier alone, a key that no terminal sends) }
function VtKeyBytes(const Event: TEvent; AppCursor: Boolean): AnsiString;

{ the report of a mouse event at the cell (X, Y) of the terminal (0-based) for the mouse mode (9, 1000, 1002, 1003) and the encoding (0, 1005, 1006, 1015).
  Press: Down = True, Button 0..2 (left, middle, right); release: Down = False; wheel: Wheel 1 (up) or 2 (down); a move: Moved = True.
  '' when the mode does not want the event. }
function VtMouseBytes(Mode, Enc, X, Y, Button: Integer; Down, Moved: Boolean; Wheel: Integer; Mods: Word): AnsiString;

{ the text that goes into the terminal as a paste; with the bracketed paste mode it is in ESC [ 200 ~ ... ESC [ 201 ~ }
function VtPasteBytes(const Text: AnsiString; Bracketed: Boolean): AnsiString;

implementation

uses
  TvKeys, TvUtf8;

function IntStr(V: LongInt): AnsiString;
var
  S: string[16];
begin
  Str(V, S);
  Result := S;
end;

{ the modifier value of xterm: 1 + shift 1 + alt 2 + ctrl 4 }
function ModValue(Mods: Word): Integer;
begin
  Result := 1;
  if (Mods and kbShift) <> 0 then Inc(Result, 1);
  if (Mods and kbAltShift) <> 0 then Inc(Result, 2);
  if (Mods and kbCtrlShift) <> 0 then Inc(Result, 4);
end;

function CsiKey(const Final: AnsiString; Mods: Word; Num: Integer): AnsiString;
var
  M: Integer;
begin
  M := ModValue(Mods);
  if Num = 0 then
  begin
    if M = 1 then
      Result := #27'[' + Final
    else
      Result := #27'[1;' + IntStr(M) + Final;
  end
  else
  begin
    if M = 1 then
      Result := #27'[' + IntStr(Num) + '~'
    else
      Result := #27'[' + IntStr(Num) + ';' + IntStr(M) + '~';
  end;
end;

function VtKeyBytes(const Event: TEvent; AppCursor: Boolean): AnsiString;
var
  Mods: Word;
  K: Word;
  C: Byte;
  Text: AnsiString;
  I: Integer;
begin
  Result := '';
  Mods := Event.ControlKeyState;
  K := Event.KeyCode;
  case K of
    kbUp, kbDown, kbRight, kbLeft, kbHome, kbEnd:
      begin
        case K of
          kbUp: Text := 'A';
          kbDown: Text := 'B';
          kbRight: Text := 'C';
          kbLeft: Text := 'D';
          kbHome: Text := 'H';
        else
          Text := 'F';
        end;
        if AppCursor and (ModValue(Mods) = 1) then
          Result := #27'O' + Text
        else
          Result := CsiKey(Text, Mods, 0);
        Exit;
      end;
    kbPgUp: Exit(CsiKey('', Mods, 5));
    kbPgDn: Exit(CsiKey('', Mods, 6));
    kbIns: Exit(CsiKey('', Mods, 2));
    kbDel: Exit(CsiKey('', Mods, 3));
    kbF1, kbF2, kbF3, kbF4:
      begin
        Text := Chr(Ord('P') + (K - kbF1) div $100);
        if ModValue(Mods) = 1 then
          Exit(#27'O' + Text);
        Exit(CsiKey(Text, Mods, 0));
      end;
    kbF5: Exit(CsiKey('', Mods, 15));
    kbF5 + $100: Exit(CsiKey('', Mods, 17));
    kbF5 + $200: Exit(CsiKey('', Mods, 18));
    kbF5 + $300: Exit(CsiKey('', Mods, 19));
    kbF5 + $400: Exit(CsiKey('', Mods, 20));
    kbF5 + $500: Exit(CsiKey('', Mods, 21));   { F10 }
    kbF11: Exit(CsiKey('', Mods, 23));
    kbF12: Exit(CsiKey('', Mods, 24));
    kbEnter: Result := #13;
    kbEsc: Result := #27;
    kbBack: Result := #127;
    kbCtrlBack: Result := #8;
    kbTab: Result := #9;
    kbShiftTab: Exit(#27'[Z');
  end;
  if Result = '' then
  begin
    if Event.TextLength > 0 then
    begin
      SetLength(Text, Event.TextLength);
      Move(Event.Text[0], Text[1], Event.TextLength);
      { Ctrl and a letter or one of @ [ \ ] ^ _ ?: the control character }
      if ((Mods and kbCtrlShift) <> 0) and (Length(Text) = 1) then
      begin
        C := Ord(Text[1]);
        if (C >= Ord('a')) and (C <= Ord('z')) then
          C := C - 32;
        if (C >= Ord('@')) and (C <= Ord('_')) then
          Text := Chr(C - 64)
        else if C = Ord(' ') then
          Text := #0
        else if C = Ord('?') then
          Text := #127;
      end;
      Result := Text;
    end
    else if (K >= 1) and (K <= $FF) then
      Result := Chr(K)                        { Ctrl and a letter: the control character itself }
    else
      Exit('');
  end;
  if ((Mods and kbAltShift) <> 0) and (Result <> '') then
    Result := #27 + Result;
  I := 0;
end;

function VtMouseBytes(Mode, Enc, X, Y, Button: Integer; Down, Moved: Boolean; Wheel: Integer; Mods: Word): AnsiString;
var
  B: Integer;
  Buf: array[0..4] of Byte;
  N: Integer;
begin
  Result := '';
  if Mode = 0 then
    Exit;
  if Wheel <> 0 then
    B := 64 + (Wheel - 1)
  else if Moved then
  begin
    if Mode < 1003 then
      if (Mode < 1002) or (Button < 0) then
        Exit;                                  { 1000 does not report moves; 1002 only with a button down }
    if Button < 0 then
      B := 3 + 32
    else
      B := Button + 32;
  end
  else if Down then
    B := Button
  else
  begin
    if Mode = 9 then
      Exit;                                    { X10: the presses only }
    if Enc = 1006 then
      B := Button
    else
      B := 3;                                  { the old encodings do not say which button is released }
  end;
  if Mode <> 9 then
  begin
    if (Mods and kbShift) <> 0 then Inc(B, 4);
    if (Mods and kbAltShift) <> 0 then Inc(B, 8);
    if (Mods and kbCtrlShift) <> 0 then Inc(B, 16);
  end;
  case Enc of
    1006:
      begin
        Result := #27'[<' + IntStr(B) + ';' + IntStr(X + 1) + ';' + IntStr(Y + 1);
        if Down or (Wheel <> 0) or Moved then
          Result := Result + 'M'
        else
          Result := Result + 'm';
      end;
    1015:
      Result := #27'[' + IntStr(B + 32) + ';' + IntStr(X + 1) + ';' + IntStr(Y + 1) + 'M';
    1005:
      begin
        Result := #27'[M' + Chr(B + 32);
        N := Utf8Encode(X + 33, @Buf[0]);
        SetLength(Result, Length(Result) + N);
        Move(Buf[0], Result[Length(Result) - N + 1], N);
        N := Utf8Encode(Y + 33, @Buf[0]);
        SetLength(Result, Length(Result) + N);
        Move(Buf[0], Result[Length(Result) - N + 1], N);
      end;
  else
    if (X > 222) or (Y > 222) then
      Exit('');                                { the old encoding cannot say it }
    Result := #27'[M' + Chr(B + 32) + Chr(X + 33) + Chr(Y + 33);
  end;
end;

function VtPasteBytes(const Text: AnsiString; Bracketed: Boolean): AnsiString;
begin
  if Bracketed then
    Result := #27'[200~' + Text + #27'[201~'
  else
    Result := Text;
end;

end.
