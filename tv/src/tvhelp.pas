{ TvHelp: the help system of Turbo Vision: topics with paragraphs and cross references (THelpTopic), the index of
  their positions (THelpIndex), the help file (THelpFile), the viewer (THelpViewer) and its window (THelpWindow).

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/helpbase.h, help.h (class declarations)
    source/tvision/helpbase.cpp, help.cpp
  Borland disclaimer and MIT notice: tv/COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/DESIGN.md):
    - the streams are those of TvObjs; the stream records (10000: THelpTopic, 10001: THelpIndex) are the numbers of Borland
      Pascal, RegisterType(RHelpTopic) and RegisterType(RHelpIndex) make them known; the fields are written with fixed sizes:
      the count of the paragraphs (LongInt), for each: the size (Word), Wrap (Byte), the bytes of the text; the count of
      the cross references (LongInt), for each: Ref (LongInt), Offset (LongInt), Length (Byte); THelpIndex: Size (LongInt:
      the contexts go up to 65535, which does not fit a Word with the step of 10), then Size LongInts;
    - a line of a topic is a ShortString (longer lines are cut to 255 bytes);
    - the help files are made by tvhc (tv/tools/tvhc.pas) from the text of a help (.htx). }
unit TvHelp;

{$I tvdefs.inc}

interface

uses
  TvGeom, TvColors, TvCell, TvKeys, TvEvents, TvText, TvDrawBuf, TvObjs, TvUtil, TvViews, TvWindow;

const
  MagicHeader = $46484246;          { 'FBHF' }
  CHelpViewer = #$06#$07#$08;
  CHelpWindow = #$80#$81#$82#$83#$84#$85#$86#$87;
  { the title of the help window and the text of a topic that is not in the file }
  HelpWinTitle = 'Help';
  InvalidContext = #10' No help available in this context.';

type
  PParagraph = ^TParagraph;
  TParagraph = record
    Next: PParagraph;
    Wrap: Boolean;
    Size: Word;
    Text: PByte;                    { Size bytes (and one more, zero) }
  end;

  PCrossRef = ^TCrossRef;
  TCrossRef = record
    Ref: LongInt;                   { the number of the topic that the reference leads to }
    Offset: LongInt;                { in the text of the topic, counted from 1 over the paragraphs }
    Length: Byte;
  end;

  TCrossRefHandler = procedure(var S: TStream; Ref: LongInt);

  PHelpTopic = ^THelpTopic;
  THelpTopic = object(TObject)
    Paragraphs: PParagraph;
    NumRefs: Integer;
    CrossRefs: PCrossRef;
    constructor Init;
    constructor Load(var S: TStream);
    destructor Done; virtual;
    procedure Store(var S: TStream);
    procedure AddCrossRef(Ref: TCrossRef);
    procedure AddParagraph(P: PParagraph);
    { the place of a cross reference in the wrapped text: X, Y (Y from 1) and the width on the screen }
    procedure GetCrossRef(I: Integer; var Loc: TPoint; var Length: Byte; var Ref: Integer);
    function GetLine(Line: Integer): ShortString;
    function GetNumCrossRefs: Integer;
    function LongestLineWidth: Integer;
    function NumLines: Integer;
    procedure SetCrossRef(I: Integer; const Ref: TCrossRef);
    procedure SetNumCrossRefs(I: Integer);
    procedure SetWidth(AWidth: Integer);
  private
    Width: Integer;
    LastOffset: Integer;
    LastLine: Integer;
    LastParagraph: PParagraph;
    procedure WrapText(Text: PByte; Size: Integer; var Offset: Integer; Wrap: Boolean; out LineStart, LineLen: Integer);
    procedure DisposeParagraphs;
  end;

  PHelpIndex = ^THelpIndex;
  THelpIndex = object(TObject)
    Size: LongInt;
    Index: PLongInt;
    constructor Init;
    constructor Load(var S: TStream);
    destructor Done; virtual;
    procedure Store(var S: TStream);
    function Position(I: Integer): LongInt;
    procedure Add(I: Integer; Val: LongInt);
  end;

  PHelpFile = ^THelpFile;
  THelpFile = object(TObject)
    Stream: PStream;
    Modified: Boolean;
    Index: PHelpIndex;
    IndexPos: LongInt;
    { the file takes the stream and disposes it }
    constructor Init(S: PStream);
    destructor Done; virtual;
    function GetTopic(I: Integer): PHelpTopic;
    function InvalidTopic: PHelpTopic;
    procedure RecordPositionInIndex(I: Integer);
    procedure PutTopic(Topic: PHelpTopic);
  end;

  { Palette: 1 = normal, 2 = keyword, 3 = selected keyword }
  PHelpViewer = ^THelpViewer;
  THelpViewer = object(TScroller)
    HFile: PHelpFile;
    Topic: PHelpTopic;
    Selected: Integer;
    constructor Init(const Bounds: TRect; AHScrollBar, AVScrollBar: PScrollBar; AHelpFile: PHelpFile; Context: Word);
    destructor Done; virtual;
    procedure ChangeBounds(const Bounds: TRect); virtual;
    procedure Draw; virtual;
    function GetPalette: TPalette; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure MakeSelectVisible(ASelected: Integer; var KeyPoint: TPoint; var KeyLength: Byte; var KeyRef: Integer);
    procedure SwitchToTopic(KeyRef: Integer);
  end;

  { Palette: 1 = frame passive, 2 = frame active, 3 = frame icon, 4 = scroll bar page area, 5 = scroll bar controls,
    6 = help viewer normal, 7 = help viewer keyword, 8 = help viewer selected keyword }
  PHelpWindow = ^THelpWindow;
  THelpWindow = object(TWindow)
    Viewer: PHelpViewer;
    constructor Init(AHelpFile: PHelpFile; Context: Word);
    procedure GotoContext(Context: Word);    { shows the topic of the context (DN reuses a window of the help) }
    function GetPalette: TPalette; virtual;
  end;

