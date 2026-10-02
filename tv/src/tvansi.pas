{ TvAnsi: cells and attributes turned into the bytes that an ANSI/xterm terminal draws (cursor moves, colors,
  styles). Nothing here writes to a terminal: the bytes are collected in a buffer, the backend (TvUnix) writes them.

  Translated from magiblot/tvision @ b4831e2:
    source/platform/ansiwrit.cpp, include/tvision/internal/ansiwrit.h
    (TermCap, AnsiScreenWriter, the conversion of colors to what the terminal can show).
  Borland disclaimer and MIT notice: tv/COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/DESIGN.md):
    - the capabilities are guessed from the environment (TermCapFromEnv); the original asks ncurses/terminfo for
      the number of colors. The guess can be forced with TV_COLORS (0, 8, 16, 256, direct);
    - the buffer is a growable array of bytes; the numbers are written with IntToStr. }
unit TvAnsi;

{$I tvdefs.inc}

interface

uses
  SysUtils, TvColors;

const
  { quirks of terminals }
  qfBoldIsBright  = $0001;
  qfBlinkIsBright = $0002;
  qfNoItalic      = $0004;
  qfNoUnderline   = $0008;

type
  TTermCapColors = (tcNoColor, tcIndexed8, tcIndexed16, tcIndexed256, tcDirect);

  TTermCap = record
    Colors: TTermCapColors;
    Quirks: Word;
  end;

  { a color as the terminal gets it }
  TTermColorKind = (tkDefault, tkIndexed, tkRgb, tkNoColor);

  TTermColor = record
    Kind: TTermColorKind;
    Value: LongWord;             { the palette index or 0x00RRGGBB }
  end;

  TTermAttr = record
    Fg, Bg: TTermColor;
    Style: Word;
  end;

  TAnsiWriter = object
  private
    Buf: PByte;
    Size, Capacity: Integer;
    Cap: TTermCap;
    CaretX, CaretY: Integer;
    Last: TTermAttr;
    procedure Reserve(Extra: Integer);
    procedure Put(const S: string);
    procedure PutNum(N: Integer);
  public
    procedure Init(const ACap: TTermCap);
    procedure Done;
    { forget what the terminal shows: the next cell moves the cursor and sets the attributes }
    procedure Reset;
    procedure ClearScreen;
    { Text is UTF-8 }
    procedure WriteCell(X, Y: Integer; const Text: string; Attr: TColorAttr; DoubleWidth: Boolean);
    procedure SetCaretPosition(X, Y: Integer);
    { raw bytes (the sequences of the backend) }
    procedure WriteRaw(const S: string);
    function Data: PByte;
    function Length: Integer;
    procedure Clear;
  end;

{ The capabilities from the environment: COLORTERM, TERM (and TV_COLORS to force). }
function TermCapFromEnv: TTermCap;
{ The same from the values (for tests). }
function TermCapFrom(const ColorTerm, Term, Force: string): TTermCap;

{ The color attributes as the terminal gets them (the conversion that WriteCell does). }
procedure ConvertAttr(Attr: TColorAttr; const Cap: TTermCap; out T: TTermAttr);

implementation

function TermCapFrom(const ColorTerm, Term, Force: string): TTermCap;
var
  T: string;
