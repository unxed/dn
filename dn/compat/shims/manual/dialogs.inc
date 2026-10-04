{ The palettes of the standard views as strings of indexes (Borland TV names; the values are those of tv/:
  the palette of a view maps its colors to the colors of its owner). }
const
  CGrayDialog = #32#33#34#35#36#37#38#39#40#41#42#43#44#45#46#47#48#49#50#51#52#53#54#55#56#57#58#59#60#61#62#63;
  CBlueDialog = #64#65#66#67#68#69#70#71#72#73#74#75#76#77#78#79#80#81#82#83#84#85#86#87#88#89#90#91#92#93#94#95;
  CCyanDialog = #96#97#98#99#100#101#102#103#104#105#106#107#108#109#110#111#112#113#114#115#116#117#118#119#120#121#122#123#124#125#126#127;
  CDialog = CGrayDialog;
  CStaticText = #6;
  CLabel = #7#8#9#9;
  CButton = #10#11#12#13#14#14#14#15;
  CCluster = #16#17#18#18#31;
  CInputLine = #19#19#20#21;
  CHistory = #22#23;
  CHistoryWindow = #19#19#21#24#23#19#20;
  CHistoryViewer = #6#6#7#6#6;
  CInfoPane = #30;

type




  { an input line for long text (DN: strings of more than 255 characters). TODO: it is an ordinary input
    line for now. }
  TLongInputLine = class;

  TLongInputLine = class(TInputLine)
  end;
