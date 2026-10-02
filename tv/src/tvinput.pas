{ TvInput: the input line (TInputLine) and the input box.

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/dialogs.h (TInputLine), source/tvision/tinputli.cpp,
    msgbox.cpp (inputBox, inputBoxRect), tvtext1.cpp (the arrows)
  Borland disclaimer and MIT notice: tv/COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/DESIGN.md):
    - the text is a ShortString (Data: PStr, MaxLen characters in the Pascal sense: the
      longest text, 1..255); only the limit in bytes exists, not the limits in columns or
      characters (ilMaxWidth, ilMaxChars);
    - InputLineOem: when set, the text typed or pasted (UTF-8) is converted to one byte
      of the current code page, so programs whose strings are OEM bytes (DOS) keep their
      data format; the clipboard is converted back;
    - paste is synchronous (TvClip): the first line of the clipboard is inserted;
    - streams are not translated yet. }
unit TvInput;

{$I tvdefs.inc}

interface

uses
  SysUtils, TvGeom, TvColors, TvKeys, TvEvents, TvText, TvUtf8, TvCodePg, TvDrawBuf,
  TvObjs, TvUtil, TvClip, TvViews, TvDialog, TvMsgBox, TvApp, TvValid;

type
  PInputLine = ^TInputLine;
  { Palette: 1 = passive, 2 = active, 3 = selected, 4 = arrows }
  TInputLine = object(TView)
    Data: PStr;
    MaxLen: Integer;
    CurPos: Integer;
    FirstPos: Integer;
    SelStart: Integer;
    SelEnd: Integer;
    Validator: PValidator;
    { used by DN: the characters at the edges when the text does not scroll (default: spaces) and own colors of the
      four palette entries (BIOS attributes in the low bytes; 0 = the palette of the dialog) }
    LC, RC: Char;
    C: array[1..4] of Word;
    constructor Init(const Bounds: TRect; AMaxLen: Integer);
    constructor Load(var S: TStream);
    procedure Store(var S: TStream);
    destructor Done; virtual;
    function DataSize: Integer; virtual;
    procedure Draw; virtual;
    procedure GetData(var Rec); virtual;
    function GetPalette: TPalette; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure SelectAll(Enable: Boolean; Scroll: Boolean = True);
    procedure SetData(var Rec); virtual;
    procedure SetState(AState: Word; Enable: Boolean); virtual;
    function Valid(Command: Word): Boolean; virtual;
    procedure SetValidator(AValid: PValidator);
  private
    Anchor: Integer;
    OldData: PStr;
    OldCurPos, OldFirstPos, OldSelStart, OldSelEnd: Integer;
    function CanScroll(Delta: Integer): Boolean;
    function MouseDelta(var Event: TEvent): Integer;
    function MousePos(var Event: TEvent): Integer;
    function DisplayedPos(Pos: Integer): Integer;
    procedure DeleteSelect;
    procedure DeleteCurrent;
    procedure AdjustSelectBlock;
    procedure SaveState;
    procedure RestoreState;
    function CheckValid(NoAutoFill: Boolean): Boolean;
    function CanUpdateCommands: Boolean;
    procedure SetCmdState(Command: Word; Enable: Boolean);
    procedure UpdateCommands;
    procedure TypeText(KeyText: ShortString);
  end;

var
  { see the note at the top of the unit }
  InputLineOem: Boolean = False;

{ A dialog with a label and an input line; S is the text (changed unless Cancel). }
function InputBox(const Title, ALabel: ShortString; var S: ShortString; Limit: Byte): Word;
function InputBoxRect(const Bounds: TRect; const Title, ALabel: ShortString;
  var S: ShortString; Limit: Byte): Word;

var
  { stream records (see RView of TvViews) }
  RInputLine: TStreamRec;

implementation

const
  ControlY = 25;
  RightArrow = $10;
  LeftArrow = $11;
  InputLinePalette = #$13#$13#$14#$15;
  PadKeys: array[0..5] of Byte = ($47, $4B, $4D, $4F, $73, $74);

{ a text typed (UTF-8) to the form the line keeps }
function ToLine(const S: ShortString): ShortString;
var
  I, Used: Integer;
  Cp: LongWord;
  B: Byte;