begin
  Result.Colors := tcIndexed16;
  Result.Quirks := 0;
  T := LowerCase(Term);
  if (Force = '0') or (Force = 'none') then
    Result.Colors := tcNoColor
  else if Force = '8' then
    Result.Colors := tcIndexed8
  else if Force = '16' then
    Result.Colors := tcIndexed16
  else if Force = '256' then
    Result.Colors := tcIndexed256
  else if (LowerCase(Force) = 'direct') or (LowerCase(Force) = 'truecolor') then
    Result.Colors := tcDirect
  else if (ColorTerm = 'truecolor') or (ColorTerm = '24bit') then
    Result.Colors := tcDirect
  else if Pos('direct', T) > 0 then
    Result.Colors := tcDirect
  else if Pos('256color', T) > 0 then
    Result.Colors := tcIndexed256
  else if (T = 'dumb') or (T = 'vt100') or (T = 'vt52') then
    Result.Colors := tcNoColor
  else if T = 'linux' then
    Result.Colors := tcIndexed8
  else if (T = 'screen') or (T = 'vt220') or (T = 'ansi') or (T = 'cons25') or (T = 'sun-color') then
    Result.Colors := tcIndexed8;
  if Result.Colors = tcIndexed8 then
  begin
    Result.Quirks := Result.Quirks or qfBoldIsBright;
    if T = 'linux' then
      Result.Quirks := Result.Quirks or qfBlinkIsBright or qfNoItalic or qfNoUnderline;
  end;
end;

function TermCapFromEnv: TTermCap;
begin
  Result := TermCapFrom(GetEnvironmentVariable('COLORTERM'), GetEnvironmentVariable('TERM'),
    GetEnvironmentVariable('TV_COLORS'));
end;

{ --- color conversion ---------------------------------------------------------------------------------------- }

type
  TConverted = record
    Color: TTermColor;
    ExtraStyle: Word;
  end;

function Indexed(Idx: Byte): TTermColor;
begin
  Result.Kind := tkIndexed;
  Result.Value := Idx;
end;

function DefaultColor: TTermColor;
begin
  Result.Kind := tkDefault;
  Result.Value := 0;
end;

function ConvertNoColor(C: TColor; IsFg: Boolean): TConverted;
var
  Bios: TColorBIOS;
begin
  Result.Color.Kind := tkNoColor;
  Result.Color.Value := 0;
  Result.ExtraStyle := 0;
  { the mono palettes are mimicked with styles }
  if ColorIsBIOS(C) then
  begin
    Bios := ColorAsBIOS(C);
    if IsFg then
    begin
      if (Bios and 8) <> 0 then
        Result.ExtraStyle := slBold
      else if Bios = 1 then
        Result.ExtraStyle := slUnderline;
    end
    else if (Bios and 7) = 7 then
      Result.ExtraStyle := slReverse;
  end;
end;

function ConvertIndexed16(C: TColor): TConverted;
var
  Idx: Byte;
begin
  Result.ExtraStyle := 0;
  if ColorIsBIOS(C) then
    Result.Color := Indexed(BIOSToXTerm16(ColorAsBIOS(C)))
  else if ColorIsXTerm(C) then
  begin
    Idx := ColorAsXTerm(C);
    if Idx >= 16 then
      Idx := XTerm256ToXTerm16(Idx);
    Result.Color := Indexed(Idx);
  end
  else if ColorIsRGB(C) then
    Result.Color := Indexed(RGBToXTerm16(ColorAsRGB(C)))
  else
    Result.Color := DefaultColor;
end;

function ConvertIndexed8(C: TColor; IsFg: Boolean; const Cap: TTermCap): TConverted;
begin
  Result := ConvertIndexed16(C);
  if (Result.Color.Kind = tkIndexed) and (Result.Color.Value >= 8) then
  begin
    Dec(Result.Color.Value, 8);
    if IsFg then
    begin
      if (Cap.Quirks and qfBoldIsBright) <> 0 then
        Result.ExtraStyle := Result.ExtraStyle or slBold;
    end
    else if (Cap.Quirks and qfBlinkIsBright) <> 0 then
      Result.ExtraStyle := Result.ExtraStyle or slBlink;
  end;
end;

function ConvertIndexed256(C: TColor): TConverted;
begin
  if ColorIsXTerm(C) then
  begin
    Result.Color := Indexed(ColorAsXTerm(C));
    Result.ExtraStyle := 0;
  end
  else if ColorIsRGB(C) then
  begin
    Result.Color := Indexed(RGBToXTerm256(ColorAsRGB(C)));
    Result.ExtraStyle := 0;
  end
  else
    Result := ConvertIndexed16(C);
