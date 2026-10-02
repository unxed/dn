{ TvTextView: text devices: TTextDevice, TTerminal (a scrolling window that shows the text written
  to it), AssignDevice (a Pascal text file that writes into a text device).

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/textview.h (class declarations)
    source/tvision/textview.cpp, ttprvlns.cpp
  Borland disclaimer and MIT notice: tv/COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/DESIGN.md):
    - TTextDevice is not a streambuf: DoSputn is its interface; Write, WriteLn and PutChar
      are the shortcuts (instead of the C++ streams); AssignDevice (as in Borland Pascal
      TextView) redirects the Pascal Write/WriteLn;
    - the text is UTF-8 (or the bytes of the code page), as everywhere in tv/. }
unit TvTextView;

{$I tvdefs.inc}

interface

uses
  TvGeom, TvColors, TvCell, TvKeys, TvEvents, TvUtf8, TvText, TvDrawBuf, TvObjs, TvUtil,
  TvViews, TvWindow;

type
  PTextDevice = ^TTextDevice;
  TTextDevice = object(TScroller)
    constructor Init(const Bounds: TRect; AHScrollBar, AVScrollBar: PScrollBar);
    { puts Count bytes of S into the device; returns the number of bytes taken }
    function DoSputn(S: PByte; Count: Integer): Integer; virtual;
    procedure PutStr(const S: ShortString);
    procedure PutLine(const S: ShortString);
    procedure PutChar(C: Char);
  end;

  { Palette: 1 = text }
  PTerminal = ^TTerminal;
  TTerminal = object(TTextDevice)
    constructor Init(const Bounds: TRect; AHScrollBar, AVScrollBar: PScrollBar;
      ABufSize: Word);
    destructor Done; virtual;
    function DoSputn(S: PByte; Count: Integer): Integer; virtual;
    procedure BufInc(var Val: Word);
    function CanInsert(Amount: Word): Boolean;
    procedure Draw; virtual;
    function NextLine(Pos: Word): Word;
    function PrevLines(Pos, Lines: Word): Word;
    function QueEmpty: Boolean;
  protected
    BufSize: Word;
    Buffer: PByte;
    QueFront, QueBack: Word;
    procedure BufDec(var Val: Word);
  end;

{ After AssignDevice(T, Device), Rewrite(T) and Write(T, ...) put the text into Device;
  Close(T) does not dispose the device. Reading gives the end of the file at once. }
procedure AssignDevice(var T: Text; Device: PTextDevice);

implementation

{ --- TTextDevice ------------------------------------------------------------- }

constructor TTextDevice.Init(const Bounds: TRect; AHScrollBar, AVScrollBar: PScrollBar);
begin
  inherited Init(Bounds, AHScrollBar, AVScrollBar);
end;

function TTextDevice.DoSputn(S: PByte; Count: Integer): Integer;
begin
  Result := 0;       { abstract: descendants take the text }
end;

procedure TTextDevice.PutStr(const S: ShortString);
begin
  if Length(S) > 0 then
    DoSputn(@S[1], Length(S));
end;

procedure TTextDevice.PutLine(const S: ShortString);
var
  N: Byte;
begin
  PutStr(S);
  N := 10;
  DoSputn(@N, 1);
end;

procedure TTextDevice.PutChar(C: Char);
begin
  DoSputn(@C, 1);
end;

{ --- TTerminal --------------------------------------------------------------- }

constructor TTerminal.Init(const Bounds: TRect; AHScrollBar, AVScrollBar: PScrollBar;
  ABufSize: Word);
begin
  inherited Init(Bounds, AHScrollBar, AVScrollBar);
  QueFront := 0;
  QueBack := 0;
  GrowMode := gfGrowHiX + gfGrowHiY;
  if ABufSize > 32000 then
    ABufSize := 32000;
  if ABufSize < 2 then
    ABufSize := 2;
  BufSize := ABufSize;
  GetMem(Buffer, BufSize);
  SetLimit(0, 1);
  SetCursor(0, 0);
  ShowCursor;