begin
  if not InputLineOem then
    Exit(S);
  Result := '';
  I := 1;
  while I <= Length(S) do
  begin
    if Byte(S[I]) < $80 then
    begin
      Result := Result + S[I];
      Inc(I);
    end
    else if Utf8Decode(@S[I], Length(S) - I + 1, Cp, Used) then
    begin
      B := CpFromUnicode(Cp);
      if B = 0 then
        B := Ord('?');
      Result := Result + Chr(B);
      Inc(I, Used);
    end
    else
    begin
      Result := Result + S[I];
      Inc(I);
    end;
  end;
end;

function PrevWord(const S: ShortString; Pos: Integer): Integer;
var
  I: Integer;
begin
  for I := Pos - 1 downto 1 do
    if (S[I + 1] <> ' ') and (S[I] = ' ') then
      Exit(I);
  Result := 0;
end;

function NextWord(const S: ShortString; Pos: Integer): Integer;
var
  I: Integer;
begin
  for I := Pos to Length(S) - 2 do
    if (S[I + 1] = ' ') and (S[I + 2] <> ' ') then
      Exit(I + 1);
  Result := Length(S);
end;

constructor TInputLine.Init(const Bounds: TRect; AMaxLen: Integer);
begin
  inherited Init(Bounds);
  LC := ' ';
  RC := ' ';
  if AMaxLen < 1 then
    AMaxLen := 1;
  if AMaxLen > 255 then
    AMaxLen := 255;
  MaxLen := AMaxLen;
  GetMem(Data, MaxLen + 1);
  GetMem(OldData, MaxLen + 1);
  Data^ := '';
  OldData^ := '';
  CurPos := 0;
  FirstPos := 0;
  SelStart := 0;
  SelEnd := 0;
  Validator := nil;
  State := State or sfCursorVis;
  Options := Options or ofSelectable or ofFirstClick;
end;

destructor TInputLine.Done;
begin
  FreeMem(Data);
  FreeMem(OldData);
  Data := nil;
  OldData := nil;
  if Validator <> nil then
    Dispose(Validator, Done);
  Validator := nil;
  inherited Done;
end;

function TInputLine.CanScroll(Delta: Integer): Boolean;
begin
  if Delta < 0 then
    Result := FirstPos > 0
  else if Delta > 0 then
    Result := TextWidthS(Data^) - FirstPos + 2 > Size.X
  else
    Result := False;
end;

function TInputLine.DataSize: Integer;
var
  DSize: Integer;
begin
  DSize := 0;
  if Validator <> nil then
    DSize := Validator^.Transfer(Data^, nil, vtDataSize);
  if DSize = 0 then
    DSize := MaxLen + 1;
  Result := DSize;
end;

function TInputLine.DisplayedPos(Pos: Integer): Integer;
begin
  Result := TextWidth(@Data^[1], Pos);
end;

procedure TInputLine.Draw;
var
  L, R: Integer;
  B: TDrawBuffer;
  Color: TColorAttr;

  function Pick(I: Integer): TColorAttr;
  begin
    if C[I] <> 0 then
      Result := AttrFromBIOS(C[I] and $FF)
    else
      Result := GetColor(I).Lo;
  end;

begin
  if (State and sfFocused) <> 0 then
    Color := Pick(2)
  else
    Color := Pick(1);
  B.Init(Size.X);
  B.MoveChar(0, Ord(' '), Color, Size.X);
  if Size.X > 1 then
    B.MoveStrS(1, Data^, Color, Size.X - 1, FirstPos);
  if CanScroll(1) then
    B.MoveChar(Size.X - 1, RightArrow, Pick(4), 1)
  else if RC <> ' ' then
    B.MoveChar(Size.X - 1, Ord(RC), Pick(4), 1);
  if CanScroll(-1) then
    B.MoveChar(0, LeftArrow, Pick(4), 1)
  else if LC <> ' ' then
    B.MoveChar(0, Ord(LC), Pick(4), 1);
  if (State and sfSelected) <> 0 then
  begin
    L := DisplayedPos(SelStart) - FirstPos;
    R := DisplayedPos(SelEnd) - FirstPos;
    if L < 0 then
      L := 0;
    if R > Size.X - 2 then
      R := Size.X - 2;
    if L < R then
      B.MoveChar(L + 1, 0, Pick(3), R - L);
  end;
  WriteLineD(0, 0, Size.X, Size.Y, B);
  SetCursor(DisplayedPos(CurPos) - FirstPos + 1, 0);
  B.Done;