procedure NotAssigned(var S: TStream; Ref: LongInt);

var
  CrossRefHandler: TCrossRefHandler = @NotAssigned;
  { stream records: RegisterType(RHelpTopic), RegisterType(RHelpIndex) }
  RHelpTopic, RHelpIndex: TStreamRec;

implementation

procedure NotAssigned(var S: TStream; Ref: LongInt);
begin
end;

{ --- THelpTopic -------------------------------------------------------------- }

constructor THelpTopic.Init;
begin
  inherited Init;
  Paragraphs := nil;
  NumRefs := 0;
  CrossRefs := nil;
  Width := 0;
  LastOffset := 0;
  LastLine := MaxInt;
  LastParagraph := nil;
end;

constructor THelpTopic.Load(var S: TStream);
var
  I, Count: LongInt;
  P: PParagraph;
  PP: ^PParagraph;
  C: PCrossRef;
begin
  inherited Init;
  Paragraphs := nil;
  NumRefs := 0;
  CrossRefs := nil;
  LastOffset := 0;
  LastParagraph := nil;
  S.Read(Count, SizeOf(Count));
  PP := @Paragraphs;
  for I := 1 to Count do
  begin
    New(P);
    S.Read(P^.Size, SizeOf(P^.Size));
    S.Read(P^.Wrap, SizeOf(P^.Wrap));
    GetMem(P^.Text, P^.Size + 1);
    if P^.Size > 0 then
      S.Read(P^.Text^, P^.Size);
    P^.Text[P^.Size] := 0;
    P^.Next := nil;
    PP^ := P;
    PP := @P^.Next;
  end;
  S.Read(Count, SizeOf(Count));
  if Count > 0 then
  begin
    GetMem(CrossRefs, Count * SizeOf(TCrossRef));
    NumRefs := Count;
    for I := 0 to Count - 1 do
    begin
      C := CrossRefs + I;
      S.Read(C^.Ref, SizeOf(C^.Ref));
      S.Read(C^.Offset, SizeOf(C^.Offset));
      S.Read(C^.Length, SizeOf(C^.Length));
    end;
  end;
  Width := 0;
  LastLine := MaxInt;
end;

procedure THelpTopic.Store(var S: TStream);
var
  I: LongInt;
  P: PParagraph;
  C: PCrossRef;
begin
  I := 0;
  P := Paragraphs;
  while P <> nil do
  begin
    Inc(I);
    P := P^.Next;
  end;
  S.Write(I, SizeOf(I));
  P := Paragraphs;
  while P <> nil do
  begin
    S.Write(P^.Size, SizeOf(P^.Size));
    S.Write(P^.Wrap, SizeOf(P^.Wrap));
    if P^.Size > 0 then
      S.Write(P^.Text^, P^.Size);
    P := P^.Next;
  end;
  I := NumRefs;
  S.Write(I, SizeOf(I));
  for I := 0 to NumRefs - 1 do
  begin
    C := CrossRefs + I;
    S.Write(C^.Ref, SizeOf(C^.Ref));
    S.Write(C^.Offset, SizeOf(C^.Offset));
    S.Write(C^.Length, SizeOf(C^.Length));
  end;
