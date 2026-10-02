{ TvHist: the history of input lines: the list of strings (HistoryAdd...), THistory (the arrow
  next to an input line), THistoryWindow, THistoryViewer.

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/dialogs.h, util.h (class declarations, history functions)
    source/tvision/histlist.cpp, thistory.cpp, thistwin.cpp, thstview.cpp, tvtext1.cpp (icon)
  Borland disclaimer and MIT notice: tv/COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/DESIGN.md):
    - the history is an array of records instead of a block of bytes; the behavior is the
      same: HistorySize bytes are counted as in the original (3 bytes + the length of the
      string per record) and the oldest records are dropped when the strings do not fit;
      the empty first record of the original is not needed (after it is dropped, the
      original skips the first string of its list);
    - the history is initialized and freed by the unit itself;
    - HistoryStr is a function that returns '' if there is no such string;
    - THistoryWindow gets its viewer from the virtual InitViewer;
    - streams are not translated yet. }
unit TvHist;

{$I tvdefs.inc}

interface

uses
  TvGeom, TvColors, TvCell, TvKeys, TvEvents, TvText, TvDrawBuf, TvObjs, TvUtil, TvViews,
  TvDialog, TvWindow, TvList, TvInput;

var
  { the size of the history block in bytes; set it before the first HistoryAdd }
  HistorySize: Word = 1024;

procedure ClearHistory;
{ frees the memory of the history (it is empty afterwards) }
procedure DoneHistory;
function HistoryCount(Id: Byte): Integer;
procedure HistoryAdd(Id: Byte; const Str: ShortString);
function HistoryStr(Id: Byte; Index: Integer): ShortString;

const
  HistoryIcon = #$DE'~'#$19'~'#$DD;
  HistoryPalette = #$16#$17;
  HistoryWindowPalette = #$13#$13#$15#$18#$17#$13#$14;
  HistoryViewerPalette = #$06#$06#$07#$06#$06;

type
  PHistoryViewer = ^THistoryViewer;
  THistoryViewer = object(TListViewer)
    HistoryId: Word;
    constructor Init(const Bounds: TRect; AHScrollBar, AVScrollBar: PScrollBar; AHistoryId: Word);
    function GetPalette: TPalette; virtual;
    function GetText(Item, MaxLen: Integer): ShortString; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    function HistoryWidth: Integer;
  end;

  PHistoryWindow = ^THistoryWindow;
  THistoryWindow = object(TWindow)
    Viewer: PListViewer;
    constructor Init(const Bounds: TRect; AHistoryId: Word);
    function GetPalette: TPalette; virtual;
    function GetSelection: ShortString;
    procedure HandleEvent(var Event: TEvent); virtual;
    function InitViewer(R: TRect; AHistoryId: Word): PListViewer; virtual;
  end;

  { Palette: 1 = arrow, 2 = sides }
  PHistory = ^THistory;
  THistory = object(TView)
    Link: PInputLine;
    HistoryId: Word;
    constructor Init(const Bounds: TRect; ALink: PInputLine; AHistoryId: Word);
    destructor Done; virtual;
    procedure Draw; virtual;
    function GetPalette: TPalette; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    function InitHistoryWindow(const Bounds: TRect): PHistoryWindow; virtual;
    procedure RecordHistory(const S: ShortString); virtual;
  end;

implementation

{ --- the history list -------------------------------------------------------- }

type
  THistRec = record
    Id: Byte;
    Str: ShortString;
  end;

var
  Recs: array of THistRec;
  RecCount: Integer = 0;
  Used: Integer = 0;          { the bytes taken by the records }
  CurId: Byte = 0;
  CurRec: Integer = -1;       { the index of the current record, -1 if none }

function RecLen(Index: Integer): Integer;
begin
  Result := Length(Recs[Index].Str) + 3;
end;

procedure ClearHistory;
begin
  SetLength(Recs, 16);
  RecCount := 0;
  Used := 0;
end;

procedure DoneHistory;
begin
  SetLength(Recs, 0);
  RecCount := 0;
  Used := 0;
end;