end;

procedure TInputLine.GetData(var Rec);
begin
  if (Validator = nil) or (Validator^.Transfer(Data^, @Rec, vtGetData) = 0) then
    Move(Data^, Rec, DataSize);
end;

function TInputLine.GetPalette: TPalette;
begin
  Result := MakePalette(InputLinePalette);
end;

function TInputLine.MouseDelta(var Event: TEvent): Integer;
var
  Mouse: TPoint;
begin
  Mouse := MakeLocal(Event.Where);
  if Mouse.X <= 0 then
    Result := -1
  else if Mouse.X >= Size.X - 1 then
    Result := 1
  else
    Result := 0;
end;

function TInputLine.MousePos(var Event: TEvent): Integer;
var
  Mouse: TPoint;
  Pos, Len, Wd: Integer;
begin
  Mouse := MakeLocal(Event.Where);
  if Mouse.X < 1 then
    Mouse.X := 1;
  Pos := Mouse.X + FirstPos - 1;
  if Pos < 0 then
    Pos := 0;
  TextScroll(@Data^[1], Length(Data^), Pos, False, Len, Wd);
  Result := Len;
end;

procedure TInputLine.DeleteSelect;
begin
  if SelStart < SelEnd then
  begin
    Delete(Data^, SelStart + 1, SelEnd - SelStart);
    CurPos := SelStart;
  end;
end;

procedure TInputLine.DeleteCurrent;
var
  CharLen, CharWidth: Integer;
begin
  if CurPos < Length(Data^) then
  begin
    SelStart := CurPos;
    TextNext(@Data^[CurPos + 1], Length(Data^) - CurPos, CharLen, CharWidth);
    SelEnd := CurPos + CharLen;
    DeleteSelect;
  end;
end;

procedure TInputLine.AdjustSelectBlock;
begin
  if CurPos < Anchor then
  begin
    SelStart := CurPos;
    SelEnd := Anchor;
  end
  else
  begin
    SelStart := Anchor;
    SelEnd := CurPos;
  end;
end;

procedure TInputLine.SaveState;
begin
  if Validator <> nil then
  begin
    OldData^ := Data^;
    OldCurPos := CurPos;
    OldFirstPos := FirstPos;
    OldSelStart := SelStart;
    OldSelEnd := SelEnd;
  end;
end;

procedure TInputLine.RestoreState;
begin
  if Validator <> nil then
  begin
    Data^ := OldData^;
    CurPos := OldCurPos;
    FirstPos := OldFirstPos;
    SelStart := OldSelStart;
    SelEnd := OldSelEnd;
  end;
end;

function TInputLine.CheckValid(NoAutoFill: Boolean): Boolean;
var
  OldLen, NewLen: Integer;
  NewData: ShortString;
begin
  Result := True;
  if Validator <> nil then
  begin
    NewData := Data^;
    OldLen := Length(Data^);
    if not Validator^.IsValidInput(NewData, NoAutoFill) then
    begin
      RestoreState;
      Result := False;
    end
    else
    begin
      NewLen := Length(NewData);
      if NewLen > MaxLen then
      begin
        SetLength(NewData, MaxLen);
        NewLen := MaxLen;
      end;
      Data^ := NewData;
      if (CurPos >= OldLen) and (NewLen > OldLen) then
        CurPos := NewLen;
    end;
  end;
end;

function TInputLine.CanUpdateCommands: Boolean;
begin
  Result := (State and (sfActive or sfSelected)) = (sfActive or sfSelected);
end;

procedure TInputLine.SetCmdState(Command: Word; Enable: Boolean);
var
  S: TCommandSet;
