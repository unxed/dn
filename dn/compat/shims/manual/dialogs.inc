{ The palettes of the standard views as strings of indexes (Borland TV names; the values are those of tv/:
  the palette of a view maps its colors to the colors of its owner). }
const
  { the dialog palettes: the 32 colors of the dialog of each kind, in a row from the first of the kind }
  CGrayDialog = #$20#$21#$22#$23#$24#$25#$26#$27#$28#$29#$2A#$2B#$2C#$2D#$2E#$2F#$30#$31#$32#$33#$34#$35#$36#$37#$38#$39#$3A#$3B#$3C#$3D#$3E#$3F;
  CBlueDialog = #$40#$41#$42#$43#$44#$45#$46#$47#$48#$49#$4A#$4B#$4C#$4D#$4E#$4F#$50#$51#$52#$53#$54#$55#$56#$57#$58#$59#$5A#$5B#$5C#$5D#$5E#$5F;
  CCyanDialog = #$60#$61#$62#$63#$64#$65#$66#$67#$68#$69#$6A#$6B#$6C#$6D#$6E#$6F#$70#$71#$72#$73#$74#$75#$76#$77#$78#$79#$7A#$7B#$7C#$7D#$7E#$7F;
  CDialog = CGrayDialog;
  { the views of a dialog: the entries of the palette of the dialog that each one uses }
  CHistoryViewer = #$06#$06#$07#$06#$06;
  CStaticText = #$06;
  CInfoPane = #$1E;
  CLabel = #$07#$08#$09#$09;
  CHistory = #$16#$17;
  CInputLine = #$13#$13#$14#$15;
  CCluster = #$10#$11#$12#$12#$1F;
  CHistoryWindow = #$13#$13#$15#$18#$17#$13#$14;
  CButton = #$0A#$0B#$0C#$0D#$0E#$0E#$0E#$0F;

type




  { an input line for long text (DN: strings of more than 255 characters). TODO: it is an ordinary input
    line for now. }
  TLongInputLine = class;

  TLongInputLine = class(TInputLine)
  protected
    function StreamableName: ShortString; override;
  public
    class function Build: TStreamable; static;
  end;