procedure AdvanceStringPointer;
begin
  Inc(CurRec);
  while (CurRec < RecCount) and (Recs[CurRec].Id <> CurId) do
    Inc(CurRec);
  if CurRec >= RecCount then
    CurRec := -1;
end;

procedure DeleteRec(Index: Integer);
var
  I: Integer;
begin
  Dec(Used, RecLen(Index));
  for I := Index to RecCount - 2 do
    Recs[I] := Recs[I + 1];
  Dec(RecCount);
end;

procedure InsertString(Id: Byte; const Str: ShortString);
var
  Len: Integer;
begin
  Len := Length(Str) + 3;
  while (Len > HistorySize - Used) and (RecCount > 0) do
    DeleteRec(0);
  if RecCount >= Length(Recs) then
    SetLength(Recs, Length(Recs) * 2 + 16);
  Recs[RecCount].Id := Id;
  Recs[RecCount].Str := Str;
  Inc(RecCount);
  Inc(Used, Len);
end;

procedure StartId(Id: Byte);
begin
  CurId := Id;
  CurRec := -1;       { the original starts at its empty first record instead }
end;

function HistoryCount(Id: Byte): Integer;
begin
  StartId(Id);
  Result := 0;
  AdvanceStringPointer;
  while CurRec <> -1 do
  begin
    Inc(Result);
    AdvanceStringPointer;
  end;
end;

procedure HistoryAdd(Id: Byte; const Str: ShortString);
begin
  if Str = '' then
    Exit;
  StartId(Id);
  AdvanceStringPointer;
  while CurRec <> -1 do
  begin
    if Str = Recs[CurRec].Str then
      DeleteRec(CurRec);
    AdvanceStringPointer;
  end;
  InsertString(Id, Str);
end;

function HistoryStr(Id: Byte; Index: Integer): ShortString;
var
  I: Integer;
begin
  StartId(Id);
  for I := 0 to Index do
    AdvanceStringPointer;
  if CurRec <> -1 then
    Result := Recs[CurRec].Str
  else
    Result := '';
end;

{ --- THistoryViewer ---------------------------------------------------------- }

constructor THistoryViewer.Init(const Bounds: TRect; AHScrollBar, AVScrollBar: PScrollBar;
  AHistoryId: Word);
begin
  inherited Init(Bounds, 1, AHScrollBar, AVScrollBar);
  HistoryId := AHistoryId;
  SetRange(HistoryCount(AHistoryId));
  if Range > 1 then
    FocusItem(1);
  if HScrollBar <> nil then
    HScrollBar^.SetRange(0, HistoryWidth - Size.X + 3);
end;

function THistoryViewer.GetPalette: TPalette;
begin
  Result := MakePalette(HistoryViewerPalette);
end;

function THistoryViewer.GetText(Item, MaxLen: Integer): ShortString;
begin
  Result := HistoryStr(HistoryId, Item);
  if Length(Result) > MaxLen then
    SetLength(Result, MaxLen);
end;

procedure THistoryViewer.HandleEvent(var Event: TEvent);
begin
  if ((Event.What = evMouseDown) and ((Event.EventFlags and meDoubleClick) <> 0)) or
    ((Event.What = evKeyDown) and (Event.KeyCode = kbEnter)) then
  begin
    EndModal(cmOK);
    ClearEvent(Event);
  end
  else if ((Event.What = evKeyDown) and (Event.KeyCode = kbEsc)) or
    ((Event.What = evCommand) and (Event.Command = cmCancel)) then
  begin
    EndModal(cmCancel);
    ClearEvent(Event);
  end
  else
    inherited HandleEvent(Event);
end;

function THistoryViewer.HistoryWidth: Integer;
var
  I, W: Integer;
begin
  Result := 0;
  for I := 0 to HistoryCount(HistoryId) - 1 do
  begin
    W := TextWidthS(HistoryStr(HistoryId, I));
    if W > Result then
      Result := W;
  end;
end;

{ --- THistoryWindow ---------------------------------------------------------- }