begin
  S := [];
  Include(S, Command);
  if Enable and CanUpdateCommands then
    EnableCommands(S)
  else
    DisableCommands(S);
end;

procedure TInputLine.UpdateCommands;
begin
  SetCmdState(cmCut, SelStart < SelEnd);
  SetCmdState(cmCopy, SelStart < SelEnd);
  SetCmdState(cmPaste, True);
end;

{ inserts typed (or pasted) text at the cursor, as the keyboard does }
procedure TInputLine.TypeText(KeyText: ShortString);
begin
  KeyText := ToLine(KeyText);
  if Length(KeyText) = 0 then
    Exit;
  DeleteSelect;
  if (State and sfCursorIns) <> 0 then
    DeleteCurrent;
  if CheckValid(True) then
  begin
    if KeyText[1] in [#9, #13, #10] then
      KeyText[1] := ' ';     { tabs and line breaks become blanks }
    if Length(Data^) + Length(KeyText) <= MaxLen then
    begin
      if FirstPos > CurPos then
        FirstPos := CurPos;
      Insert(KeyText, Data^, CurPos + 1);
      Inc(CurPos, Length(KeyText));
    end;
    CheckValid(False);
  end;
end;

procedure TInputLine.HandleEvent(var Event: TEvent);
var
  ExtendBlock: Boolean;
  Delta, I, CurWidth, CharLen, CharWidth, ScanIdx: Integer;
  KeyText: ShortString;
  Sel: ShortString;
  Clip: AnsiString;
  J: Integer;
  IsPad: Boolean;
begin
  inherited HandleEvent(Event);
  if (State and sfSelected) <> 0 then
  begin
    case Event.What of
      evMouseDown:
        begin
          Delta := MouseDelta(Event);
          if CanScroll(Delta) then
          begin
            repeat
              if CanScroll(Delta) then
              begin
                Inc(FirstPos, Delta);
                DrawView;
              end;
            until not MouseEvent(Event, evMouseAuto);
          end
          else if (Event.EventFlags and meDoubleClick) <> 0 then
            SelectAll(True)
          else
          begin
            Anchor := MousePos(Event);
            repeat
              if Event.What = evMouseAuto then
              begin
                Delta := MouseDelta(Event);
                if CanScroll(Delta) then
                  Inc(FirstPos, Delta);
              end;
              CurPos := MousePos(Event);
              AdjustSelectBlock;
              DrawView;
            until not MouseEvent(Event, evMouseMove or evMouseAuto);
          end;
          ClearEvent(Event);
        end;
      evKeyDown:
        begin
          SaveState;
          Event.KeyCode := CtrlToArrow(Event.KeyCode);
          IsPad := False;
          for ScanIdx := 0 to High(PadKeys) do
            if PadKeys[ScanIdx] = Event.ScanCode then
              IsPad := True;
          if IsPad and ((Event.ControlKeyState and kbShift) <> 0) then
          begin
            Event.CharCode := 0;
            if CurPos = SelEnd then
              Anchor := SelStart
            else if SelStart = SelEnd then
              Anchor := CurPos
            else
              Anchor := SelEnd;
            ExtendBlock := True;
          end
          else
            ExtendBlock := False;
          case Event.KeyCode of
            kbLeft:
              Dec(CurPos, TextPrev(@Data^[1], CurPos));
            kbRight:
              begin
                TextNext(@Data^[CurPos + 1], Length(Data^) - CurPos, CharLen, CharWidth);
                Inc(CurPos, CharLen);
              end;
            kbCtrlLeft:
              CurPos := PrevWord(Data^, CurPos);
            kbCtrlRight:
              CurPos := NextWord(Data^, CurPos);
            kbHome:
              CurPos := 0;
            kbEnd:
              CurPos := Length(Data^);
            kbBack:
              begin
                if SelStart = SelEnd then
                begin
                  SelStart := CurPos - TextPrev(@Data^[1], CurPos);
                  SelEnd := CurPos;
                end;
                DeleteSelect;
                CheckValid(True);
              end;
            kbCtrlBack, kbAltBack:
              begin
                if SelStart = SelEnd then
                begin
                  SelStart := PrevWord(Data^, CurPos);
                  SelEnd := CurPos;
                end;
                DeleteSelect;
                CheckValid(True);
              end;
            kbDel:
              begin
                if SelStart = SelEnd then
                  DeleteCurrent
                else
                  DeleteSelect;
                CheckValid(True);
              end;
            kbCtrlDel:
              begin
                if SelStart = SelEnd then
                begin
                  SelStart := CurPos;
                  SelEnd := NextWord(Data^, CurPos);
                end;
                DeleteSelect;
                CheckValid(True);
              end;
            kbIns:
              SetState(sfCursorIns, (State and sfCursorIns) = 0);
          else
            begin
              KeyText := EventText(Event);
              J := Pos(#0, KeyText);
              if J > 0 then
                SetLength(KeyText, J - 1);
              if Length(KeyText) > 0 then
                TypeText(KeyText)
              else if Event.CharCode = ControlY then
              begin
                Data^ := '';
                CurPos := 0;
              end
              else
                Exit;
            end;
          end;
          if ExtendBlock then
            AdjustSelectBlock
          else
          begin
            SelStart := 0;
            SelEnd := 0;
          end;
          CurWidth := DisplayedPos(CurPos);
          if FirstPos > CurWidth then
            FirstPos := CurWidth;
          I := CurWidth - Size.X + 2;
          if FirstPos < I then
            FirstPos := I;
          DrawView;
          ClearEvent(Event);
        end;
      evCommand:
        if Event.Command = cmPaste then
        begin
          Clip := ClipboardGetText;
          J := Pos(#13, Clip);
          if (J = 0) or ((Pos(#10, Clip) > 0) and (Pos(#10, Clip) < J)) then
            J := Pos(#10, Clip);
          if J > 0 then
            SetLength(Clip, J - 1);
          if Length(Clip) > 255 then
            SetLength(Clip, 255);
          SaveState;
          TypeText(Clip);
          SelStart := 0;
          SelEnd := 0;
          DrawView;
          ClearEvent(Event);
        end
        else if (Event.Command = cmCut) or (Event.Command = cmCopy) then
        begin
          Sel := Copy(Data^, SelStart + 1, SelEnd - SelStart);
          if InputLineOem then
            ClipboardSetText(OemToUtf8(Sel))
          else
            ClipboardSetText(Sel);
          if Event.Command = cmCut then
          begin
            SaveState;
            DeleteSelect;
            CheckValid(True);
            SelStart := 0;
            SelEnd := 0;
            DrawView;
          end;
          ClearEvent(Event);
        end;
    end;
    if CanUpdateCommands then
      UpdateCommands;
  end;
end;

procedure TInputLine.SelectAll(Enable: Boolean; Scroll: Boolean);
begin
  SelStart := 0;
  if Enable then
  begin
    CurPos := Length(Data^);
    SelEnd := CurPos;
  end
  else
  begin
    CurPos := 0;
    SelEnd := 0;
  end;
  if Scroll then
  begin
    FirstPos := DisplayedPos(CurPos) - Size.X + 2;
    if FirstPos < 0 then
      FirstPos := 0;
  end;
  DrawView;
  if CanUpdateCommands then
    UpdateCommands;
end;

procedure TInputLine.SetData(var Rec);
begin
  if (Validator = nil) or (Validator^.Transfer(Data^, @Rec, vtSetData) = 0) then
  begin
    Move(Rec, Data^, DataSize - 1);
    if Length(Data^) > MaxLen then
      SetLength(Data^, MaxLen);
  end;
  SelectAll(True);
end;

procedure TInputLine.SetState(AState: Word; Enable: Boolean);
var
  UpdateBefore, UpdateAfter: Boolean;
begin
  UpdateBefore := CanUpdateCommands;
  inherited SetState(AState, Enable);
  UpdateAfter := CanUpdateCommands;
  if (AState = sfSelected) or ((AState = sfActive) and ((State and sfSelected) <> 0)) then
    SelectAll(Enable, False);
  if UpdateBefore <> UpdateAfter then
    UpdateCommands;
end;

procedure TInputLine.SetValidator(AValid: PValidator);
begin
  if Validator <> nil then
    Dispose(Validator, Done);
  Validator := AValid;
end;

function TInputLine.Valid(Command: Word): Boolean;
begin
  Result := True;
  if Validator <> nil then
  begin
    if Command = cmValid then
      Result := Validator^.Status = vsOk
    else if Command <> cmCancel then
      if not Validator^.Validate(Data^) then
      begin
        Select;
        Result := False;
      end;
  end;
end;

{ --- input box --------------------------------------------------------------- }

function InputBoxRect(const Bounds: TRect; const Title, ALabel: ShortString;
  var S: ShortString; Limit: Byte): Word;
var
  Dialog: PDialog;
  Control: PInputLine;
  Lbl: PLabel;
  R: TRect;
  C: Word;
begin
  New(Dialog, Init(Bounds, Title));
  R.Assign(4 + Length(ALabel), 2, Dialog^.Size.X - 3, 3);
  New(Control, Init(R, Limit));
  Dialog^.Insert(Control);
  R.Assign(2, 2, 3 + Length(ALabel), 3);
  New(Lbl, Init(R, ALabel, Control));
  Dialog^.Insert(Lbl);
  R.Assign(Dialog^.Size.X - 24, Dialog^.Size.Y - 4, Dialog^.Size.X - 14, Dialog^.Size.Y - 2);
  Dialog^.Insert(New(PButton, Init(R, MsgOKText, cmOK, bfDefault)));
  Inc(R.A.X, 12);
  Inc(R.B.X, 12);
  Dialog^.Insert(New(PButton, Init(R, MsgCancelText, cmCancel, bfNormal)));
  Dialog^.SelectNext(False);
  Dialog^.SetData(S);
  C := Application^.ExecView(Dialog);
  if C <> cmCancel then
    Dialog^.GetData(S);
  Dispose(Dialog, Done);
  Result := C;
end;

function InputBox(const Title, ALabel: ShortString; var S: ShortString; Limit: Byte): Word;
var
  R: TRect;
begin
  R.Assign(0, 0, 60, 8);
  R.Move((DeskTop^.Size.X - R.B.X) div 2, (DeskTop^.Size.Y - R.B.Y) div 2);
  Result := InputBoxRect(R, Title, ALabel, S, Limit);
end;

{ --- Streams ------------------------------------------------------------------ }

constructor TInputLine.Load(var S: TStream);
var
  T: PStr;
begin
  inherited Load(S);
  S.Read(MaxLen, SizeOf(MaxLen));
  S.Read(CurPos, SizeOf(CurPos));
  S.Read(FirstPos, SizeOf(FirstPos));
  S.Read(SelStart, SizeOf(SelStart));
  S.Read(SelEnd, SizeOf(SelEnd));
  if MaxLen < 1 then
    MaxLen := 1;
  if MaxLen > 255 then
    MaxLen := 255;
  GetMem(Data, MaxLen + 1);
  GetMem(OldData, MaxLen + 1);
  Data^ := '';
  OldData^ := '';
  T := S.ReadStr;
  if T <> nil then
  begin
    Data^ := Copy(T^, 1, MaxLen);
    DisposeStr(T);
  end;
  Validator := PValidator(S.Get);
  Anchor := -1;
end;

procedure TInputLine.Store(var S: TStream);
begin
  inherited Store(S);
  S.Write(MaxLen, SizeOf(MaxLen));
  S.Write(CurPos, SizeOf(CurPos));
  S.Write(FirstPos, SizeOf(FirstPos));
  S.Write(SelStart, SizeOf(SelStart));
  S.Write(SelEnd, SizeOf(SelEnd));
  S.WriteStr(Data);
  S.Put(Validator);
end;

function BuildInputLine(var S: TStream): PObject;
begin
  Result := New(PInputLine, Load(S));
end;

procedure StoreInputLine(P: PObject; var S: TStream);
begin
  PInputLine(P)^.Store(S);
end;

initialization
  RInputLine.ObjType := 11;
  RInputLine.VmtLink := PtrUInt(TypeOf(TInputLine));
  RInputLine.Load := @BuildInputLine;
  RInputLine.Store := @StoreInputLine;

end.