end;

procedure THelpTopic.DisposeParagraphs;
var
  P, T: PParagraph;
begin
  P := Paragraphs;
  while P <> nil do
  begin
    T := P;
    P := P^.Next;
    FreeMem(T^.Text, T^.Size + 1);
    Dispose(T);
  end;
  Paragraphs := nil;
end;

destructor THelpTopic.Done;
begin
  DisposeParagraphs;
  if CrossRefs <> nil then
    FreeMem(CrossRefs, NumRefs * SizeOf(TCrossRef));
  CrossRefs := nil;
  NumRefs := 0;
  inherited Done;
end;

procedure THelpTopic.AddCrossRef(Ref: TCrossRef);
var
  P: PCrossRef;
begin
  GetMem(P, (NumRefs + 1) * SizeOf(TCrossRef));
  if NumRefs > 0 then
  begin
    Move(CrossRefs^, P^, NumRefs * SizeOf(TCrossRef));
    FreeMem(CrossRefs, NumRefs * SizeOf(TCrossRef));
  end;
  CrossRefs := P;
  (CrossRefs + NumRefs)^ := Ref;
  Inc(NumRefs);
end;

procedure THelpTopic.AddParagraph(P: PParagraph);
var
  PP, Back: PParagraph;
begin
  if Paragraphs = nil then
    Paragraphs := P
  else
  begin
    PP := Paragraphs;
    Back := PP;
    while PP <> nil do
    begin
      Back := PP;
      PP := PP^.Next;
    end;
    Back^.Next := P;
  end;
  P^.Next := nil;
end;

{ Takes one line of the paragraph from Offset: the line is wrapped to the width of the topic, a word that is cut by the wrapping
  goes to the next line. LineStart and LineLen tell the line without the white space at its end, Offset moves past it. }
procedure THelpTopic.WrapText(Text: PByte; Size: Integer; var Offset: Integer; Wrap: Boolean; out LineStart, LineLen: Integer);
var
  LineEnd, Wrapped, NewSize, Dummy: Integer;
