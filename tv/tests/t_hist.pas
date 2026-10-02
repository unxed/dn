program t_hist;
{$I ../src/tvdefs.inc}
uses TvGeom, TvCell, TvCodePg, TvEvents, TvKeys, TvViews, TvObjs, TvUtil, TvMem, TvApp,
  TvDialog, TvWindow, TvList, TvInput, TvHist;
{$I testlib.inc}

function R(A, B, C, D: Integer): TRect;
begin
  Result.Assign(A, B, C, D);
end;

var
  App: PApplication;
  Dlg: PDialog;
  L: PInputLine;
  H: PHistory;
  Used0: PtrUInt;
  E: TEvent;
  I: Integer;

begin
  CpSelect(866);
  DoneHistory;
  Used0 := GetFPCHeapStatus.CurrHeapUsed;

  { the list }
  Check(HistoryCount(1) = 0, 'an empty history');
  HistoryAdd(1, 'one');
  HistoryAdd(1, 'two');
  HistoryAdd(2, 'other');
  HistoryAdd(1, 'three');
  HistoryAdd(1, '');
  Check(HistoryCount(1) = 3, 'three strings of the id 1 (an empty one is ignored)');
  Check((HistoryStr(1, 0) = 'one') and (HistoryStr(1, 2) = 'three'), 'the oldest string is the first');
  Check(HistoryStr(1, 3) = '', 'no string after the last one');
  Check((HistoryCount(2) = 1) and (HistoryStr(2, 0) = 'other'), 'the ids are separate');
  HistoryAdd(1, 'one');
  Check((HistoryCount(1) = 3) and (HistoryStr(1, 0) = 'two') and (HistoryStr(1, 2) = 'one'),
    'a repeated string moves to the end');
  ClearHistory;
  Check((HistoryCount(1) = 0) and (HistoryCount(2) = 0), 'ClearHistory');
  HistorySize := 40;
  for I := 1 to 6 do
    HistoryAdd(3, 'abcde' + Chr(Ord('0') + I));
  Check((HistoryCount(3) = 4) and (HistoryStr(3, 0) = 'abcde3') and (HistoryStr(3, 3) = 'abcde6'),
    'old strings are dropped when the block is full');
  HistorySize := 1024;
  ClearHistory;

  { THistory }
  MemInit(80, 25);
  New(App, Init);
  New(Dlg, Init(R(10, 5, 60, 14), 'History'));
  New(L, Init(R(2, 2, 22, 3), 20));
  Dlg^.Insert(L);
  New(H, Init(R(22, 2, 25, 3), L, 7));
  Dlg^.Insert(H);
  L^.Select;
  App^.InsertWindow(Dlg);

  Check((H^.Options and ofPostProcess) <> 0, 'a history view is processed after the others');
  Check(MemText(8, 32, 34) = #$E2#$96#$90#$E2#$86#$93#$E2#$96#$8C, 'the arrow is shown');
  HistoryAdd(7, 'one');
  HistoryAdd(7, 'two');
  HistoryAdd(7, 'three');
  L^.Data^ := 'abc';

  { Down opens the list, Down moves, Enter takes the string }
  MemKey(kbDown);
  MemKey(kbEnter);
  MakeKeyEvent(E, kbDown, 0);
  H^.HandleEvent(E);
  Check(E.What = evNothing, 'the event is handled');
  Check(HistoryCount(7) = 4, 'the text of the line is recorded');
  Check(L^.Data^ = 'three', 'the chosen string goes to the line');
  Check((L^.SelStart = 0) and (L^.SelEnd = 5), 'and is selected');

  { Esc leaves the line as is }
  L^.Data^ := 'xyz';
  MemKey(kbEsc);
  MakeKeyEvent(E, kbDown, 0);
  H^.HandleEvent(E);
  Check(L^.Data^ = 'xyz', 'Esc: the line is not changed');
  Check((HistoryCount(7) = 5) and (HistoryStr(7, 4) = 'xyz'), 'but the text is recorded');

  { a click on the arrow }
  MemMouse(evMouseUp, 33, 8);
  MemKey(kbEsc);
  ClearEvent(E);
  E.What := evMouseDown;
  E.Where.X := 22 + 11;
  E.Where.Y := 8;
  E.Buttons := mbLeftButton;
  H^.HandleEvent(E);
  Check(E.What = evNothing, 'a click on the arrow opens the list');

  { the broadcast of a dialog records the history }
  ClearHistory;
  L^.Data^ := 'rec';
  ClearEvent(E);
  E.What := evBroadcast;
  E.Command := cmRecordHistory;
  H^.HandleEvent(E);
  Check(HistoryStr(7, 0) = 'rec', 'cmRecordHistory records the text');

  Dispose(App, Done);
  MemDone;
  DoneHistory;
  Check(GetFPCHeapStatus.CurrHeapUsed = Used0, 'no memory is left behind');
  ClearHistory;
  Finish;
end.