end;

destructor TTerminal.Done;
begin
  FreeMem(Buffer);
  Buffer := nil;
  inherited Done;
end;

procedure TTerminal.BufDec(var Val: Word);
begin
  if Val = 0 then
    Val := BufSize - 1
  else
    Dec(Val);
end;

procedure TTerminal.BufInc(var Val: Word);
begin
  Inc(Val);
  if Val >= BufSize then
    Val := 0;
end;

function TTerminal.CanInsert(Amount: Word): Boolean;
var
  T: LongInt;
begin
  if QueFront < QueBack then
    T := LongInt(QueFront) + Amount
  else
    T := LongInt(QueFront) - BufSize + Amount;
  Result := QueBack > T;
end;

{ Pre: Count >= 1. Pos points to the last checked character afterwards. }
function FindLfBackwards(Buffer: PByte; var Pos: Word; Count: Word): Boolean;
begin
  Inc(Pos);
  repeat
    Dec(Pos);
    if Buffer[Pos] = 10 then
      Exit(True);
    Dec(Count);
  until Count = 0;
  Result := False;
end;

function TTerminal.PrevLines(Pos, Lines: Word): Word;
var
  Count: Word;
begin
  if (Lines > 0) and (Pos <> QueBack) then
  begin
    repeat
      if Pos = QueBack then
        Exit(QueBack);
      BufDec(Pos);
      if Pos >= QueBack then
        Count := Pos - QueBack + 1
      else
        Count := Pos + 1;
      if FindLfBackwards(Buffer, Pos, Count) then
        Dec(Lines);
    until Lines = 0;
    BufInc(Pos);
  end;
  Result := Pos;
end;

function TTerminal.NextLine(Pos: Word): Word;
begin
  while (Pos <> QueFront) and (Buffer[Pos] <> 10) do
    BufInc(Pos);
  if Pos <> QueFront then
    BufInc(Pos);
  Result := Pos;
end;

function TTerminal.QueEmpty: Boolean;
begin
  Result := QueBack = QueFront;
end;

procedure TTerminal.Draw;
var
  B: TDrawBuffer;
  S: array[0..255] of Byte;
  SLen: Integer;
  X, Y, CharLen, CharWidth, Cpy, Fst, Snd: Integer;
  BegLine, EndLine, LinePos: Word;
  BottomLine: Integer;
  Color: TColorAttr;
begin
  Color := GetColor(1).Lo;
  SetCursor(-1, -1);
  BottomLine := Size.Y + Delta.Y;
  if Limit.Y > BottomLine then
  begin
    EndLine := PrevLines(QueFront, Limit.Y - BottomLine);
    BufDec(EndLine);
  end
  else
    EndLine := QueFront;

  B.Init(Size.X);
  if Limit.Y > Size.Y then
    Y := Size.Y - 1
  else
  begin
    B.MoveChar(0, Ord(' '), Color, Size.X);
    WriteLineD(0, Limit.Y, Size.X, Size.Y - Limit.Y, B);
    Y := Limit.Y - 1;
  end;

  while Y >= 0 do
  begin
    X := 0;
    BegLine := PrevLines(EndLine, 1);
    LinePos := BegLine;
    while LinePos <> EndLine do
    begin
      if EndLine >= LinePos then
      begin
        Cpy := EndLine - LinePos;
        if Cpy > SizeOf(S) then
          Cpy := SizeOf(S);
        Move(Buffer[LinePos], S[0], Cpy);
        SLen := Cpy;
      end
      else
      begin
        Fst := BufSize - LinePos;
        if Fst > SizeOf(S) then
          Fst := SizeOf(S);
        Snd := EndLine;
        if Snd > SizeOf(S) - Fst then
          Snd := SizeOf(S) - Fst;
        Move(Buffer[LinePos], S[0], Fst);
        Move(Buffer[0], S[Fst], Snd);
        SLen := Fst + Snd;
      end;
      { a character cut by the end of the chunk is left for the next one }
      if SLen = SizeOf(S) then
      begin
        SLen := 0;
        while SLen < SizeOf(S) - (MaxCharSize - 1) do
        begin
          if not TextNext(@S[SLen], SizeOf(S) - SLen, CharLen, CharWidth) then
            Break;
          Inc(SLen, CharLen);
        end;
      end;
      if LinePos >= BufSize - SLen then
        LinePos := SLen - (BufSize - LinePos)
      else
        Inc(LinePos, SLen);
      Inc(X, B.MoveStr(X, @S[0], SLen, Color));
    end;
    if Size.X - X > 0 then
      B.MoveChar(X, Ord(' '), Color, Size.X - X);
    WriteBufD(0, Y, Size.X, 1, B);
    { the cursor is drawn when this is the last line }
    if EndLine = QueFront then
      SetCursor(X, Y);
    EndLine := BegLine;
    BufDec(EndLine);
    Dec(Y);
  end;
  B.Done;