constructor THistoryWindow.Init(const Bounds: TRect; AHistoryId: Word);
begin
  inherited Init(Bounds, '', wnNoNumber);
  Flags := wfClose;
  Viewer := InitViewer(GetExtent, AHistoryId);
  if Viewer <> nil then
    Insert(Viewer);
end;

function THistoryWindow.GetPalette: TPalette;
begin
  Result := MakePalette(HistoryWindowPalette);
end;

function THistoryWindow.GetSelection: ShortString;
begin
  Result := Viewer^.GetText(Viewer^.Focused, 255);
end;

procedure THistoryWindow.HandleEvent(var Event: TEvent);
begin
  inherited HandleEvent(Event);
  if (Event.What = evMouseDown) and not MouseInView(Event.Where) then
  begin
    EndModal(cmCancel);
    ClearEvent(Event);
  end;
end;

function THistoryWindow.InitViewer(R: TRect; AHistoryId: Word): PListViewer;
begin
  R.Grow(-1, -1);
  New(PHistoryViewer(Result), Init(R, StandardScrollBar(sbHorizontal or sbHandleKeyboard),
    StandardScrollBar(sbVertical or sbHandleKeyboard), AHistoryId));
end;

{ --- THistory ---------------------------------------------------------------- }

constructor THistory.Init(const Bounds: TRect; ALink: PInputLine; AHistoryId: Word);
begin
  inherited Init(Bounds);
  Link := ALink;
  HistoryId := AHistoryId;
  Options := Options or ofPostProcess;
  EventMask := EventMask or evBroadcast;
end;

destructor THistory.Done;
begin
  Link := nil;
  inherited Done;
end;

procedure THistory.Draw;
var
  B: TDrawBuffer;
begin
  B.Init(Size.X);
  B.MoveCStrS(0, HistoryIcon, GetColor($0102));
  WriteLineD(0, 0, Size.X, Size.Y, B);
  B.Done;
end;

function THistory.GetPalette: TPalette;
begin
  Result := MakePalette(HistoryPalette);
end;

procedure THistory.HandleEvent(var Event: TEvent);
var
  HistoryWindow: PHistoryWindow;
  R, P: TRect;
  C: Word;
  Sel: ShortString;
begin
  inherited HandleEvent(Event);
  if (Event.What = evMouseDown) or
    ((Event.What = evKeyDown) and (CtrlToArrow(Event.KeyCode) = kbDown) and
     ((Link^.State and sfFocused) <> 0)) then
  begin
    if not Link^.Focus then
    begin
      ClearEvent(Event);
      Exit;
    end;
    RecordHistory(Link^.Data^);
    R := Link^.GetBounds;
    Dec(R.A.X);
    Inc(R.B.X);
    Inc(R.B.Y, 7);
    Dec(R.A.Y);
    P := Owner^.GetExtent;
    R.Intersect(P);
    Dec(R.B.Y);
    HistoryWindow := InitHistoryWindow(R);
    if HistoryWindow <> nil then
    begin
      C := Owner^.ExecView(HistoryWindow);
      if C = cmOK then
      begin
        Sel := HistoryWindow^.GetSelection;
        if Length(Sel) > Link^.MaxLen then
          SetLength(Sel, Link^.MaxLen);
        Link^.Data^ := Sel;
        Link^.SelectAll(True);
        Link^.DrawView;
      end;
      Dispose(HistoryWindow, Done);
    end;
    ClearEvent(Event);
  end
  else if Event.What = evBroadcast then
  begin
    if ((Event.Command = cmReleasedFocus) and (Event.InfoPtr = Link)) or
      (Event.Command = cmRecordHistory) then
      RecordHistory(Link^.Data^);
  end;
end;

function THistory.InitHistoryWindow(const Bounds: TRect): PHistoryWindow;
begin
  New(Result, Init(Bounds, HistoryId));
  Result^.HelpCtx := Link^.HelpCtx;
end;

procedure THistory.RecordHistory(const S: ShortString);
begin
  HistoryAdd(Byte(HistoryId), S);
end;

initialization
  ClearHistory;
finalization
  DoneHistory;
end.