begin
  LineStart := Offset;
  LineEnd := Offset;
  while (LineEnd < Size) and (Text[LineEnd] <> 10) do
    Inc(LineEnd);
  if LineEnd < Size then
    Inc(LineEnd);                  { past the #10 }
  LineLen := LineEnd - LineStart;
  if Wrap and (Width > 0) then
  begin
    TextScroll(Text + LineStart, LineLen, Width, False, Wrapped, Dummy);
    if (Wrapped > 0) and (Wrapped < LineLen) then
    begin
      NewSize := Wrapped;
      { the last word is omitted if the wrapping cut it off }
      while (NewSize > 0) and not (Text[LineStart + NewSize] in [9, 10, 11, 12, 13, 32]) do
        Dec(NewSize);
      { unless it fills the whole line }
      if NewSize = 0 then
        NewSize := Wrapped;
      { if a blank follows, it is kept so that Offset moves past it }
      if (NewSize < LineLen) and (Text[LineStart + NewSize] in [9, 10, 11, 12, 13, 32]) then
        Inc(NewSize);
      LineLen := NewSize;
    end;
  end;
  Inc(Offset, LineLen);
  while (LineLen > 0) and (Text[LineStart + LineLen - 1] in [9, 10, 11, 12, 13, 32]) do
    Dec(LineLen);
end;

procedure THelpTopic.GetCrossRef(I: Integer; var Loc: TPoint; var Length: Byte; var Ref: Integer);
var
  CurOffset, ParaOffset, Line, Offset, LineOffset, RefOffset, LS, LL: Integer;
  P: PParagraph;
  C: PCrossRef;
begin
  ParaOffset := 0;
  CurOffset := 0;
  Line := 0;
  C := CrossRefs + I;
  Offset := C^.Offset;
  P := Paragraphs;
  while P <> nil do
  begin
    LineOffset := CurOffset;
    WrapText(P^.Text, P^.Size, CurOffset, P^.Wrap, LS, LL);
    Inc(Line);
    if Offset <= ParaOffset + CurOffset then
    begin
      RefOffset := Offset - (ParaOffset + LineOffset) - 1;
      Loc.X := TextWidth(P^.Text + LineOffset, RefOffset);
      Loc.Y := Line;
      Length := TextWidth(P^.Text + LineOffset + RefOffset, C^.Length);
      Ref := C^.Ref;
      Exit;
    end;
    if CurOffset >= P^.Size then
    begin
      Inc(ParaOffset, P^.Size);
      P := P^.Next;
      CurOffset := 0;
    end;
  end;
  { the reference is not in the text (a damaged file): nowhere }
  Loc.X := 0;
  Loc.Y := 0;
  Length := 0;
  Ref := C^.Ref;
end;

function THelpTopic.GetLine(Line: Integer): ShortString;
var
  Offset, LS, LL: Integer;
  P: PParagraph;
begin
  Result := '';
  if LastLine < Line then
  begin
    Dec(Line, LastLine);
    LastLine := LastLine + Line;
    Offset := LastOffset;
    P := LastParagraph;
  end
  else
  begin
    P := Paragraphs;
    Offset := 0;
    LastLine := Line;
  end;
  while P <> nil do
  begin
    while Offset < P^.Size do
    begin
      Dec(Line);
      WrapText(P^.Text, P^.Size, Offset, P^.Wrap, LS, LL);
      if Line = 0 then
      begin
        LastOffset := Offset;
        LastParagraph := P;
        if LL > 255 then
          LL := 255;
        SetLength(Result, LL);
        if LL > 0 then
          Move(P^.Text[LS], Result[1], LL);
        Exit;
      end;
    end;
    P := P^.Next;
    Offset := 0;
  end;
end;

function THelpTopic.GetNumCrossRefs: Integer;
begin
  Result := NumRefs;
end;

function THelpTopic.LongestLineWidth: Integer;
var
  I, W: Integer;
  S: ShortString;
begin
  Result := 0;
  for I := 1 to NumLines do
  begin
    S := GetLine(I);
    W := TextWidthS(S);
    if W > Result then
      Result := W;
  end;
end;

function THelpTopic.NumLines: Integer;
var
  Offset, LS, LL: Integer;
  P: PParagraph;
begin
  Result := 0;
  P := Paragraphs;
  while P <> nil do
  begin
    Offset := 0;
    while Offset < P^.Size do
    begin
      Inc(Result);
      WrapText(P^.Text, P^.Size, Offset, P^.Wrap, LS, LL);
    end;
    P := P^.Next;
  end;
end;

procedure THelpTopic.SetCrossRef(I: Integer; const Ref: TCrossRef);
begin
  if (I >= 0) and (I < NumRefs) then
    (CrossRefs + I)^ := Ref;
end;

procedure THelpTopic.SetNumCrossRefs(I: Integer);
var
  P: PCrossRef;
begin
  if NumRefs = I then
    Exit;
  if I > 0 then
  begin
    GetMem(P, I * SizeOf(TCrossRef));
    FillChar(P^, I * SizeOf(TCrossRef), 0);
  end
  else
    P := nil;
  if NumRefs > 0 then
  begin
    if I > NumRefs then
      Move(CrossRefs^, P^, NumRefs * SizeOf(TCrossRef))
    else if I > 0 then
      Move(CrossRefs^, P^, I * SizeOf(TCrossRef));
    FreeMem(CrossRefs, NumRefs * SizeOf(TCrossRef));
  end;
  CrossRefs := P;
  NumRefs := I;
end;

procedure THelpTopic.SetWidth(AWidth: Integer);
begin
  Width := AWidth;
  LastLine := MaxInt;              { the cached place of the last line was found with the old width }
end;

{ --- THelpIndex -------------------------------------------------------------- }

constructor THelpIndex.Init;
begin
  inherited Init;
  Size := 0;
  Index := nil;
end;

constructor THelpIndex.Load(var S: TStream);
begin
  inherited Init;
  Index := nil;
  S.Read(Size, SizeOf(Size));
  if Size > 0 then
  begin
    GetMem(Index, Size * SizeOf(LongInt));
    S.Read(Index^, Size * SizeOf(LongInt));
  end;
end;

procedure THelpIndex.Store(var S: TStream);
begin
  S.Write(Size, SizeOf(Size));
  if Size > 0 then
    S.Write(Index^, Size * SizeOf(LongInt));
end;

destructor THelpIndex.Done;
begin
  if Index <> nil then
    FreeMem(Index, Size * SizeOf(LongInt));
  Index := nil;
  inherited Done;
end;

function THelpIndex.Position(I: Integer): LongInt;
begin
  if (I >= 0) and (I < Size) then
    Result := (Index + I)^
  else
    Result := -1;
end;

procedure THelpIndex.Add(I: Integer; Val: LongInt);
const
  Delta = 10;
var
  P: PLongInt;
  NewSize: Integer;
begin
  if I >= Size then
  begin
    NewSize := (I + Delta) div Delta * Delta;
    GetMem(P, NewSize * SizeOf(LongInt));
    if Index <> nil then
    begin
      Move(Index^, P^, Size * SizeOf(LongInt));
      FreeMem(Index, Size * SizeOf(LongInt));
    end;
    FillChar((P + Size)^, (NewSize - Size) * SizeOf(LongInt), $FF);
    Index := P;
    Size := NewSize;
  end;
  (Index + I)^ := Val;
end;

{ --- THelpFile --------------------------------------------------------------- }

constructor THelpFile.Init(S: PStream);
var
  Magic, Size: LongInt;
begin
  inherited Init;
  Stream := S;
  Magic := 0;
  Size := S^.GetSize;
  S^.Seek(0);
  if Size > SizeOf(Magic) then
    S^.Read(Magic, SizeOf(Magic));
  if (Magic = MagicHeader) and (Size >= 12) then
  begin
    S^.Seek(8);
    S^.Read(IndexPos, SizeOf(IndexPos));
    S^.Seek(IndexPos);
    Index := PHelpIndex(S^.Get);
    if Index = nil then
      New(Index, Init);
    Modified := False;
  end
  else
  begin
    IndexPos := 12;
    New(Index, Init);
    Modified := True;
  end;
end;

destructor THelpFile.Done;
var
  Magic, Size: LongInt;
begin
  if Modified and (Stream <> nil) then
  begin
    { the stream must be as long as the index position (the topics were put before it) }
    while Stream^.GetSize < IndexPos do
    begin
      Stream^.Seek(Stream^.GetSize);
      Magic := 0;
      Stream^.Write(Magic, 1);
    end;
    Stream^.Seek(IndexPos);
    Stream^.Put(Index);
    Magic := MagicHeader;
    Size := Stream^.GetSize - 8;
    Stream^.Seek(0);
    Stream^.Write(Magic, SizeOf(Magic));
    Stream^.Write(Size, SizeOf(Size));
    Stream^.Write(IndexPos, SizeOf(IndexPos));
  end;
  if Stream <> nil then
    Dispose(Stream, Done);
  Stream := nil;
  if Index <> nil then
    Dispose(Index, Done);
  Index := nil;
  inherited Done;
end;

function THelpFile.GetTopic(I: Integer): PHelpTopic;
var
  Pos: LongInt;
begin
  Pos := Index^.Position(I);
  if Pos > 0 then
  begin
    Stream^.Seek(Pos);
    Result := PHelpTopic(Stream^.Get);
    if Result = nil then
      Result := InvalidTopic;
  end
  else
    Result := InvalidTopic;
end;

function THelpFile.InvalidTopic: PHelpTopic;
var
  Para: PParagraph;
begin
  New(Result, Init);
  New(Para);
  Para^.Size := Length(InvalidContext);
  GetMem(Para^.Text, Para^.Size + 1);
  Move(InvalidContext[1], Para^.Text^, Para^.Size);
  Para^.Text[Para^.Size] := 0;
  Para^.Wrap := False;
  Para^.Next := nil;
  Result^.AddParagraph(Para);
end;

procedure THelpFile.RecordPositionInIndex(I: Integer);
begin
  Index^.Add(I, IndexPos);
  Modified := True;
end;

procedure THelpFile.PutTopic(Topic: PHelpTopic);
var
  Zero: Byte;
begin
  while Stream^.GetSize < IndexPos do
  begin
    Stream^.Seek(Stream^.GetSize);
    Zero := 0;
    Stream^.Write(Zero, 1);
  end;
  Stream^.Seek(IndexPos);
  Stream^.Put(Topic);
  IndexPos := Stream^.GetPos;
  Modified := True;
end;

{ --- THelpViewer ------------------------------------------------------------- }

constructor THelpViewer.Init(const Bounds: TRect; AHScrollBar, AVScrollBar: PScrollBar; AHelpFile: PHelpFile; Context: Word);
begin
  inherited Init(Bounds, AHScrollBar, AVScrollBar);
  Options := Options or ofSelectable;
  GrowMode := gfGrowHiX or gfGrowHiY;
  HFile := AHelpFile;
  Topic := AHelpFile^.GetTopic(Context);
  Topic^.SetWidth(Size.X);        { the width for the wrapping of the lines }
  SetLimit(Topic^.LongestLineWidth, Topic^.NumLines);
  Selected := 1;
end;

destructor THelpViewer.Done;
begin
  if HFile <> nil then
    Dispose(HFile, Done);
  HFile := nil;
  if Topic <> nil then
    Dispose(Topic, Done);
  Topic := nil;
  inherited Done;
end;

procedure THelpViewer.ChangeBounds(const Bounds: TRect);
begin
  inherited ChangeBounds(Bounds);
  Topic^.SetWidth(Size.X);
  SetLimit(Topic^.LongestLineWidth, Topic^.NumLines);
end;

procedure THelpViewer.Draw;
var
  B: TDrawBuffer;
  I, J, L, KeyCount, KeyRef: Integer;
  Normal, Keyword, SelKeyword, C: TColorAttr;
  KeyPoint: TPoint;
  KeyLength: Byte;
  Line: ShortString;
begin
  Normal := GetColor(1).Lo;
  Keyword := GetColor(2).Lo;
  SelKeyword := GetColor(3).Lo;
  KeyCount := 0;
  KeyPoint.X := 0;
  KeyPoint.Y := 0;
  KeyLength := 0;
  Topic^.SetWidth(Size.X);
  if Topic^.GetNumCrossRefs > 0 then
  begin
    repeat
      Topic^.GetCrossRef(KeyCount, KeyPoint, KeyLength, KeyRef);
      Inc(KeyCount);
    until (KeyCount >= Topic^.GetNumCrossRefs) or (KeyPoint.Y > Delta.Y);
  end;
  B.Init(Size.X);
  for I := 1 to Size.Y do
  begin
    B.MoveChar(0, Ord(' '), Normal, Size.X);
    Line := Topic^.GetLine(I + Delta.Y);
    if TextWidthS(Line) > Delta.X then
      B.MoveStrS(0, Line, Normal, Size.X, Delta.X)
    else
      B.MoveStrS(0, '', Normal);
    while I + Delta.Y = KeyPoint.Y do
    begin
      L := KeyLength;
      if KeyPoint.X < Delta.X then
      begin
        Dec(L, Delta.X - KeyPoint.X);
        KeyPoint.X := Delta.X;
      end;
      if KeyCount = Selected then
        C := SelKeyword
      else
        C := Keyword;
      for J := 0 to L - 1 do
        B.PutAttribute(KeyPoint.X - Delta.X + J, C);
      if KeyCount < Topic^.GetNumCrossRefs then
      begin
        Topic^.GetCrossRef(KeyCount, KeyPoint, KeyLength, KeyRef);
        Inc(KeyCount);
      end
      else
        KeyPoint.Y := 0;
    end;
    WriteLineD(0, I - 1, Size.X, 1, B);
  end;
  B.Done;
end;

function THelpViewer.GetPalette: TPalette;
begin
  Result := MakePalette(CHelpViewer);
end;

procedure THelpViewer.MakeSelectVisible(ASelected: Integer; var KeyPoint: TPoint; var KeyLength: Byte; var KeyRef: Integer);
var
  D: TPoint;
begin
  Topic^.GetCrossRef(ASelected, KeyPoint, KeyLength, KeyRef);
  D := Delta;
  if KeyPoint.X < D.X then
    D.X := KeyPoint.X;
  if KeyPoint.X > D.X + Size.X then
    D.X := KeyPoint.X - Size.X;
  if KeyPoint.Y <= D.Y then
    D.Y := KeyPoint.Y - 1;
  if KeyPoint.Y > D.Y + Size.Y then
    D.Y := KeyPoint.Y - Size.Y;
  if (D.X <> Delta.X) or (D.Y <> Delta.Y) then
    ScrollTo(D.X, D.Y);
end;

procedure THelpViewer.SwitchToTopic(KeyRef: Integer);
begin
  if Topic <> nil then
    Dispose(Topic, Done);
  Topic := HFile^.GetTopic(KeyRef);
  Topic^.SetWidth(Size.X);
  ScrollTo(0, 0);
  SetLimit(Topic^.LongestLineWidth, Topic^.NumLines);
  Selected := 1;
  DrawView;
end;

procedure THelpViewer.HandleEvent(var Event: TEvent);
var
  KeyPoint, Mouse: TPoint;
  KeyLength: Byte;
  KeyRef, KeyCount: Integer;
begin
  inherited HandleEvent(Event);
  case Event.What of
    evKeyDown:
      begin
        case Event.KeyCode of
          kbTab:
            begin
              Inc(Selected);
              if Selected > Topic^.GetNumCrossRefs then
                Selected := 1;
              if Topic^.GetNumCrossRefs <> 0 then
                MakeSelectVisible(Selected - 1, KeyPoint, KeyLength, KeyRef);
            end;
          kbShiftTab:
            begin
              Dec(Selected);
              if Selected = 0 then
                Selected := Topic^.GetNumCrossRefs;
              if Topic^.GetNumCrossRefs <> 0 then
                MakeSelectVisible(Selected - 1, KeyPoint, KeyLength, KeyRef);
            end;
          kbEnter:
            if Selected <= Topic^.GetNumCrossRefs then
            begin
              Topic^.GetCrossRef(Selected - 1, KeyPoint, KeyLength, KeyRef);
              SwitchToTopic(KeyRef);
            end;
          kbEsc:
            begin
              Event.What := evCommand;
              Event.Command := cmClose;
              PutEvent(Event);
            end;
        else
          Exit;
        end;
        DrawView;
        ClearEvent(Event);
      end;
    evMouseDown:
      begin
        Mouse := MakeLocal(Event.Where);
        Inc(Mouse.X, Delta.X);
        Inc(Mouse.Y, Delta.Y);
        KeyCount := 0;
        repeat
          Inc(KeyCount);
          if KeyCount > Topic^.GetNumCrossRefs then
            Exit;
          Topic^.GetCrossRef(KeyCount - 1, KeyPoint, KeyLength, KeyRef);
        until (KeyPoint.Y = Mouse.Y + 1) and (Mouse.X >= KeyPoint.X) and (Mouse.X < KeyPoint.X + KeyLength);
        Selected := KeyCount;
        DrawView;
        SwitchToTopic(KeyRef);
        ClearEvent(Event);
      end;
    evCommand:
      if (Event.Command = cmClose) and ((Owner^.State and sfModal) <> 0) then
      begin
        EndModal(cmClose);
        ClearEvent(Event);
      end;
  end;
end;

{ --- THelpWindow ------------------------------------------------------------- }

constructor THelpWindow.Init(AHelpFile: PHelpFile; Context: Word);
var
  R: TRect;
begin
  R.Assign(0, 0, 50, 18);
  inherited Init(R, HelpWinTitle, wnNoNumber);
  Options := Options or ofCentered;
  R.Grow(-2, -1);
  Viewer := New(PHelpViewer, Init(R, StandardScrollBar(sbHorizontal or sbHandleKeyboard),
    StandardScrollBar(sbVertical or sbHandleKeyboard), AHelpFile, Context));
  Insert(Viewer);
end;

procedure THelpWindow.GotoContext(Context: Word);
begin
  if Viewer <> nil then
    Viewer^.SwitchToTopic(Context);
end;

function THelpWindow.GetPalette: TPalette;
begin
  Result := MakePalette(CHelpWindow);
end;

{ --- stream records ---------------------------------------------------------- }

function BuildHelpTopic(var S: TStream): PObject;
begin
  Result := New(PHelpTopic, Load(S));
end;

procedure StoreHelpTopic(P: PObject; var S: TStream);
begin
  PHelpTopic(P)^.Store(S);
end;

function BuildHelpIndex(var S: TStream): PObject;
begin
  Result := New(PHelpIndex, Load(S));
end;

procedure StoreHelpIndex(P: PObject; var S: TStream);
begin
  PHelpIndex(P)^.Store(S);
end;

initialization
  RHelpTopic.ObjType := 10000;
  RHelpTopic.VmtLink := PtrUInt(TypeOf(THelpTopic));
  RHelpTopic.Load := @BuildHelpTopic;
  RHelpTopic.Store := @StoreHelpTopic;
  RHelpIndex.ObjType := 10001;
  RHelpIndex.VmtLink := PtrUInt(TypeOf(THelpIndex));
  RHelpIndex.Load := @BuildHelpIndex;
  RHelpIndex.Store := @StoreHelpIndex;

end.
