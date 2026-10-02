program t_msgbox;
{$I ../src/tvdefs.inc}
uses TvGeom, TvEvents, TvKeys, TvViews, TvMem, TvApp, TvMsgBox;
{$I testlib.inc}

var
  App: PApplication;
  R: TRect;
  Used0: PtrUInt;

begin
  Used0 := GetFPCHeapStatus.CurrHeapUsed;
  MemInit(80, 25);
  New(App, Init);

  MemClear;
  MemKey(kbEnter);
  Check(MessageBox('Hello', mfInformation or mfOKButton) = cmOK, 'Enter presses the default (first) button: cmOK');
  MemClear;
  MemKey(kbEsc);
  Check(MessageBox('Really?', mfConfirmation or mfOKCancel) = cmCancel, 'Esc: cmCancel');
  MemClear;
  MemKey(Ord('n'));
  Check(MessageBox('Save?', mfYesNoCancel) = cmNo, 'the hot letter N presses No');
  MemClear;
  MemKey(Ord('y'));
  Check(MessageBox('Save?', mfYesNoCancel) = cmYes, 'the hot letter Y presses Yes');
  MemClear;
  MemKey(Ord('c'));
  Check(MessageBox('Save?', mfYesNoCancel or mfWarning) = cmCancel, 'the hot letter C presses Cancel');
  MemClear;
  MemKey(kbEnter);
  Check(MessageBoxFmt(mfError or mfOKButton, 'File %s: error %d', ['A.TXT', 5]) = cmOK, 'a formatted message');
  MemClear;
  MemKey(kbEnter);
  R.Assign(10, 5, 60, 15);
  Check(MessageBoxRect(R, 'In a given place', mfOKButton) = cmOK, 'a box with given bounds');
  MemClear;
  MemKey(kbEnter);
  Check(MessageBox('A very long message that does not fit into one line of the box and must be wrapped over several lines, and one more sentence to make it really long.', mfOKButton) = cmOK,
    'a long message makes the box taller');
  { the box is gone from the desktop }
  Check(DeskTop^.First = PView(DeskTop^.Background), 'the desktop holds only its background after the boxes');
  MsgOKText := 'O~K~';
  Dispose(App, Done);
  MemDone;
  Check(GetFPCHeapStatus.CurrHeapUsed = Used0, 'no memory is left behind');
  Finish;
end.
