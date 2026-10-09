{ What DN calls differently from tv/ (the interface part of the unit Views). }
type
  TCommandSet = TvViews.TCommandSet;
  TPalette = TvViews.TPalette;

  { DN units see these through Views (in the original they came with the Views of DN); same meaning as in Defines }
  AInt = SmallInt;
  AWord = Word;

const
  MaxViewWidth = 255;
  { DN: the window can be maximized over the desktop (cmMaxi). TODO: the flag is only a name here, tv/ does not
    maximize (the command cmMaxi is not handled by the windows) }
  wfMaxi = $10;

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
  TPhase = TView.PhaseType;
  { A row of cells of tv/ (as TDrawBuffer of tv/, but an array: DN addresses the cells by number): the buffer of Turbo Vision for Borland Pascal
    made of the cells of tv/, so that a cell holds any text (UTF-8, wide characters). The procedures Move* of Drivers fill it (they use the text
    functions of tv/, TvText); it is written to the screen by WriteBufC/WriteLineC of TView. A buffer of 16-bit words (low byte: the
    character, high byte: the BIOS attribute) goes with WriteBufW/WriteLineW. }
  PDrawBuffer = ^TDrawBuffer;
  TDrawBuffer = array[0..MaxViewWidth - 1] of TScreenCell;

var
  { The scroll bar characters of dn.ini (5 bytes of the page: first, last, bar, thumb, empty bar); '' keeps those of tv/. Set by the loader of dn.ini. }
  ScrollCharsV: String[5] = '';
  ScrollCharsH: String[5] = '';

type
  { the title of a window (Borland TV: String[80]) }
  TTitleStr = ShortString;

{ The views that are updated from time to time (DN): RegisterToBackground adds a view, its Update is called by
  RunBackground (the idle loop of the program, TProgram.Idle of mainapp) when the view's UpdTicks milliseconds have
  passed since the last call. A view that is destroyed leaves the list by itself. }
procedure RegisterToBackground(P: TView);
procedure UnregisterFromBackground(P: TView);
procedure RunBackground;

type
  { A scroll bar of the panels of DN. TODO: DN hides the bar by an option of the setup (Startup); here it is an
    ordinary scroll bar. }
  TMyScrollBar = class;
  PMyScrollBar = TMyScrollBar;
  TMyScrollBar = class(TScrollBar)
    procedure Draw; override;
  end;

  { the video buffer of DN: 80x25 cells of 16 bits }
  PVideoBuf = ^TVideoBuf;
  TVideoBuf = array[0..3999] of Word;

var
  { DN: the data of the dialogs only of the tagged controls (sfTagged); TODO: tv/ TGroup.GetData does not honour it yet }
  TaggedDataCount: LongInt = 0;
  TaggedDataOnly: Boolean = False;

{ Message with a long integer in the event (DN; Message takes a pointer). }
function MessageL(Receiver: TView; What, Command: Word; InfoLng: LongInt): Pointer;

{ The next free number of a window, 1..9 (0 if all are used); the number is free again when the window is destroyed. }
function GetNum: Integer;

{ Updates the periodic views now: those whose time has come (All = False) or all of them. }
procedure UpdateAll(All: Boolean);
