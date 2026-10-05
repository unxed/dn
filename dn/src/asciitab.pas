{ The unit ASCIITab of DN: the table of the characters (a window with a 32 x 8 table and a line that shows the
  character that is under the cursor; Enter or a double click puts the character into the text that is being edited).
  Built over tv/ with the API that DN uses (ASCIITable, fASCIITable, the classes for the streams); the
  original is a copy of the ASCII table of the Borland demo and is in dn/exclude.list. }
{$mode objfpc}{$H-}
unit ASCIITab;

interface

uses
  Views, Drivers, Streams;

const
  boundsASCII: TPoint = (X: 0; Y: 0);
  CharASCII: Char = #4;
  AsciiTableCommandBase: Word = 910;

type
  { the table: the characters 0..255 in 8 rows of 32; the cursor is the current character (Data = its code) }

  TTable = class(TView)
    procedure Draw; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    function DataSize: Integer; virtual;
    procedure GetData(var Data); virtual;
    procedure SetData(var Data); virtual;
  end;

  { the line with the character, its decimal and hexadecimal code }

  TReport = class(TView)
    ASCIIChar: LongInt;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure Store(var S: TStream);
    procedure Draw; virtual;
    constructor Load(var S: TStream);
  end;


  TASCIIChart = class(TWindow)
    destructor Done; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    constructor Create(var R: TRect);
  end;

{ Shows the table; the chosen character is sent to the program as a key. }
procedure ASCIITable;

var
  { True while the table is active: the character is put into the line that is edited (and is not handled as a key:
    Esc that is typed ends a dialog, Esc that comes from the table is a character) }
  fASCIITable: Boolean;

implementation

uses
  SysUtils, basics, strutil, mainapp, Commands, DNHelp;

const
  cmCharacterFocused = 0;

{ --- TTable --- }

procedure TTable.Draw;
var
  Buf: TDrawBuffer;
  X, Y: Integer;
  Color: Byte;
begin
  Color := Byte(GetColorW(6));
  for Y := 0 to Size.Y - 1 do
  begin
    X := 0;
    while X < Size.X do
    begin
      MoveChar(Buf[X], Chr((Y * 32 + X) and $FF), Color, 1);
      Inc(X);
    end;
    WriteLineC(0, Y, Size.X, 1, Buf);
  end;
  ShowCursor;
end;

procedure TTable.HandleEvent(var Event: TEvent);

  procedure Focused;
  begin
    MessageL(Owner, evBroadcast, AsciiTableCommandBase + cmCharacterFocused, Cursor.X + 32 * Cursor.Y);
  end;

  procedure Goto_(NX, NY: Integer);
  begin
    if NX < 0 then NX := 0;
    if NX > Size.X - 1 then NX := Size.X - 1;
    if NY < 0 then NY := 0;
    if NY > Size.Y - 1 then NY := Size.Y - 1;
    SetCursor(NX, NY);
    Focused;
  end;

  procedure Choose;
  begin
    Message(Owner, evCommand, cmOK, nil);
  end;

var
  Mouse: TPoint;
  Code: LongInt;
begin
  if Event.What = evMouseDown then
  begin
    if (Event.EventFlags and meDoubleClick) <> 0 then
    begin
      Choose;
      ClearEvent(Event);
      Exit;
    end;
    repeat
      if MouseInView(Event.Where) then
      begin
        MakeLocal(Event.Where, Mouse);
        SetCursor(Mouse.X, Mouse.Y);
        Focused;
      end;
    until not MouseEvent(Event, evMouseMove);
    ClearEvent(Event);
    Exit;
  end;
  if Event.What = evKeyDown then
  begin
    Code := DNKeyCode(Event);
    case Code of
      kbCtrlPgUp: Goto_(0, 0);
      kbCtrlPgDn: Goto_(Size.X - 1, Size.Y - 1);
      kbCtrlHome, kbPgUp: Goto_(Cursor.X, 0);
      kbCtrlEnd, kbPgDn: Goto_(Cursor.X, Size.Y - 1);
      kbHome: Goto_(0, Cursor.Y);
      kbEnd: Goto_(Size.X - 1, Cursor.Y);
      kbUp: Goto_(Cursor.X, Cursor.Y - 1);
      kbDown: Goto_(Cursor.X, Cursor.Y + 1);
      kbLeft: Goto_(Cursor.X - 1, Cursor.Y);
      kbRight: Goto_(Cursor.X + 1, Cursor.Y);
      kbCtrlUp: Goto_(Cursor.X, Cursor.Y - 2);
      kbCtrlDown: Goto_(Cursor.X, Cursor.Y + 2);
      kbCtrlLeft: Goto_(Cursor.X - 5, Cursor.Y);
      kbCtrlRight: Goto_(Cursor.X + 5, Cursor.Y);
      kbEnter, kbCtrlB, kbCtrlP: Choose;
    else
      { a character: the cursor goes to it and it is chosen }
      if Event.CharCode > 0 then
      begin
        SetCursor(Event.CharCode mod 32, Event.CharCode div 32);
        Focused;
        Choose;
      end
      else
        Exit;
    end;
    ClearEvent(Event);
    Exit;
  end;
  inherited HandleEvent(Event);
