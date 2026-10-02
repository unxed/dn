program t_help;
{$I ../src/tvdefs.inc}
uses SysUtils, TvGeom, TvColors, TvCell, TvCodePg, TvEvents, TvKeys, TvViews, TvObjs, TvUtil, TvMem, TvApp,
  TvWindow, TvHelp;
{$I testlib.inc}

function R(A, B, C, D: Integer): TRect;
begin
  Result.Assign(A, B, C, D);
end;

function Para(const S: String; Wrap: Boolean): PParagraph;
begin
  New(Result);
  Result^.Size := Length(S);
  GetMem(Result^.Text, Length(S) + 1);
  Move(S[1], Result^.Text^, Length(S));
  Result^.Text[Length(S)] := 0;
  Result^.Wrap := Wrap;
  Result^.Next := nil;
end;

function Ref(Topic: LongInt; Offset: LongInt; Len: Byte): TCrossRef;
begin
  Result.Ref := Topic;
  Result.Offset := Offset;
  Result.Length := Len;
end;

var
  App: PApplication;
  T, T2: PHelpTopic;
  HF: PHelpFile;
  Win: PHelpWindow;
  V: PHelpViewer;
  L: TPoint;
  Len: Byte;
  Rf: Integer;
  Ev: TEvent;
  Used0: PtrUInt;
const
  FName = 't_help.tmp';
begin
  Used0 := GetFPCHeapStatus.CurrHeapUsed;
  MemInit(80, 25);
  RegisterType(RHelpTopic);
  RegisterType(RHelpIndex);

  { a topic: a line that is not wrapped, with a cross reference }
  New(T, Init);
  T^.AddParagraph(Para('Hello world'#10, False));
  T^.AddCrossRef(Ref(2, 7, 5));
  T^.SetWidth(40);
  Check(T^.NumLines = 1, 'one line');
  Check(T^.GetLine(1) = 'Hello world', 'the line, without the end of line');
  T^.GetCrossRef(0, L, Len, Rf);
  Check((L.X = 6) and (L.Y = 1) and (Len = 5) and (Rf = 2), 'a cross reference: the place on the screen and the target');

  { wrapping }
  New(T2, Init);
  T2^.AddParagraph(Para('aaa bbb ccc ddd eee', True));
  T2^.SetWidth(8);
  Check(T2^.NumLines = 3, 'wrapped to 8 columns: three lines');
  Check((T2^.GetLine(1) = 'aaa bbb') and (T2^.GetLine(2) = 'ccc ddd') and (T2^.GetLine(3) = 'eee'), 'the words are not cut');
  T2^.SetWidth(30);
  Check((T2^.NumLines = 1) and (T2^.GetLine(1) = 'aaa bbb ccc ddd eee'), 'a wider topic: one line');
  Check(T2^.LongestLineWidth = 19, 'the longest line');
  T2^.AddParagraph(Para(' not wrapped      '#10'second line', False));
  Check(T2^.NumLines = 3, 'a paragraph that is not wrapped goes by its line ends');
  Check((T2^.GetLine(2) = ' not wrapped') and (T2^.GetLine(3) = 'second line'), 'the blanks at the end of a line are dropped');
  Check(T2^.GetLine(1) = 'aaa bbb ccc ddd eee', 'a line before the last one asked: again from the start');

  { the help file: put, close, open, get }
  if FileExists(FName) then
    DeleteFile(FName);
  New(HF, Init(New(PBufStream, Init(FName, stCreate, 1024))));
  HF^.RecordPositionInIndex(0);
  HF^.PutTopic(T);
  HF^.RecordPositionInIndex(5);
  HF^.PutTopic(T2);
  Dispose(HF, Done);
  New(HF, Init(New(PBufStream, Init(FName, stOpenRead, 1024))));
  Check(HF^.Index^.Position(5) > 0, 'the index is read');
  Check(HF^.Index^.Position(3) = -1, 'a topic that is not in the file has no position');
  Dispose(T, Done);
  T := HF^.GetTopic(0);
  T^.SetWidth(40);
  Check((T^.NumLines = 1) and (T^.GetLine(1) = 'Hello world'), 'the topic is read');
  T^.GetCrossRef(0, L, Len, Rf);
  Check((L.X = 6) and (Len = 5) and (Rf = 2), 'the cross reference is read');
  Dispose(T, Done);
  T := HF^.GetTopic(7);
  T^.SetWidth(40);
  Check(Pos('No help available', T^.GetLine(2)) > 0, 'a topic that is not in the file: the standard text');
  Dispose(T, Done);

  { the viewer in a window }
  New(App, Init);
  New(Win, Init(HF, 5));
  App^.InsertWindow(Win);
  V := PHelpViewer(Win^.Current);
  Check(V^.HFile = HF, 'the viewer has the file');
  Check(Win^.Title^ = 'Help', 'the title of the window');
  Check(V^.Topic^.GetNumCrossRefs = 0, 'the topic 5 has no references');
  Check(Pos('aaa bbb', MemText(4, 0, 79)) > 0, 'the text is drawn');
  V^.SwitchToTopic(0);
  Check(Pos('Hello world', MemText(4, 0, 79)) > 0, 'a switch to another topic draws it');
  Check(V^.Topic^.GetNumCrossRefs = 1, 'the cross reference of the topic');
  Check(MemAttr(24, 4) <> MemAttr(17, 4), 'the keyword has its own color');
  FillChar(Ev, SizeOf(Ev), 0);
  MakeKeyEvent(Ev, kbEnter, 0);
  V^.HandleEvent(Ev);
  Check(Ev.What = evNothing, 'Enter on a cross reference is taken');
  Check(V^.Topic^.GetNumCrossRefs = 0, 'Enter goes to the topic 2: it is not in the file, the standard text has no references');
  Dispose(App, Done);
  if FileExists(FName) then
    DeleteFile(FName);
  Dispose(T2, Done);
  MemDone;
  Check(GetFPCHeapStatus.CurrHeapUsed = Used0, 'no memory is left behind');
  Finish;
end.