end;

function TTerminal.DoSputn(S: PByte; Count: Integer): Integer;
var
  ScreenLines: Word;
  I: Integer;
begin
  ScreenLines := Limit.Y;
  if Count > BufSize - 1 then
  begin
    Inc(S, Count - (BufSize - 1));
    Count := BufSize - 1;
  end;
  for I := 0 to Count - 1 do
    if S[I] = 10 then
      Inc(ScreenLines);
  while not CanInsert(Count) do
  begin
    QueBack := NextLine(QueBack);
    if ScreenLines > 1 then
      Dec(ScreenLines);
  end;
  if QueFront + Count >= BufSize then
  begin
    I := BufSize - QueFront;
    Move(S^, Buffer[QueFront], I);
    Move(S[I], Buffer^, Count - I);
    QueFront := Count - I;
  end
  else
  begin
    Move(S^, Buffer[QueFront], Count);
    Inc(QueFront, Count);
  end;
  { DrawLock: avoid redundant calls to DrawView }
  Inc(DrawLock);
  SetLimit(Limit.X, ScreenLines);
  ScrollTo(0, ScreenLines + 1);
  Dec(DrawLock);
  DrawView;
  Result := Count;
end;

{ --- AssignDevice ------------------------------------------------------------ }

function DevClose(var F: TextRec): Integer;
begin
  Result := 0;
end;

function DevRead(var F: TextRec): Integer;
begin
  F.BufEnd := 0;
  F.BufPos := 0;
  Result := 0;
end;

function DevWrite(var F: TextRec): Integer;
var
  Device: PTextDevice;
  I, N: Integer;
  Buf: PByte;
begin
  Device := PTextDevice(PPointer(@F.UserData)^);
  Buf := PByte(F.BufPtr);
  N := 0;
  for I := 0 to F.BufPos - 1 do    { carriage returns are dropped: the text has line feeds only }
    if Buf[I] <> 13 then
    begin
      Buf[N] := Buf[I];
      Inc(N);
    end;
  if (N > 0) and (Device <> nil) then
    Device^.DoSputn(Buf, N);
  F.BufPos := 0;
  Result := 0;
end;

function DevOpen(var F: TextRec): Integer;
begin
  if F.Mode = fmOutput then
  begin
    F.InOutFunc := @DevWrite;
    F.FlushFunc := @DevWrite;
  end
  else
  begin
    F.InOutFunc := @DevRead;
    F.FlushFunc := nil;
    F.Mode := fmInput;
  end;
  F.CloseFunc := @DevClose;
  Result := 0;
end;

procedure AssignDevice(var T: Text; Device: PTextDevice);
begin
  FillChar(T, SizeOf(TextRec), 0);
  TextRec(T).Mode := fmClosed;
  TextRec(T).BufSize := SizeOf(TextRec(T).Buffer);
  TextRec(T).BufPtr := @TextRec(T).Buffer;
  TextRec(T).OpenFunc := @DevOpen;
  TextRec(T).LineEnd := #10;       { the terminal wants line feeds only (not zeroed by FillChar) }
  PPointer(@TextRec(T).UserData)^ := Device;
end;

end.
