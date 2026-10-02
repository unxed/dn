program t_dialog;
{$I ../src/tvdefs.inc}
uses TvGeom, TvColors, TvCell, TvEvents, TvKeys, TvScreen, TvViews, TvWindow, TvMenus,
  TvSys, TvTimer, TvMem, TvApp, TvDialog;
{$I testlib.inc}

function R(A, B, C, D: Integer): TRect;
begin
  Result.Assign(A, B, C, D);
end;

var
  App: PApplication;
  Dlg: PDialog;
  Txt, Ctr, Txt2: PStaticText;
  Lbl: PLabel;
  Ok, Cancel: PButton;
  Res: Word;
  Ev: TEvent;
  Used0: PtrUInt;

begin
  Used0 := GetFPCHeapStatus.CurrHeapUsed;
  MemInit(80, 25);
  New(App, Init);

  New(Dlg, Init(R(10, 5, 50, 16), 'Title'));
  Check((Dlg^.Flags = (wfMove or wfClose)) and (Dlg^.GrowMode = 0), 'a dialog moves and closes, does not grow');
  Check(Dlg^.Palette = dpGrayDialog, 'a gray dialog');
  Check(Dlg^.Number = wnNoNumber, 'a dialog has no number');
  Check((Dlg^.DirectLink[1] = nil) and (Dlg^.DirectLink[9] = nil), 'DN extensions: DirectLink starts empty');
  Check(Dlg^.Title^ = 'Title', 'the title is a heap string (PStr), as in Borland');

  New(Txt, Init(R(2, 1, 14, 4), 'Hello brave new world'));
  Dlg^.Insert(Txt);
  New(Ctr, Init(R(2, 5, 14, 6), #3'Hi'));
  Dlg^.Insert(Ctr);
  New(Ok, Init(R(5, 8, 15, 10), '~O~K', cmOK, bfDefault));
  Dlg^.Insert(Ok);
  New(Cancel, Init(R(20, 8, 30, 10), 'Cancel', cmCancel, bfNormal));
  Dlg^.Insert(Cancel);
  New(Lbl, Init(R(2, 3, 14, 4), '~N~ame', Cancel));
  Dlg^.Insert(Lbl);
  New(Txt2, Init(R(20, 1, 30, 4), 'AB'#13'CD'));
  Dlg^.Insert(Txt2);
  Dlg^.SelectNext(False);   { the last inserted control has the focus: go back to the first }
  App^.InsertWindow(Dlg);

  { static text }
  Check(MemText(7, 12, 23) = 'Hello brave ', 'static text: the first line is cut at a space');
  Check(MemText(8, 12, 23) = 'new world   ', 'static text: the rest goes to the next line');
  Check(MemText(11, 12, 23) = '     Hi     ', 'static text: #3 centers the line');
  Check((MemText(7, 30, 31) = 'AB') and (MemText(8, 30, 31) = 'CD'), 'static text: #13 ends a line as #10 does (Borland, DN)');
  Check(MemAttr(12, 7) = $70, 'static text color: the text of the gray dialog');
  Check((Txt^.GrowMode and gfFixed) <> 0, 'static text is fixed');

  { label }
  Check(MemText(9, 12, 17) = ' Name ', 'a label has a blank before the text');
  Check(MemAttr(13, 9) = $7E, 'the shortcut of a label: yellow on gray');
  Check(not Lbl^.Light, 'the label is not lit while its link is not focused');
  Check((Lbl^.Options and (ofPreProcess or ofPostProcess)) = (ofPreProcess or ofPostProcess), 'a label sees keys before and after');

  { buttons }
  Check(MemText(14, 15, 24) = '    OK   ▄', 'button: the title is centered, the shadow on the right');
  Check(MemText(15, 15, 24) = '  ▀▀▀▀▀▀▀▀', 'button: the shadow below');
  Check(Ok^.AmDefault and not Cancel^.AmDefault, 'the default button');
  Check((Ok^.Options and (ofSelectable or ofFirstClick)) = (ofSelectable or ofFirstClick), 'button options');
  Check(MemAttr(34, 14) = $20, 'a button: black on green');
  Check(MemAttr(17, 14) = $2F, 'the focused default button: white on green');
  Check(MemAttr(15, 14) = $70, 'the left edge of a button is shadow-colored');

  { focus: the label is lit when its button is focused }
  Cancel^.Focus;
  Check(Lbl^.Light, 'the label lights up when its link gets the focus');
  Check((Cancel^.State and sfFocused) <> 0, 'the button is focused');
  Ok^.Focus;
  Check(not Lbl^.Light, 'the label goes out when its link loses the focus');

  { Alt+N focuses the label's link }
  MemKey(kbAltN, kbAltShift);
  Ev.What := evNothing;
  App^.GetEvent(Ev);
  Dlg^.HandleEvent(Ev);
  Check(((Cancel^.State and sfFocused) <> 0) and Lbl^.Light, 'the hot key of a label focuses its link');

  { running the dialog }
  Dispose(Dlg, Done);
  Check(True, 'a dialog is disposed with its controls');

  New(Dlg, Init(R(10, 5, 50, 16), 'Dlg'));
  New(Ok, Init(R(5, 8, 15, 10), '~O~K', cmOK, bfDefault));
  Dlg^.Insert(Ok);
  New(Cancel, Init(R(20, 8, 30, 10), 'Cancel', cmCancel, bfNormal));
  Dlg^.Insert(Cancel);
  Dlg^.SelectNext(False);

  { Enter presses the default button (after its animation) }
  MemClear;
  MemKey(kbEnter);
  MemClock := 0;
  Res := DeskTop^.ExecView(Dlg);
  Check(Res = cmOK, 'Enter: the default button is pressed, cmOK ends the dialog');
  Check(MemClock >= 100, 'the button animation took its 100 ms');
  Check(Ok^.AnimationTimer = nil, 'and the timer is gone');

  { Esc cancels }
  MemClear;
  MemKey(kbEsc);
  Check(DeskTop^.ExecView(Dlg) = cmCancel, 'Esc: cmCancel');
  Check(ModalCount = 0, 'DN extensions: ModalCount is 0 again after ExecView');

  { a click on a button }
  MemClear;
  MemMouse(evMouseDown, 36, 14);
  MemMouse(evMouseUp, 36, 14);
  Check(DeskTop^.ExecView(Dlg) = cmCancel, 'a click on the Cancel button');
  { pressed on a button, released away from it: nothing happens, Esc ends it }
  MemClear;
  MemMouse(evMouseDown, 36, 14);
  MemMouse(evMouseUp, 11, 8);
  MemKey(kbEsc);
  Check(DeskTop^.ExecView(Dlg) = cmCancel, 'released away from the button: no command, Esc ends the dialog');
  { Alt+O (the hot key of OK) }
  MemClear;
  MemKey(kbAltO, kbAltShift);
  Check(DeskTop^.ExecView(Dlg) = cmOK, 'the hot key of a button presses it');
  { Tab moves the focus, Space presses the focused button }
  MemClear;
  MemKey(kbTab);
  MemKey(Ord(' '));
  Res := DeskTop^.ExecView(Dlg);
  Check((Res = cmCancel) or (Res = cmOK), 'Tab and Space');
  { a disabled button }
  DeskTop^.Insert(Dlg);
  DisableCommand(cmCancel);
  Ev.What := evBroadcast;
  Ev.Command := cmCommandSetChanged;
  Dlg^.HandleEvent(Ev);
  Check((Cancel^.State and sfDisabled) <> 0, 'a button of a disabled command is disabled');
  Check(MemAttr(34, 14) = $78, 'a disabled button: dark gray on gray');
  EnableCommand(cmCancel);
  Dlg^.HandleEvent(Ev);
  Check((Cancel^.State and sfDisabled) = 0, 'and is enabled again');
  Dispose(Dlg, Done);

  Dispose(App, Done);
  MemDone;
  Check(GetFPCHeapStatus.CurrHeapUsed = Used0, 'no memory is left behind');
  Finish;
end.