end;

function ConvertDirect(C: TColor): TConverted;
begin
  if ColorIsRGB(C) then
  begin
    Result.Color.Kind := tkRgb;
    Result.Color.Value := ColorAsRGB(C) and $FFFFFF;
    Result.ExtraStyle := 0;
  end
  else
    Result := ConvertIndexed256(C);
end;

function ConvertColor(C: TColor; IsFg: Boolean; const Cap: TTermCap): TConverted;
begin
  case Cap.Colors of
    tcNoColor: Result := ConvertNoColor(C, IsFg);
    tcIndexed8: Result := ConvertIndexed8(C, IsFg, Cap);
    tcIndexed16: Result := ConvertIndexed16(C);
    tcIndexed256: Result := ConvertIndexed256(C);
  else
    Result := ConvertDirect(C);
  end;
end;

procedure ConvertAttr(Attr: TColorAttr; const Cap: TTermCap; out T: TTermAttr);
var
  F, B: TConverted;
begin
  T.Style := AttrStyle(Attr);
  F := ConvertColor(AttrFg(Attr), True, Cap);
  B := ConvertColor(AttrBg(Attr), False, Cap);
  T.Fg := F.Color;
  T.Bg := B.Color;
  T.Style := T.Style or F.ExtraStyle or B.ExtraStyle;
  if (Cap.Quirks and qfNoItalic) <> 0 then
    T.Style := T.Style and not slItalic;
  if (Cap.Quirks and qfNoUnderline) <> 0 then
    T.Style := T.Style and not slUnderline;
end;

{ --- the writer ---------------------------------------------------------------------------------------------- }

procedure TAnsiWriter.Init(const ACap: TTermCap);
begin
  Cap := ACap;
  Buf := nil;
  Size := 0;
  Capacity := 0;
  CaretX := -1;
  CaretY := -1;
  FillChar(Last, SizeOf(Last), 0);
end;

procedure TAnsiWriter.Done;
begin
  if Buf <> nil then
    FreeMem(Buf);
  Buf := nil;
  Size := 0;
  Capacity := 0;
end;

procedure TAnsiWriter.Reserve(Extra: Integer);
begin
  if Size + Extra > Capacity then
  begin
    Capacity := Size + Extra + Capacity + 4096;
    ReallocMem(Buf, Capacity);
  end;
end;

procedure TAnsiWriter.Put(const S: string);
begin
  if S = '' then
    Exit;
  Reserve(System.Length(S));
  Move(S[1], Buf[Size], System.Length(S));
  Inc(Size, System.Length(S));
end;

procedure TAnsiWriter.PutNum(N: Integer);
begin
  Put(IntToStr(N));
end;

