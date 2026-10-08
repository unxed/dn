{ The unit ASCIITab of DN: the table of the characters (a window with a 32 x 8 table and a line that shows the
  character that is under the cursor; Enter or a double click puts the character into the text that is being edited).
  The views are those of tv/ TvAscii; here: the key codes of DN, the code as one byte of data, the text of the report,
  the title, the help context and the palette of DN, and the modal run. }
{$mode objfpc}{$H-}
unit ASCIITab;

interface

uses
  Views, Drivers, Streams, TvAscii;

const
  boundsASCII: TPoint = (X: 0; Y: 0);
  CharASCII: Char = #4;

type
  { the table: the characters 0..255 in 8 rows of 32; the cursor is the current character (Data = its code, a byte) }

  TTable = class(TAsciiTable)
    constructor Create(const Bounds: TRect);
    function KeyAction(var Event: TEvent): TAsciiKey; override;
    function TypedCode(var Event: TEvent): LongInt; override;
    function DataSize: Integer; override;
    procedure GetData(var Data); override;
    procedure SetData(var Data); override;
  end;

  { the line with the character, its decimal and hexadecimal code }

  TReport = class(TAsciiReport)
    procedure ReportParts(out Prefix, Rest: AnsiString); override;
  end;

  TASCIIChart = class(TvAscii.TAsciiChart)
    destructor Destroy; override;
    procedure HandleEvent(var Event: TEvent); override;
    function MakeTable(const Bounds: TRect): TAsciiTable; override;
    function MakeReport(const Bounds: TRect): TAsciiReport; override;
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

{ --- TTable --- }

constructor TTable.Create(const Bounds: TRect);
begin
  inherited Create(Bounds);
  MarkCursor := False;
end;

function TTable.KeyAction(var Event: TEvent): TAsciiKey;
begin
  case DNKeyCode(Event) of
    kbCtrlPgUp: Result := akFirst;
    kbCtrlPgDn: Result := akLast;
    kbCtrlHome, kbPgUp: Result := akColTop;
    kbCtrlEnd, kbPgDn: Result := akColBottom;
    kbHome: Result := akRowStart;
    kbEnd: Result := akRowEnd;
    kbUp: Result := akUp;
    kbDown: Result := akDown;
    kbLeft: Result := akLeft;
    kbRight: Result := akRight;
    kbCtrlUp: Result := akUp2;
    kbCtrlDown: Result := akDown2;
    kbCtrlLeft: Result := akLeft5;
    kbCtrlRight: Result := akRight5;
    kbEnter, kbCtrlB, kbCtrlP: Result := akPick;
  else
    Result := akNone;
  end;
end;

{ any character (a control character too) goes to its code and is chosen }
function TTable.TypedCode(var Event: TEvent): LongInt;
begin
  if Event.CharCode > 0 then
    Result := Event.CharCode
  else
    Result := -1;
end;

function TTable.DataSize: Integer;
begin
  Result := 1;
end;

procedure TTable.GetData(var Data);
begin
  Byte(Data) := Code;
end;

procedure TTable.SetData(var Data);
begin
  SetCode(Byte(Data));
  if Owner <> nil then
    Owner.Redraw;
end;

{ --- TReport --- }

procedure TReport.ReportParts(out Prefix, Rest: AnsiString);
begin
  Prefix := ' Char: ';
  Rest := ' Decimal: ' + Format('%3d', [Code]) + ' Hex: ' + Format('%.2x', [Code]);
end;

{ --- TASCIIChart --- }

constructor TASCIIChart.Create(var R: TRect);
begin
  inherited Create(GetString(dlASCIIChart), False);
  Options := Options and ofTopSelect;
  HelpCtx := hcAsciiChart;
  Palette := wpGrayWindow;
  Table.EventMask := $FFFF;
  fASCIITable := True;
end;

function TASCIIChart.MakeTable(const Bounds: TRect): TAsciiTable;
begin
  Result := TTable.Create(Bounds);
end;

function TASCIIChart.MakeReport(const Bounds: TRect): TAsciiReport;
begin
  Result := TReport.Create(Bounds);
end;

procedure TASCIIChart.HandleEvent(var Event: TEvent);
begin
  { the commands end the modal state: cmOK and the pick of the table (the character is chosen), cmYes, cmCancel (Esc,
    the close box) }
  if (Event.What = evCommand) and ((State and sfModal) <> 0) then
  begin
    if Event.Command = AsciiCommandBase + acPicked then
      Event.Command := cmOK;
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
  end;
  if (Event.What = evKeyDown) and (DNKeyCode(Event) = kbEsc) and ((State and sfModal) <> 0) then
  begin
    EndModal(cmCancel);
    ClearEvent(Event);
    Exit;
  end;
  inherited HandleEvent(Event);
end;

destructor TASCIIChart.Destroy;
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
