{ dnscreen: the screen of DN over tv/. DN keeps its screen as an array of 16-bit cells (character + BIOS attribute) and a
  cursor given by the lines of the cell; tv/ has cells with UTF-8 text and a caret size in percent. Here is the glue between
  them: ReadScreenCells makes the copy of the screen of tv/, WriteScreenCells puts cells of the copy back, the cursor
  routines convert the shape. (It was a part of the layer of Virtual Pascal, SysTv*; split out of osdep, which is the system
  layer only.) Our own code (MIT, see LICENSE). }
unit dnscreen;

{$mode objfpc}
{$H-}

interface

uses
  osdep;

{ --- the screen (a copy of the screen of tv/ in 16-bit cells) ---------------------- }

{ The size of the screen; the result is the mode of DN: 3 (80x25 and the like) or $0103 (more lines, small
  font). Size may be nil. }
function GetScreenMode(Size: PSysPoint; Flag: Boolean): Word;
function SetScreenSize(Cols, Rows: Word): Boolean;
{ The screen as an array of 16-bit cells; it is filled from the screen of tv/ at every call. }
function ReadScreenCells: Pointer;
{ Writes Size cells from the position Pos (the number of the cell) of that array to the screen of tv/. }
procedure WriteScreenCells(Pos, Size: LongInt);
procedure ClearScreenCells;
{ After the first draw of the application: the build with the code page inside on DOS and Windows writes the 16-bit copy back to the screen (the cells of the
  copy are the text of DN as bytes of the page); on Unix and in the UTF-8 build it does nothing: CellText turns even the code-page build into UTF-8 for the terminal,
  and the one-byte copy would replace such cells with '?'. }
procedure SyncScreenCopyAfterDraw;
procedure GetCursorType(var Y1, Y2: Integer; var Visible: Boolean);
procedure SetCursorType(Y1, Y2: Integer; Visible: Boolean);
procedure MoveCursorTo(X, Y: Word);
procedure GetCursorXY(var X, Y: Word);

{ A desktop notification that a long operation is done (the far2l terminal shows it when the window is not the active one; elsewhere nothing happens). DN_NOTIFY=0 switches it off. }
procedure NotifyUser(const Text: String);

implementation

uses
  SysUtils, TvSys, TvCell, TvColors, TvScreen, TvUtf8, TvCodePg{$IF DEFINED(UNIX) OR DEFINED(WINDOWS)}, TvUnix{$ENDIF};

{ --- the screen ---------------------------------------------------------------- }

const
  FontHeight = 16;                 { the lines of a character cell; the caret size of tv/ is in percent }

var
  CellCopy: array of Word;

{ TvText stores high code-page bytes as UTF-8 in the cell (DrawOneImpl). The 16-bit
  copy needs the OEM byte: take it from a one-byte cell, else decode the UTF-8 and
  map through the current page (else '?'). Without this, WriteScreenCells after
  ReadScreenCells replaces panel names like Größe with '?'. }
function CellToBiosChar(const Ch: TScreenCharacter): Byte;
var
  S: ShortString;
  CP: LongWord;
  Used: Integer;
  B: Byte;
begin
  if ScIsWideTrail(Ch) then
    Exit(Ord(' '));
  if ScLength(Ch) = 1 then
    Exit(Ch.Text[0]);
  S := ScText(Ch);
  if (Length(S) > 0) and Utf8Decode(@S[1], Length(S), CP, Used) and (Used = Length(S)) then
  begin
    B := CpFromUnicode(CP);
    if B <> 0 then
      Exit(B);
  end;
  Result := Ord('?');
end;

function GetScreenMode(Size: PSysPoint; Flag: Boolean): Word;
begin
  if Size <> nil then
  begin
    Size^.X := ScreenWidth;
    Size^.Y := ScreenHeight;
  end;
  if ScreenHeight > 25 then
    Result := $0103
  else
    Result := 3;
end;

function SetScreenSize(Cols, Rows: Word): Boolean;
begin
  Result := (ScreenWidth = Cols) and (ScreenHeight = Rows);
end;

function ReadScreenCells: Pointer;
var
  I, N: Integer;
  C: PScreenCell;
begin
  N := ScreenWidth * ScreenHeight;
  if Length(CellCopy) <> N then
    SetLength(CellCopy, N);
  C := ScreenBuffer;
  for I := 0 to N - 1 do
  begin
    if C <> nil then
      CellCopy[I] := CellToBiosChar(C^.Character) or (Word(AttrAsBIOSByte(C^.Attribute)) shl 8)
    else
      CellCopy[I] := $0720;
    if C <> nil then
      Inc(C);
  end;
  if N = 0 then
    Exit(nil);
  Result := @CellCopy[0];
end;

procedure WriteScreenCells(Pos, Size: LongInt);
var
  Row: array of TScreenCell;
  X, Y, N, I: Integer;
begin
  if (ScreenWidth <= 0) or (Length(CellCopy) = 0) then
    Exit;
  SetLength(Row, ScreenWidth);
  while (Size > 0) and (Pos < Length(CellCopy)) do
  begin
    Y := Pos div ScreenWidth;
    X := Pos mod ScreenWidth;
    N := ScreenWidth - X;
    if N > Size then
      N := Size;
    for I := 0 to N - 1 do
      Row[I] := CellFromBIOS(CellCopy[Pos + I]);
    if ScreenBuffer <> nil then
      Move(Row[0], (ScreenBuffer + Y * ScreenWidth + X)^, N * SizeOf(TScreenCell));
    ScreenWrite(X, Y, @Row[0], N);
    Inc(Pos, N);
    Dec(Size, N);
  end;
{$IF DEFINED(UNIX) OR DEFINED(WINDOWS)}
  UnixFlush;                 { DN writes the screen and goes on working (a long loop): the terminal gets it now }
{$ENDIF}
end;

procedure SyncScreenCopyAfterDraw;
begin
{$IF NOT DEFINED(DNUTF8) AND NOT DEFINED(UNIX)}
  WriteScreenCells(0, ScreenWidth * ScreenHeight);
{$ENDIF}
end;

procedure ClearScreenCells;
var
  I: Integer;
begin
  SetLength(CellCopy, ScreenWidth * ScreenHeight);
  for I := 0 to High(CellCopy) do
    CellCopy[I] := $0720;
  WriteScreenCells(0, Length(CellCopy));
end;

procedure GetCursorType(var Y1, Y2: Integer; var Visible: Boolean);
var
  H: Integer;
begin
  Visible := CaretSize > 0;
  H := (CaretSize * FontHeight + 99) div 100;
  if H < 1 then
    H := 1;
  Y2 := FontHeight - 1;
  Y1 := FontHeight - H;
end;

procedure SetCursorType(Y1, Y2: Integer; Visible: Boolean);
begin
  if not Visible then
    SetCaretSize(0)
  else if Y2 >= Y1 then
    SetCaretSize((Y2 - Y1 + 1) * 100 div FontHeight)
  else
    SetCaretSize(CursorLines);
end;

procedure MoveCursorTo(X, Y: Word);
begin
  SetCaretPosition(X, Y);
end;

procedure GetCursorXY(var X, Y: Word);
begin
  X := CaretX;
  Y := CaretY;
end;

procedure NotifyUser(const Text: String);
begin
  if GetEnvironmentVariable('DN_NOTIFY') = '0' then
    Exit;
  TvSys.Notify('DN', Text);
end;

end.