procedure TAnsiWriter.Reset;
begin
  Put(#27'[0m');
  CaretX := -1;
  CaretY := -1;
  FillChar(Last, SizeOf(Last), 0);
end;

procedure TAnsiWriter.ClearScreen;
begin
  Put(#27'[0m'#27'[2J');
  FillChar(Last, SizeOf(Last), 0);
end;

function TAnsiWriter.Data: PByte;
begin
  Result := Buf;
end;

function TAnsiWriter.Length: Integer;
begin
  Result := Size;
end;

procedure TAnsiWriter.Clear;
begin
  Size := 0;
end;

procedure TAnsiWriter.WriteRaw(const S: string);
begin
  Put(S);
end;

function SameColor(const A, B: TTermColor): Boolean;
begin
  Result := (A.Kind = B.Kind) and (A.Value = B.Value);
end;

{ an SGR sequence is closed at the ';' that ends a parameter and a new one is opened: "ESC [ 38;5;9;" becomes "ESC [ 38;5;9 m ESC [" }
procedure SplitSgrOpen(var S: string);
begin
  if (S <> '') and (S[System.Length(S)] = ';') then
  begin
    S[System.Length(S)] := 'm';
    S := S + #27'[';
  end;
end;

function ColorParams(const C: TTermColor; IsFg: Boolean; var S: string): Boolean;
var
  R, G, B: Integer;
begin
  Result := True;
  case C.Kind of
    tkDefault:
      if IsFg then S := S + '39;' else S := S + '49;';
    tkIndexed:
      if C.Value >= 16 then
      begin
        { 256 colors and RGB get a separate SGR sequence: some terminals have trouble with them otherwise }
        SplitSgrOpen(S);
        if IsFg then S := S + '38;5;' else S := S + '48;5;';
        S := S + IntToStr(C.Value) + ';';
        SplitSgrOpen(S);
      end
      else if C.Value >= 8 then
      begin
        if IsFg then
          S := S + IntToStr(C.Value - 8 + 90) + ';'
        else
          S := S + IntToStr(C.Value - 8 + 100) + ';';
      end
      else if IsFg then
        S := S + IntToStr(C.Value + 30) + ';'
      else
        S := S + IntToStr(C.Value + 40) + ';';
    tkRgb:
      begin
        R := (C.Value shr 16) and $FF;
        G := (C.Value shr 8) and $FF;
        B := C.Value and $FF;
        SplitSgrOpen(S);
        if IsFg then S := S + '38;2;' else S := S + '48;2;';
        S := S + IntToStr(R) + ';' + IntToStr(G) + ';' + IntToStr(B) + ';';
        SplitSgrOpen(S);
      end;
  else
    Result := False;
  end;
end;

procedure WriteFlag(var S: string; const A, L: TTermAttr; Mask: Word; const On_, Off_: string);
begin
  if (A.Style and Mask) <> (L.Style and Mask) then
  begin
    if (A.Style and Mask) <> 0 then
      S := S + On_ + ';'
    else
      S := S + Off_ + ';';
  end;
end;

{ the sequence that changes the attributes from Last to A ('' if they are the same) }
function AttributeSequence(const A, L: TTermAttr): string;
begin
  Result := #27'[';
  WriteFlag(Result, A, L, slBold, '1', '22');
  WriteFlag(Result, A, L, slItalic, '3', '23');
  WriteFlag(Result, A, L, slUnderline, '4', '24');
  WriteFlag(Result, A, L, slBlink, '5', '25');
  WriteFlag(Result, A, L, slReverse, '7', '27');
  WriteFlag(Result, A, L, slStrike, '9', '29');
  if not SameColor(A.Fg, L.Fg) then
    ColorParams(A.Fg, True, Result);
  if not SameColor(A.Bg, L.Bg) then
    ColorParams(A.Bg, False, Result);
  if Result[System.Length(Result)] = ';' then
    Result[System.Length(Result)] := 'm'
  else
    { what is left is a dangling "ESC [" (nothing changed, or the last color closed its own sequence): cut it }
    Delete(Result, System.Length(Result) - 1, 2);
end;

procedure TAnsiWriter.WriteCell(X, Y: Integer; const Text: string; Attr: TColorAttr; DoubleWidth: Boolean);
var
  A: TTermAttr;
  Seq: string;
begin
  if Y <> CaretY then
  begin
    Put(#27'[' + IntToStr(Y + 1) + ';' + IntToStr(X + 1) + 'H');
  end
  else if X <> CaretX then
    Put(#27'[' + IntToStr(X + 1) + 'G');
  ConvertAttr(Attr, Cap, A);
  Seq := AttributeSequence(A, Last);
  Last := A;
  Put(Seq);
  Put(Text);
  CaretX := X + 1;
  if DoubleWidth then
    Inc(CaretX);
  CaretY := Y;
end;

procedure TAnsiWriter.SetCaretPosition(X, Y: Integer);
begin
  Put(#27'[' + IntToStr(Y + 1) + ';' + IntToStr(X + 1) + 'H');
  CaretX := X;
  CaretY := Y;
end;

end.
