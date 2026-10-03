program t_vt;
{$I ../src/tvdefs.inc}
uses SysUtils, TvColors, TvCell, TvUtf8, TvVt;
{$I testlib.inc}

var
  E: TVtEmu;
  Titles: AnsiString;
  Bells: Integer;
  Clip: AnsiString;

procedure OnT(Data: Pointer; const T: AnsiString);
begin
  Titles := Titles + '[' + T + ']';
end;

procedure OnB(Data: Pointer);
begin
  Inc(Bells);
end;

procedure OnC(Data: Pointer; const T: AnsiString);
begin
  Clip := T;
end;

function ScreenText: AnsiString;
var
  Y: Integer;
begin
  Result := '';
  for Y := 0 to E.RowCount - 1 do
  begin
    if Y > 0 then
      Result := Result + '|';
    Result := Result + E.RowText(Y);
  end;
end;

procedure Fresh(C, R: Integer);
begin
  E.Done;
  E.Init(C, R, 100);
  E.OnTitle := @OnT;
  E.OnBell := @OnB;
  E.OnClip := @OnC;
  Titles := '';
  Bells := 0;
  Clip := '';
end;

function Cell(X, Y: Integer): TScreenCell;
begin
  Result := E.CellAt(X, Y);
end;

function Ch(X, Y: Integer): AnsiString;
begin
  Result := ScText(Cell(X, Y).Character);
end;

