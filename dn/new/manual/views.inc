{ What DN calls differently from tv/ (the interface part of the unit Views). }
type
  { DN units see these through Views (in the original they came with the Views of DN); same meaning as in Defines }
  AInt = SmallInt;
  AWord = Word;

const
  MaxViewWidth = 255;

var
  { the smallest size of a window (the width and the height) }
  MinWinSize: TPoint = (X: 16; Y: 6);

const

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
  TTitleStr = ShortString;

{ The views that are updated from time to time (DN): RegisterToBackground adds a view, its Update is called by
  RunBackground (the idle loop of the program, TProgram.Idle of DNApp) when the view's UpdTicks milliseconds have
  passed since the last call. A view that is destroyed leaves the list by itself. }
procedure RegisterToBackground(P: PView);
procedure UnregisterFromBackground(P: PView);
procedure RunBackground;

type
  { A scroll bar of the panels of DN. TODO: DN hides the bar by an option of the setup (Startup); here it is an
    ordinary scroll bar. }
  PMyScrollBar = ^TMyScrollBar;
  TMyScrollBar = object(TScrollBar)
    procedure Draw; virtual;
  end;

  { the video buffer of DN: 80x25 cells of 16 bits }
  PVideoBuf = ^TVideoBuf;
  TVideoBuf = array[0..3999] of Word;
