program t_vstrm;
{ Streams of the views of dialogs: a dialog with its controls is stored and loaded back. }
{$I ../src/tvdefs.inc}
uses TvGeom, TvEvents, TvScreen, TvObjs, TvUtil, TvViews, TvWindow, TvDialog, TvInput, TvCluster, TvList;
{$I testlib.inc}

function R(A, B, C, D: Integer): TRect;
begin
  Result.Assign(A, B, C, D);
end;

var
  D, L: PDialog;
  M: TMemoryStream;
  Inp: PInputLine;
  Lab: PLabel;
  Btn: PButton;
  Chk: PCheckBoxes;
  Lb: PListBox;
  Coll: PStringCollection;
  I: Integer;
  Inp2: PInputLine;
  Lab2: PLabel;
  Btn2: PButton;
  Chk2: PCheckBoxes;
  Lb2: PListBox;
  St2: PStaticText;
  P: PView;

procedure Find;
begin
  Inp2 := nil; Lab2 := nil; Btn2 := nil; Chk2 := nil; Lb2 := nil; St2 := nil;
  for I := 1 to 20 do
  begin
    P := L^.At(I);
    if P = nil then
      Break;
    if TypeOf(P^) = TypeOf(TInputLine) then Inp2 := PInputLine(P);
    if TypeOf(P^) = TypeOf(TLabel) then Lab2 := PLabel(P);
    if TypeOf(P^) = TypeOf(TButton) then Btn2 := PButton(P);
    if TypeOf(P^) = TypeOf(TCheckBoxes) then Chk2 := PCheckBoxes(P);
    if TypeOf(P^) = TypeOf(TListBox) then Lb2 := PListBox(P);
    if TypeOf(P^) = TypeOf(TStaticText) then St2 := PStaticText(P);
  end;
end;

begin
  ScreenCreate(80, 25);
  RegisterType(RView);
  RegisterType(RGroup);
  RegisterType(RFrame);
  RegisterType(RWindow);
  RegisterType(RScrollBar);
  RegisterType(RListViewer);
  RegisterType(RDialog);
  RegisterType(RStaticText);
  RegisterType(RLabel);
  RegisterType(RButton);
  RegisterType(RInputLine);
  RegisterType(RCluster);
  RegisterType(RCheckBoxes);
  RegisterType(RRadioButtons);
  RegisterType(RListBox);
  RegisterType(RCollection);
  RegisterType(RStringCollection);

  D := New(PDialog, Init(R(0, 0, 50, 16), 'Options'));
  Inp := New(PInputLine, Init(R(3, 3, 30, 4), 20));
  Inp^.Data^ := 'abc';
  Inp^.CurPos := 2;
  D^.Insert(Inp);
  Lab := New(PLabel, Init(R(2, 2, 12, 3), '~N~ame', Inp));
  D^.Insert(Lab);
  D^.Insert(New(PStaticText, Init(R(3, 5, 40, 6), 'some text')));
  Btn := New(PButton, Init(R(3, 13, 13, 15), '~O~K', cmOK, bfDefault));
  D^.Insert(Btn);
  Chk := New(PCheckBoxes, Init(R(3, 7, 20, 9), NewSItem('~A~', NewSItem('~B~', nil))));
  Chk^.Value := 2;
  D^.Insert(Chk);
  New(Coll, Init(5, 5));
  Coll^.Insert(NewStr('one'));
  Coll^.Insert(NewStr('two'));
  Lb := New(PListBox, Init(R(25, 7, 45, 12), 1, nil));
  Lb^.NewList(Coll);
  D^.Insert(Lb);

  D^.DirectLink[1] := Inp;           { DN: the controls of a dialog by number }
  D^.DirectLink[2] := Chk;
  M.Init(0, 1024);
  M.Put(D);
  Check(M.Status = stOk, 'a dialog is stored');
  M.Seek(0);
  L := PDialog(M.Get);
  Check((L <> nil) and (M.Status = stOk), 'a dialog is loaded');
  Check((L <> nil) and (L^.Title^ = 'Options') and (L^.Size.X = 50), 'the window part');
  Find;
  Check(Inp2 <> nil, 'the input line');
  Check((L <> nil) and (L^.DirectLink[1] = PView(Inp2)) and (L^.DirectLink[2] = PView(Chk2)) and (L^.DirectLink[3] = nil),
    'DirectLink: the numbers of the controls of the dialog are stored and give the loaded controls');
  Check((Inp2 <> nil) and (Inp2^.Data^ = 'abc') and (Inp2^.MaxLen = 20),
    'the text and the length of the input line (Awaken selects all, as in Borland TV)');
  Check((Lab2 <> nil) and (Lab2^.Link = PView(Inp2)), 'the label points to its input line');
  Check((Lab2 <> nil) and (Lab2^.Text <> nil) and (Lab2^.Text^ = '~N~ame'), 'the text of the label');
  Check((Btn2 <> nil) and (Btn2^.Title^ = '~O~K') and (Btn2^.Command = cmOK) and Btn2^.AmDefault, 'the button');
  Check((Chk2 <> nil) and (Chk2^.Value = 2) and (Chk2^.Strings^.Count = 2), 'the check boxes');
  Check((Lb2 <> nil) and (Lb2^.List <> nil) and (Lb2^.List^.Count = 2) and (Lb2^.Range = 2), 'the list box and its list');
  Check((St2 <> nil) and (St2^.Text^ = 'some text'), 'the static text');
  Check((L <> nil) and (L^.Frame <> nil), 'the frame');
  Dispose(L, Done);
  Dispose(D, Done);
  M.Done;
  ScreenDestroy;
  Finish;
end.
