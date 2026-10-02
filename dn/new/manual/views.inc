{ What DN calls differently from tv/ (the interface part of the unit Views). }
const
  MaxViewWidth = 255;

  { palettes (see dialogs.inc) }
  CFrame = #1#1#2#2#3;
  CScrollBar = #4#5#5;
  CScroller = #6#7;
  CListViewer = #26#26#27#28#29;
  CBlueWindow = #8#9#10#11#12#13#14#15;
  CCyanWindow = #16#17#18#19#20#21#22#23;
  CGrayWindow = #24#25#26#27#28#29#30#31;

type
  TPhase = TPhaseType;
  { A row of 16-bit cells (low byte: the character, high byte: the BIOS attribute): the buffer of Turbo Vision
    for Borland Pascal. It is written to the screen by WriteBufW/WriteLineW of TView (tv/DESIGN.md, 11c). }
  PDrawBuffer = ^TDrawBuffer;
  TDrawBuffer = array[0..MaxViewWidth - 1] of Word;

type
  { the title of a window (Borland TV: String[80]) }
  TTitleStr = String[80];
