program t_cluster;
{$I ../src/tvdefs.inc}
uses TvGeom, TvCell, TvCodePg, TvEvents, TvKeys, TvViews, TvObjs, TvUtil, TvMem, TvApp,
  TvDialog, TvCluster;
{$I testlib.inc}

function R(A, B, C, D: Integer): TRect;
begin
  Result.Assign(A, B, C, D);
end;

function Pt(X, Y: Integer): TPoint;
begin
  Result.X := X;
  Result.Y := Y;
end;

procedure Key(V: PView; Code: Word; Mods: Word = 0);
var
  E: TEvent;
begin
  MakeKeyEvent(E, Code, Mods);
  V^.HandleEvent(E);
end;

var
  App: PApplication;
  Dlg: PDialog;
  Chk: PCheckBoxes;
  Rad: PRadioButtons;
  Mul: PMultiCheckBoxes;
  Wide: PCheckBoxes;
  Used0: PtrUInt;
  W: Word;
  D: LongWord;
  E: TEvent;

begin
  CpSelect(866);
  Used0 := GetFPCHeapStatus.CurrHeapUsed;
  MemInit(80, 25);
  New(App, Init);
  New(Dlg, Init(R(10, 5, 60, 14), 'Cluster'));
  New(Chk, Init(R(2, 2, 22, 5), NewSItem('~A~lpha', NewSItem('~B~eta', NewSItem('~G~amma', nil)))));
  Dlg^.Insert(Chk);
  New(Rad, Init(R(2, 5, 22, 8), NewSItem('~O~ne', NewSItem('~T~wo', NewSItem('T~h~ree', nil)))));
  Dlg^.Insert(Rad);
  New(Mul, Init(R(2, 8, 22, 10), NewSItem('~X~', NewSItem('~Y~', nil)), 3, $0203, ' -+'));
  Dlg^.Insert(Mul);
  New(Wide, Init(R(25, 2, 49, 4), NewSItem('Alpha', NewSItem('Beta', NewSItem('Gamma', NewSItem('Delta', nil))))));
  Dlg^.Insert(Wide);
  Chk^.Select;
  App^.InsertWindow(Dlg);

  Check((Chk^.Strings^.Count = 3) and (Chk^.Value = 0) and (Chk^.Sel = 0), 'a new cluster');
  Check((Chk^.Options and (ofSelectable or ofFirstClick or ofPreProcess or ofPostProcess)) =
    (ofSelectable or ofFirstClick or ofPreProcess or ofPostProcess), 'options');
  Check(Chk^.GetState(sfFocused), 'the first cluster is focused');
  Check(Chk^.DataSize = 2, 'the data of a cluster is a Word');
  Check(Mul^.DataSize = 4, 'the data of multi check boxes is a LongWord');

  { check boxes }
  Check(MemText(8, 12, 21) = ' [ ] Alpha', 'a check box row');
  Key(Chk, Ord(' '));
  Check(Chk^.Value = 1, 'Space toggles the item');
  Check(MemText(8, 12, 21) = ' [X] Alpha', 'and it is shown');
  Key(Chk, kbDown);
  Check(Chk^.Sel = 1, 'Down moves the selection');
  Key(Chk, Ord(' '));
  Check(Chk^.Value = 3, 'Space toggles the second one');
  Key(Chk, Ord(' '));
  Check(Chk^.Value = 1, 'and back');
  Key(Chk, Ord('g'));
  Check((Chk^.Value = 5) and (Chk^.Sel = 2), 'a hot key toggles its item');
  Key(Chk, kbDown);
  Check(Chk^.Sel = 0, 'the selection wraps');
  Key(Chk, kbUp);
  Check(Chk^.Sel = 2, 'and wraps up');
  W := 0;
  Chk^.GetData(W);
  Check(W = 5, 'GetData');
  W := 2;
  Chk^.SetData(W);
  Check((Chk^.Value = 2) and Chk^.Mark(1) and not Chk^.Mark(0), 'SetData and Mark');

  { disabled items }
  Chk^.SetButtonState(2, False);
  Check(not Chk^.ButtonState(1) and Chk^.ButtonState(0), 'ButtonState');
  Chk^.Sel := 0;
  Key(Chk, kbDown);
  Check(Chk^.Sel = 2, 'Down skips a disabled item');
  Key(Chk, Ord('b'));
  Check(Chk^.Value = 2, 'a disabled item does not react to its hot key');
  Chk^.SetButtonState($FFFFFFFF, False);
  Check((Chk^.Options and ofSelectable) = 0, 'all items disabled: the cluster is not selectable');
  Chk^.SetButtonState($FFFFFFFF, True);
  Check((Chk^.Options and ofSelectable) <> 0, 'and selectable again');

  { the mouse }
  Chk^.Value := 0;
  Chk^.Sel := 0;
  MemClear;
  MemMouse(evMouseUp, 17, 9);
  ClearEvent(E);
  E.What := evMouseDown;
  E.Where.X := 17;
  E.Where.Y := 9;
  E.Buttons := mbLeftButton;
  Chk^.HandleEvent(E);
  Check((Chk^.Sel = 1) and (Chk^.Value = 2), 'a click on an item presses it');
  Check(Chk^.FindSel(Pt(2, 1)) = 1, 'FindSel finds the item under the point');
  Check((Chk^.FindSel(Pt(2, 3)) = -1) and (Chk^.FindSel(Pt(25, 0)) = -1),
    'and -1 outside the items');

  { columns }
  Check((Wide^.Column(0) = 0) and (Wide^.Column(1) = 0) and (Wide^.Column(2) = 11), 'two columns');
  Check((Wide^.Row(0) = 0) and (Wide^.Row(1) = 1) and (Wide^.Row(2) = 0) and (Wide^.Row(3) = 1), 'rows');
  Check(Wide^.FindSel(Pt(12, 1)) = 3, 'FindSel in the second column');
  Wide^.Select;
  Key(Wide, kbRight);
  Check(Wide^.Sel = 2, 'Right goes to the next column');
  Key(Wide, kbLeft);
  Check(Wide^.Sel = 0, 'Left goes back');
  Check(MemText(8, 35, 55) = ' [ ] Alpha  [ ] Gamma', 'the text of the first row of the wide cluster');

  { radio buttons }
  Rad^.Select;
  Check(MemText(11, 12, 19) = ' (' + #$E2#$80#$A2 + ') One', 'a radio button row (the first is marked)');
  Check(MemText(12, 12, 19) = ' ( ) Two', 'and the others are not');
  Key(Rad, Ord(' '));
  Check(Rad^.Value = 0, 'Space presses the selected button');
  Key(Rad, kbDown);
  Check((Rad^.Value = 1) and (Rad^.Sel = 1), 'moving selects the button');
  Check(MemText(12, 12, 19) = ' (' + #$E2#$80#$A2 + ') Two', 'and shows it');
  Key(Rad, Ord('h'));
  Check(Rad^.Value = 2, 'a hot key presses the button');
  Check(Rad^.Mark(2) and not Rad^.Mark(1), 'Mark');
  W := 0;
  Rad^.SetData(W);
  Check((Rad^.Value = 0) and (Rad^.Sel = 0), 'SetData moves the selection too');

  { multi check boxes }
  Mul^.Select;
  Check(MemText(14, 12, 17) = ' [ ] X', 'a multi check box row');
  Key(Mul, Ord(' '));
  Check((Mul^.Value = 1) and (Mul^.MultiMark(0) = 1), 'the first press: state 1');
  Check(MemText(14, 12, 17) = ' [-] X', 'shown');
  Key(Mul, Ord(' '));
  Check((Mul^.Value = 2) and (MemText(14, 12, 17) = ' [+] X'), 'the second press: state 2');
  Key(Mul, Ord(' '));
  Check(Mul^.Value = 0, 'the third press: back to 0');
  Key(Mul, kbDown);
  Key(Mul, Ord(' '));
  Check((Mul^.Value = 4) and (Mul^.MultiMark(1) = 1) and (Mul^.MultiMark(0) = 0), 'the second item uses its own bits');
  D := 0;
  Mul^.GetData(D);
  Check(D = 4, 'GetData gives a LongWord');
  D := 6;
  Mul^.SetData(D);
  Check((Mul^.MultiMark(0) = 2) and (Mul^.MultiMark(1) = 1), 'SetData');

  Dispose(App, Done);
  MemDone;
  Check(GetFPCHeapStatus.CurrHeapUsed = Used0, 'no memory is left behind');
  Finish;
end.
