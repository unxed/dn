program t_dosbk;
{ Tests of the DOS backend (TvDos); they run only under DOS (DOSBox-X in CI). }
{$I ../src/tvdefs.inc}
uses Go32, Dos, TvGeom, TvColors, TvCell, TvCodePg, TvEvents, TvKeys, TvScreen, TvViews,
  TvWindow, TvMenus, TvSys, TvMouse, TvApp, TvDos;
{$I ../tests/testlib.inc}

function R(A, B, C, D: Integer): TRect;
begin
  Result.Assign(A, B, C, D);
end;

{ the first mouse state differs from "nothing": that is an event; take all of them }
procedure Drain;
var
  E: TEvent;
  N: Integer;
begin
  N := 0;
  repeat
    PollEvent(0, E);
    Inc(N);
  until (E.What = evNothing) or (N > 100);
end;

var
  App: PApplication;
  W: PWindow;
  Ev: TEvent;
  Regs: Registers;
  St: TMouseState;
  T0: Int64;
  Cp: Integer;
  Row, Want: ShortString;
  Attr: TColorAttr;
  Cell: TScreenCell;
begin
  DosInit(866);
  Check((ScreenWidth = 80) and (ScreenHeight = 25), 'the screen is the text mode: 80x25');
  Check(CpCurrent = 866, 'the code page is the one asked for');
  Check(DosMousePresent, 'a mouse driver');

  { cells to video words }
  ScInitChar(Cell.Character, Ord('A'));
  Cell.Attribute := AttrFromBIOS($1E);
  Check(DosCellToVga(Cell) = $1E41, 'an ASCII cell');
  ScInitChar(Cell.Character, $C9);
  Check(DosCellToVga(Cell) = $1EC9, 'a code page byte goes as it is');
  ScInitText(Cell.Character, @'Ж'[1], 2, False);
  Check(DosCellToVga(Cell) = $1E86, 'UTF-8 text goes through the code page (CP866: Zhe is $86)');
  ScInitText(Cell.Character, @'€'[1], 3, False);
  Check(DosCellToVga(Cell) = $1E3F, 'a character the page does not have is "?"');
  ScInitWideTrail(Cell.Character);
  Check(DosCellToVga(Cell) = $1E20, 'the trail of a wide character is a blank');

  { the application on the real screen }
  New(App, Init);
  Check(DosReadRow(24, 0, 11) = ' Alt-X Exit ', 'status line in video memory');
  Check(DosReadAttr(1, 24) = $74, 'its hot key color');
  Check(DosReadAttr(0, 0) = $70, 'menu bar color');
  Check(DosReadRow(1, 0, 3) = #$B0#$B0#$B0#$B0, 'background pattern: the CP437/866 light shade');
  Check(DosReadAttr(0, 1) = $71, 'background color');
  New(W, Init(R(2, 2, 30, 10), 'Привет', 1));
  App^.InsertWindow(W);
  Check(DosReadRow(3, 2, 4) = #$C9#$CD'[', 'frame characters are code page bytes');
  Row := DosReadRow(3, 2, 29);
  Check(Pos(#$8F#$E0#$A8#$A2#$A5#$E2, Row) > 0, 'the Russian title is shown in CP866');
  Check(DosReadAttr(2, 3) = $1F, 'active frame color');

  { keyboard: keys put in the BIOS buffer come out as events }
  Drain;
  Check(DosKeyBufferEmpty, 'the keyboard buffer is empty');
  DosStuffKey($3B00);
  PollEvent(0, Ev);
  Check((Ev.What = evKeyDown) and (Ev.KeyCode = kbF1), 'F1');
  DosStuffKey($1E61);
  PollEvent(0, Ev);
  Check((Ev.What = evKeyDown) and (Ev.KeyCode = $1E61) and (Ev.TextLength = 1) and (Ev.Text[0] = 'a'), 'a letter has text');
  DosStuffKey($198F);
  PollEvent(0, Ev);
  Check((Ev.What = evKeyDown) and (Ev.TextLength = 2) and (Ev.Text[0] = #$D0) and (Ev.Text[1] = #$9F),
    'a CP866 letter has its UTF-8 as text');
  DosStuffKey($2D00);
  PollEvent(0, Ev);
  Check((Ev.What = evKeyDown) and (Ev.KeyCode = kbAltX), 'Alt-X');
  PollEvent(0, Ev);
  Check(Ev.What = evNothing, 'no key: no event');
  DosKeyToEvent($4800 or $E0, 0, Ev);
  Check(Ev.KeyCode = kbUp, 'an enhanced key ($E0) loses its character');

  { mouse }
  Regs.ax := 4;
  Regs.cx := 80;
  Regs.dx := 40;
  Intr($33, Regs);
  Check(DosMouseState(St), 'the mouse state');
  Check((St.Where.X = 10) and (St.Where.Y = 5) and (St.Buttons = 0), 'the position is in cells');

  { the clock and waiting }
  Drain;
  T0 := ClockMs;
  DosYields := 0;
  PollEvent(150, Ev);
  Check((ClockMs - T0 >= 100) and (ClockMs - T0 < 1500), 'waiting for an event takes the time asked for');
  Check(DosYields > 0, 'and gives the time slice away');

  { the caret }
  SetCaretPosition(5, 7);
  SetCaretSize(100);
  Regs.ah := 3;
  Regs.bh := 0;
  Intr($10, Regs);
  Check((Regs.dh = 7) and (Regs.dl = 5), 'caret position');
  Check((Regs.ch = 0) and (Regs.cl > 7), 'a full-height caret');
  SetCaretSize(0);
  Regs.ah := 3;
  Regs.bh := 0;
  Intr($10, Regs);
  Check((Regs.ch and $20) <> 0, 'a hidden caret');

  { the whole loop: Alt-X typed on the keyboard quits the program }
  DosStuffKey($2D00);
  App^.Run;
  Check(App^.EndState = cmQuit, 'Run: Alt-X from the keyboard quits');

  DosDumpScreen('SCR.DAT');
  Dispose(App, Done);
  DosDone;
  Finish;
end.