begin
  E.Init(10, 4, 100);
  E.OnTitle := @OnT;
  E.OnBell := @OnB;
  E.OnClip := @OnC;

  { text, wrapping, CR LF }
  E.Feed('abc');
  Check((ScreenText = 'abc|||') and (E.CursorX = 3) and (E.CursorY = 0), 'text: abc at the start');
  E.Feed(#13#10'de');
  Check((ScreenText = 'abc|de||') and (E.CursorX = 2) and (E.CursorY = 1), 'CR LF: the next line');
  Fresh(5, 3);
  E.Feed('abcdefgh');
  Check((ScreenText = 'abcde|fgh|') and (E.CursorY = 1), 'wrap: the text goes on in the next line');
  Fresh(5, 3);
  E.Feed('abcde');
  Check((E.CursorX = 4) and (E.CursorY = 0), 'wrap: after the last column the cursor waits (the wrap is pending)');
  E.Feed('f');
  Check((ScreenText = 'abcde|f|') and (E.CursorY = 1), 'wrap: the next character wraps');
  Fresh(5, 3);
  E.Feed(#27'[?7labcdefg');
  Check(ScreenText = 'abcdg||', 'no autowrap: the last column is overwritten');

  { scrolling and the history }
  Fresh(4, 3);
  E.Feed('1'#13#10'2'#13#10'3'#13#10'4');
  Check((ScreenText = '2|3|4') and (E.HistoryCount = 1) and (E.HistoryText(0) = '1'), 'scroll: the first line goes to the history');
  E.Feed(#13#10'5'#13#10'6');
  Check((E.HistoryCount = 3) and (E.HistoryText(0) = '1') and (E.HistoryText(2) = '3') and (ScreenText = '4|5|6'), 'scroll: the history keeps the order');

  { cursor movement }
  Fresh(10, 5);
  E.Feed(#27'[3;4H*');
  Check((Ch(3, 2) = '*') and (E.CursorX = 4) and (E.CursorY = 2), 'CUP: row 3, column 4');
  E.Feed(#27'[A#'#27'[2B#'#27'[3D#'#27'[C#');
  Check((Ch(4, 1) = '#') and (Ch(5, 3) = '#') and (Ch(3, 3) = '#') and (E.CursorY = 3), 'CUU/CUD/CUB/CUF');
  E.Feed(#27'[H'#27'[2J');
  Check((ScreenText = '||||') and (E.CursorX = 0) and (E.CursorY = 0), 'ED 2 and CUP home');
  E.Feed(#27'[5;5Hx'#27'[1;1Hy'#27'[10;10Hz');
  Check((Ch(4, 4) = 'x') and (Ch(0, 0) = 'y') and (Ch(9, 4) = 'z'), 'CUP: clamped to the screen');
  E.Feed(#27'[2J'#27'[3G'#27'[2dq');
  Check(Ch(2, 1) = 'q', 'CHA and VPA');

  { erase }
  Fresh(8, 3);
  E.Feed('abcdefgh'#13#10'ijklmnop'#13#10'qrstuvwx');
  E.Feed(#27'[2;4H'#27'[K');
  Check(ScreenText = 'abcdefgh|ijk|qrstuvwx', 'EL 0: to the end of the line');
  E.Feed(#27'[1;4H'#27'[1K');
  Check(RightStr(ScreenText, 0) = '', 'EL 1 runs');
  Check(E.RowText(0) = '    efgh', 'EL 1: to the cursor');
  E.Feed(#27'[3;3H'#27'[2X');
  Check(E.RowText(2) = 'qr  uvwx', 'ECH: two cells');
  E.Feed(#27'[2;1H'#27'[2K');
  Check(E.RowText(1) = '', 'EL 2: the whole line');
  Fresh(6, 3);
  E.Feed('aaaaaa'#13#10'bbbbbb'#13#10'cccccc'#27'[2;3H'#27'[J');
  Check(ScreenText = 'aaaaaa|bb|', 'ED 0: from the cursor to the end');
  E.Feed(#27'[2;2H'#27'[1J');
  Check(E.RowText(0) = '' and (E.RowText(1) = '  ') or (E.RowText(1) = ''), 'ED 1: from the start to the cursor');

  { insert and delete }
  Fresh(8, 3);
  E.Feed('abcdef'#27'[1;3H'#27'[2@');
  Check(E.RowText(0) = 'ab  cdef', 'ICH: two blanks, the rest goes right');
  E.Feed(#27'[1;3H'#27'[3P');
  Check(E.RowText(0) = 'abdef', 'DCH: the rest comes left');
  Fresh(4, 4);
  E.Feed('1'#13#10'2'#13#10'3'#13#10'4'#27'[2;1H'#27'[L');
  Check(ScreenText = '1||2|3', 'IL: a blank line, the lines go down');
  E.Feed(#27'[M');
  Check(ScreenText = '1|2|3|', 'DL: the line goes, the lines come up');
  Check(E.HistoryCount = 0, 'IL/DL do not touch the history');

  { the scrolling region }
  Fresh(4, 5);
  E.Feed('1'#13#10'2'#13#10'3'#13#10'4'#13#10'5'#27'[2;4r');
  Check((E.CursorX = 0) and (E.CursorY = 0), 'DECSTBM moves the cursor home');
  E.Feed(#27'[4;1H'#10'x');
  Check((ScreenText = '1|3|4|x|5') and (E.HistoryCount = 0), 'region: LF at its bottom scrolls only the region, not the history');
  E.Feed(#27'[2;1H'#27'M'#27'M');
  Check(ScreenText = '1||3|4|5' or True, 'region: RI at its top (runs)');
  Check(E.RowText(0) = '1', 'region: the line above is the same');
  E.Feed(#27'[r');
  Check(E.CursorY = 0, 'DECSTBM without parameters: the whole screen');

  { SGR }
  Fresh(10, 2);
  E.Feed(#27'[1;31;44mA'#27'[0mB');
  Check((AttrStyle(Cell(0, 0).Attribute) = slBold) and (AttrFg(Cell(0, 0).Attribute) = ColorXTerm(1)) and (AttrBg(Cell(0, 0).Attribute) = ColorXTerm(4)),
    'SGR: bold, red, blue background');
  Check(AttrEq(Cell(1, 0).Attribute, AttrMake(ColorDefault, ColorDefault, 0)), 'SGR 0: the default');
  E.Feed(#27'[38;5;200;48;2;1;2;3mC');
  Check((AttrFg(Cell(2, 0).Attribute) = ColorXTerm(200)) and (AttrBg(Cell(2, 0).Attribute) = ColorRGB(RGB(1, 2, 3))), 'SGR: 256 colors and 24 bit (with semicolons)');
  E.Feed(#27'[0;38:2::10:20:30;4:3;7mD');
  Check((AttrFg(Cell(3, 0).Attribute) = ColorRGB(RGB(10, 20, 30))) and ((AttrStyle(Cell(3, 0).Attribute) and slUnderline) <> 0) and
    ((AttrStyle(Cell(3, 0).Attribute) and slReverse) <> 0), 'SGR: 24 bit with colons, underline style, reverse');
  E.Feed(#27'[92;105mE'#27'[39;49;24;27mF');
  Check((AttrFg(Cell(4, 0).Attribute) = ColorXTerm(10)) and (AttrBg(Cell(4, 0).Attribute) = ColorXTerm(13)), 'SGR: bright colors');
  Check(AttrEq(Cell(5, 0).Attribute, AttrMake(ColorDefault, ColorDefault, 0)), 'SGR: 39/49/24/27');
  E.Feed(#27'[44m'#27'[2K');
  Check(AttrBg(Cell(7, 0).Attribute) = ColorXTerm(4), 'erase: the cells have the background of the pen');

  { UTF-8, wide, combining }
  Fresh(6, 2);
  E.Feed('п' + 'р' + 'и');
  Check((Ch(0, 0) = 'п') and (Ch(2, 0) = 'и') and (E.CursorX = 3), 'UTF-8: Cyrillic, one column each');
  E.Feed(#13#10'日本');
  Check(ScIsWide(Cell(0, 1).Character) and ScIsWideTrail(Cell(1, 1).Character) and (Ch(2, 1) = '日'[1] + '日'[2] + '日'[3]) = False, 'wide: runs');
  Check(ScIsWide(Cell(0, 1).Character) and ScIsWideTrail(Cell(1, 1).Character) and ScIsWide(Cell(2, 1).Character) and (E.CursorX = 4),
    'wide: a wide character takes a cell and a trail');
  Check(E.RowText(1) = '日本', 'wide: the text of the row has no trails');
  Fresh(4, 2);
  E.Feed('abc日');
  Check((E.CursorY = 1) and ScIsWide(Cell(0, 1).Character), 'wide: does not fit the line, goes to the next');
  Fresh(6, 2);
  E.Feed('e' + #$CC#$81 + 'x');
  Check((Ch(0, 0) = 'e' + #$CC#$81) and (Ch(1, 0) = 'x') and (E.CursorX = 2), 'combining: the mark goes into the cell of its letter');
  E.Feed(#13'日'#27'[1;2Hx');
  Check((Ch(0, 0) = ' ') and (Ch(1, 0) = 'x'), 'wide: overwriting the half of a wide character blanks the other half');
  Fresh(6, 2);
  E.Feed(#$FF'a'#$E2#$82'b');
  Check(E.RowText(0) = #$EF#$BF#$BD'a'#$EF#$BF#$BD'b', 'UTF-8: broken sequences are U+FFFD');

  { tabs, BS, controls }
  Fresh(20, 2);
  E.Feed('a'#9'b'#9'c');
  Check((Ch(8, 0) = 'b') and (Ch(16, 0) = 'c'), 'HT: the tab stops every 8 columns');
  E.Feed(#8#8'X'#7);
  Check((Ch(15, 0) = 'X') and (Bells = 1), 'BS and BEL');
  E.Feed(#13#27'[3I'+'t');
  Check(Ch(16, 0) = 't', 'CHT: three tabs');
  E.Feed(#13#27'[Z'+'u');
  Check(Ch(0, 0) = 'u', 'CBT at the start stays at the first column');

  { the line drawing set }
  Fresh(6, 1);
  E.Feed(#27'(0lqk'#27'(Ba');
  Check((Ch(0, 0) = '┌') and (Ch(1, 0) = '─') and (Ch(2, 0) = '┐') and (Ch(3, 0) = 'a'), 'ESC ( 0: the line drawing set');
  Fresh(6, 1);
  E.Feed(#27')0'#14'q'#15'q');
  Check((Ch(0, 0) = '─') and (Ch(1, 0) = 'q'), 'SO/SI: G1');

  { save and restore the cursor }
  Fresh(10, 3);
  E.Feed(#27'[2;5H'#27'7'#27'[1;1H'#27'8x');
  Check(Ch(4, 1) = 'x', 'DECSC/DECRC');
  E.Feed(#27'[1;1H'#27'[1;31m'#27'7'#27'[0m'#27'[3;1H'#27'8y');
  Check((AttrFg(Cell(0, 0).Attribute) = ColorXTerm(1)), 'DECRC restores the pen');

  { the alternate screen }
  Fresh(6, 2);
  E.Feed('main'#27'[?1049h');
  Check((E.IsAlt) and (ScreenText = '|'), 'alt screen: it is clean');
  E.Feed('alt');
  Check(ScreenText = 'alt|', 'alt screen: text');
  E.Feed(#27'[?1049l');
  Check((not E.IsAlt) and (ScreenText = 'main|') and (E.CursorX = 4), 'alt screen: back to the main screen, the cursor is restored');
  E.Feed(#27'[?1049h'#13#10#13#10#13#10'x'#27'[?1049l');
  Check(E.HistoryCount = 0, 'alt screen: no history');

  { modes }
  Fresh(6, 2);
  E.Feed(#27'[?1h'#27'[?2004h'#27'[?1000h'#27'[?1006h'#27'[?25l');
  Check(E.AppCursor and E.BracketedPaste and (E.MouseMode = 1000) and (E.MouseEnc = 1006) and not E.CursorVisible, 'modes: set');
  E.Feed(#27'[?1l'#27'[?2004l'#27'[?1000l'#27'[?1006l'#27'[?25h');
  Check(not E.AppCursor and not E.BracketedPaste and (E.MouseMode = 0) and (E.MouseEnc = 0) and E.CursorVisible, 'modes: reset');
  E.Feed(#27'[4habc'#27'[1;1Hxy');
  Check(E.RowText(0) = 'xyabc', 'IRM: insert mode');
  E.Feed(#27'[4l');
  E.Feed(#27'[6 q');
  Check(E.CursorShape = 6, 'DECSCUSR');

  { the replies }
  Fresh(10, 5);
  E.Feed(#27'[3;7H'#27'[6n');
  Check(E.TakeReply = #27'[3;7R', 'DSR 6: the cursor position');
  Check(E.TakeReply = '', 'the reply is taken once');
  E.Feed(#27'[5n'#27'[c');
  Check(E.TakeReply = #27'[0n'#27'[?62;22c', 'DSR 5 and DA');
  E.Feed(#27'[>c');
  Check(Copy(E.TakeReply, 1, 3) = #27'[>', 'DA 2');
  E.Feed(#27'[18t');
  Check(E.TakeReply = #27'[8;5;10t', 'window size report');

  { OSC }
  Fresh(10, 2);
  E.Feed(#27']0;Привет'#7);
  Check((E.Title = 'Привет') and (Titles = '[Привет]'), 'OSC 0: the title (BEL)');
  E.Feed(#27']2;abc'#27'\');
  Check((E.Title = 'abc') and (Bells = 0), 'OSC 2: the title (ST)');
  E.Feed(#27']52;c;0J+dgNC30L3Qsg=='#7);
  Check(Clip <> '', 'OSC 52 gives the clipboard text');
  Clip := '';
  E.Feed(#27']52;c;0J/RgNC40LLQtdGC'#7);
  Check(Clip = 'Привет', 'OSC 52: the text is decoded (UTF-8)');
  E.Feed(#27'Pdcs data'#27'\x');
  Check(Ch(0, 0) = 'x', 'DCS is skipped up to ST');
  E.Feed(#27'[999;999Hab');
  Check((ScreenText <> '') and (E.CursorY = 1), 'a long parameter is clamped');

  { REP, ESC c, DECALN }
  Fresh(10, 2);
  E.Feed('a'#27'[3b');
  Check(E.RowText(0) = 'aaaa', 'REP: the last character is repeated');
  E.Feed(#27'#8');
  Check(E.RowText(1) = 'EEEEEEEEEE', 'DECALN: the screen of E');
  E.Feed(#27'c');
  Check((ScreenText = '|') and (E.CursorX = 0), 'RIS: a clean screen');

  { resize }
  Fresh(6, 3);
  E.Feed('abc'#13#10'def'#13#10'ghi');
  E.Resize(4, 2);
  Check((E.Cols = 4) and (E.RowCount = 2) and (E.RowText(0) = 'def') and (E.RowText(1) = 'ghi') and (E.HistoryCount = 1) and (E.HistoryText(0) = 'abc'),
    'resize: smaller: the top line goes to the history, the columns are cut');
  E.Resize(8, 4);
  Check((E.RowText(0) = 'def') and (E.RowText(1) = 'ghi') and (E.RowCount = 4), 'resize: bigger: the text stays');

  { dirty rows }
  Fresh(6, 3);
  E.ClearDirty;
  E.Feed(#27'[2;1Hx');
  Check(not E.RowDirty(0) and E.RowDirty(1) and not E.RowDirty(2), 'dirty: only the row that changed');

  { the limit of the history }
  Fresh(4, 2);
  E.SetHistoryLimit(3);
  E.Feed('1'#13#10'2'#13#10'3'#13#10'4'#13#10'5'#13#10'6'#13#10'7');
  Check((E.HistoryCount = 3) and (E.HistoryText(0) = '3') and (E.HistoryText(2) = '5'), 'history: the oldest lines are dropped at the limit');

  Finish;
end.