end;

function TTable.DataSize: Integer;
begin
  Result := 1;
end;

procedure TTable.GetData(var Data);
begin
  Byte(Data) := Cursor.Y * 32 + Cursor.X;
end;

procedure TTable.SetData(var Data);
begin
  SetCursor(Byte(Data) mod 32, Byte(Data) div 32);
  MessageL(Owner, evBroadcast, AsciiTableCommandBase + cmCharacterFocused, Cursor.X + 32 * Cursor.Y);
  Owner.Redraw;
end;

{ --- TReport --- }

constructor TReport.Load(var S: TStream);
begin
  inherited Load(S);
  S.Read(ASCIIChar, SizeOf(ASCIIChar));
end;

procedure TReport.Draw;
var
  Buf: TDrawBuffer;
  Normal, Value: Byte;
  T: String;
begin
  Normal := Byte(GetColorW(6));
  Value := Byte(GetColorW(7));
  MoveChar(Buf[0], ' ', Normal, Size.X);
  T := ' Char:   Decimal: ' + Format('%3d', [ASCIIChar]) + ' Hex: ' + Format('%.2x', [ASCIIChar]);
  MoveStr(Buf[0], T, Normal);
  { the value fields in the color of the selection }
  MoveChar(Buf[16], ' ', Value, 0);
  if (ASCIIChar > 0) and (Size.X > 7) then
    MoveChar(Buf[7], Chr(ASCIIChar and $FF), Value, 1);
  WriteLineC(0, 0, Size.X, 1, Buf);
end;

procedure TReport.HandleEvent(var Event: TEvent);
begin
  inherited HandleEvent(Event);
  if Event.What <> evBroadcast then Exit;
  if Event.Command <> AsciiTableCommandBase + cmCharacterFocused then Exit;
  ASCIIChar := Event.InfoLong;
  DrawView;
end;

procedure TReport.Store(var S: TStream);
begin
  inherited Store(S);
  S.Write(ASCIIChar, SizeOf(ASCIIChar));
end;

{ --- TASCIIChart --- }

constructor TASCIIChart.Create(var R: TRect);
var
  Control: TView;
  T: TRect;
begin
  R.Assign(0, 0, 34, 12);
  inherited Create(R, GetString(dlASCIIChart), wnNoNumber);
  Flags := Flags and not (wfGrow or wfZoom);
  Options := Options and ofTopSelect;
  HelpCtx := hcAsciiChart;
  Palette := wpGrayWindow;

  { inside the frame: the line with the code at the bottom (one row), the table over it }
  GetExtent(R);
  R.Grow(-1, -1);
  T.Assign(R.A.X, R.B.Y - 1, R.B.X, R.B.Y);
  Control := TReport.Create(T);
  Control.Options := Control.Options or ofFramed;
  Control.EventMask := evBroadcast or Control.EventMask;
  Insert(Control);
  T.Assign(R.A.X, R.A.Y, R.B.X, R.B.Y - 2);
  Control := TTable.Create(T);
  Control.Options := Control.Options or ofSelectable or ofFramed;
  Control.EventMask := $FFFF;
  Control.BlockCursor;
  Insert(Control);
  Control.Select;
  fASCIITable := True;
end;

procedure TASCIIChart.HandleEvent(var Event: TEvent);
begin
  { the commands end the modal state: cmOK (the character is chosen), cmYes, cmCancel (Esc, the close box) }
  if (Event.What = evCommand) and ((State and sfModal) <> 0) then
    case Event.Command of
      cmOK, cmYes, cmCancel:
        begin
          EndModal(Event.Command);
          ClearEvent(Event);
          Exit;
        end;
      cmClose:
        begin
          EndModal(cmCancel);
          ClearEvent(Event);
          Exit;
        end;
    end;
  if (Event.What = evKeyDown) and (DNKeyCode(Event) = kbEsc) and ((State and sfModal) <> 0) then
  begin
    EndModal(cmCancel);
    ClearEvent(Event);
    Exit;
  end;
  inherited HandleEvent(Event);
end;

destructor TASCIIChart.Done;
begin
  fASCIITable := False;
  inherited Destroy;
end;

{ --- the procedure --- }

procedure ASCIITable;
var
  P: TWindow;
  W: Word;
  E: TEvent;
  R: TRect;
  CR: TView;

  function GetCH: Boolean;
  begin
    W := Desktop.ExecView(P);
    P.GetData(CharASCII);
    ClearEvent(E);
    E.What := evKeyDown;
    SetDNKeyCode(E, Byte(CharASCII));
    if W in [cmOK, cmYes] then
      Application.HandleEvent(E);
    GetCH := W = cmYes;
  end;

begin
  P := TASCIIChart.Create(R);
  P.MoveTo(boundsASCII.X, boundsASCII.Y);
  P.SetData(CharASCII);
  CR := Desktop.Current;
  while GetCH do
    ;
  boundsASCII := P.Origin;
  P.Free;
  if CR <> nil then
    CR.Select;
end;

end.
