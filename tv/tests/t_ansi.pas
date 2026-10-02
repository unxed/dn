program t_ansi;
{$I ../src/tvdefs.inc}
uses SysUtils, TvColors, TvAnsi;
{$I testlib.inc}

const
  E = #27;

var
  W: TAnsiWriter;
  Cap: TTermCap;

function Out: string;
begin
  SetLength(Result, W.Length);
  if W.Length > 0 then
    Move(W.Data^, Result[1], W.Length);
  W.Clear;
end;

function Cell(const S: string; Fg, Bg: TColor; Style: Word; X, Y: Integer): string;
begin
  W.WriteCell(X, Y, S, AttrMake(Fg, Bg, Style), False);
  Result := Out;
end;

begin
  { the capabilities from the environment }
  Check(TermCapFrom('truecolor', 'xterm', '').Colors = tcDirect, 'COLORTERM=truecolor: direct colors');
  Check(TermCapFrom('24bit', 'screen', '').Colors = tcDirect, 'COLORTERM=24bit: direct colors');
  Check(TermCapFrom('', 'xterm-256color', '').Colors = tcIndexed256, 'xterm-256color: 256 colors');
  Check(TermCapFrom('', 'xterm', '').Colors = tcIndexed16, 'xterm: 16 colors');
  Check(TermCapFrom('', 'linux', '').Colors = tcIndexed8, 'linux: 8 colors');
  Check(TermCapFrom('', 'linux', '').Quirks = (qfBoldIsBright or qfBlinkIsBright or qfNoItalic or qfNoUnderline),
    'linux: the console quirks');
  Check(TermCapFrom('', 'dumb', '').Colors = tcNoColor, 'dumb: no color');
  Check(TermCapFrom('truecolor', 'xterm', '16').Colors = tcIndexed16, 'TV_COLORS=16 wins');
  Check(TermCapFrom('', 'xterm', 'direct').Colors = tcDirect, 'TV_COLORS=direct');

  { 16 colors: white on blue, then the same, then another place }
  Cap := TermCapFrom('', 'xterm', '');
  W.Init(Cap);
  Check(Cell('A', ColorBIOS($F), ColorBIOS($1), 0, 0, 0) = E + '[1;1H' + E + '[97;44mA', 'first cell: move, colors, text');
  Check(Cell('B', ColorBIOS($F), ColorBIOS($1), 0, 1, 0) = 'B', 'the next cell with the same attributes: the text only');
  Check(Cell('C', ColorBIOS($F), ColorBIOS($1), 0, 5, 0) = E + '[6GC', 'a jump on the row: the column');
  Check(Cell('D', ColorBIOS($F), ColorBIOS($1), 0, 0, 1) = E + '[2;1HD', 'another row: row and column');
  Check(Cell('E', ColorBIOS($4), ColorBIOS($1), 0, 1, 1) = E + '[31mE', 'only the foreground changes');
  Check(Cell('F', ColorBIOS($4), ColorBIOS($1), slBold, 2, 1) = E + '[1mF', 'bold on');
  Check(Cell('G', ColorBIOS($4), ColorBIOS($1), 0, 3, 1) = E + '[22mG', 'bold off');
  Check(Cell('H', ColorDefault, ColorDefault, 0, 4, 1) = E + '[39;49mH', 'default colors');
  W.Reset;
  Check(Out = E + '[0m', 'reset');
  Check(Cell('I', ColorDefault, ColorDefault, 0, 0, 0) = E + '[1;1HI', 'after reset the move is repeated, the default colors are known');

  { a wide character takes two columns: the next one does not need a move }
  W.WriteCell(0, 0, 'W', AttrMake(ColorDefault, ColorDefault), True);
  W.WriteCell(2, 0, 'x', AttrMake(ColorDefault, ColorDefault), False);
  Check(Pos(E + '[', Out) > 0, 'a wide cell moves the cursor by two');
  W.Reset;
  W.Clear;
  W.WriteCell(0, 0, 'W', AttrMake(ColorDefault, ColorDefault), True);
  W.Clear;
  W.WriteCell(2, 0, 'x', AttrMake(ColorDefault, ColorDefault), False);
  Check(Out = 'x', '... so the cell after it (column 2) is only the text');

  { 256 and direct colors }
  W.Done;
  W.Init(TermCapFrom('', 'xterm-256color', ''));
  Check(Cell('A', ColorRGB(RGB(255, 0, 0)), ColorDefault, 0, 0, 0) = E + '[1;1H' + E + '[38;5;' + IntToStr(RGBToXTerm256(RGB(255, 0, 0))) + 'mA',
    '256 colors: an RGB color is the nearest of the palette (a sequence of its own)');
  W.Done;
  W.Init(TermCapFrom('truecolor', 'xterm', ''));
  Check(Cell('A', ColorRGB(RGB(255, 0, 0)), ColorRGB(RGB(0, 0, 128)), 0, 0, 0) =
    E + '[1;1H' + E + '[38;2;255;0;0m' + E + '[48;2;0;0;128mA', 'direct colors: 38;2 and 48;2');
  Check(Cell('B', ColorRGB(RGB(255, 0, 0)), ColorRGB(RGB(0, 0, 128)), slItalic, 1, 0) = E + '[3mB', 'italic');

  { 8 colors (the Linux console): the bright colors are bold and blink; no italic, no underline }
  W.Done;
  W.Init(TermCapFrom('', 'linux', ''));
  Check(Cell('A', ColorBIOS($F), ColorBIOS($9), 0, 0, 0) = E + '[1;1H' + E + '[1;5;37;44mA', 'linux: bright white on bright blue is bold and blink');
  Check(Cell('B', ColorBIOS($F), ColorBIOS($9), slItalic or slUnderline, 1, 0) = 'B', 'linux: italic and underline are dropped');

  { no colors: styles instead }
  W.Done;
  W.Init(TermCapFrom('', 'dumb', ''));
  Check(Cell('A', ColorBIOS($F), ColorBIOS($0), 0, 0, 0) = E + '[1;1H' + E + '[1mA', 'no colors: bright is bold');
  Check(Cell('B', ColorBIOS($7), ColorBIOS($0), 0, 1, 0) = E + '[22mB', '... and the normal is not');
  W.SetCaretPosition(9, 3);
  Check(Out = E + '[4;10H', 'the caret');
  W.Done;
  Finish;
end.
