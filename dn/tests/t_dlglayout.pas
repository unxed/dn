program t_dlglayout;
{ The layout rule of the dialogs of the resources (DlgLayout.TResDialog): the grow modes it gives and the size limits. }
{$mode objfpc}{$H-}
uses SysUtils, TvGeom, TvViews, TvWindow, TvDialog, TvInput, TvList, DlgLayout;
{$I dntest.inc}

function MakeR(AX, AY, BX, BY: Integer): TRect;
begin
  Result := TRect.Create(AX, AY, BX, BY);
end;

var
  D: TResDialog;
  Inp, Inp2, Lst: TView;
  Lbl, Hist, Ok, Sb, Below: TView;
  Mn, Mx: TPoint;

begin
  { an input line with a history arrow and a label, a list with its scroll bar, a line under the list, buttons at the bottom }
  D := TResDialog.Create(MakeR(0, 0, 60, 20), 'T');
  Lbl := TStaticText.Create(MakeR(2, 2, 10, 3), 'Name');
  D.Insert(Lbl);
  Inp := TInputLine.Create(MakeR(10, 2, 50, 3), 80);
  D.Insert(Inp);
  Hist := TView.Create(MakeR(50, 2, 53, 3));
  D.Insert(Hist);
  Sb := TScrollBar.Create(MakeR(50, 4, 51, 14));
  D.Insert(Sb);
  Lst := TListBox.Create(MakeR(2, 4, 50, 14), 1, TScrollBar(Sb));
  D.Insert(Lst);
  Below := TStaticText.Create(MakeR(2, 15, 40, 16), 'under the list');
  D.Insert(Below);
  Ok := TButton.Create(MakeR(20, 17, 30, 19), 'OK', 10, bfDefault);
  D.Insert(Ok);
  Inp2 := TInputLine.Create(MakeR(52, 17, 58, 18), 10);
  D.Insert(Inp2);
  D.Layout;
  Check(Inp.GrowMode = gfGrowHiX, 'the input line stretches to the right');
  Check(Hist.GrowMode = gfGrowLoX or gfGrowHiX, 'the view to the right of it moves with the right edge');
  Check(Lbl.GrowMode = 0, 'the label to the left of it stays');
  Check(Lst.GrowMode = gfGrowHiX or gfGrowHiY, 'the list stretches both ways');
  Check(Sb.GrowMode = gfGrowLoX or gfGrowHiX or gfGrowHiY, 'its scroll bar moves to the right and stretches down');
  Check(Below.GrowMode = gfGrowLoY or gfGrowHiY, 'the line under the list moves down');
  Check(Ok.GrowMode = gfGrowLoY or gfGrowHiY, 'a button with an input line that stretches to its right stays at the left, moves down');
  Check(Inp2.GrowMode = gfGrowHiX or gfGrowLoY or gfGrowHiY, 'the input line of the bottom row stretches and moves down');
  Check((D.Flags and wfGrow) <> 0, 'the dialog can be resized');
  D.SizeLimits(Mn, Mx);
  Check((Mn.X = 60) and (Mn.Y = 20), 'it cannot be smaller than it was laid out');
  D.Free;

  { only buttons and check boxes: nothing stretches, the dialog keeps its size }
  D := TResDialog.Create(MakeR(0, 0, 40, 10), 'T');
  Ok := TButton.Create(MakeR(5, 7, 15, 9), 'OK', 10, bfDefault);
  D.Insert(Ok);
  D.Layout;
  Check((D.Flags and wfGrow) = 0, 'nothing stretches: no resize corner');
  D.Free;

  { a list: a button of a column to its right moves with the right edge and stays at the top; RESIZE Y keeps the width }
  D := TResDialog.Create(MakeR(0, 0, 50, 16), 'T');
  Lst := TListBox.Create(MakeR(2, 2, 35, 14), 1, nil);
  D.Insert(Lst);
  Ok := TButton.Create(MakeR(37, 2, 47, 4), 'OK', 10, bfDefault);
  D.Insert(Ok);
  D.Resize := rzY;
  D.Layout;
  Check(Ok.GrowMode = gfGrowLoX or gfGrowHiX, 'a button to the right of the list moves with the right edge, stays at the top');
  D.SizeLimits(Mn, Mx);
  Check(Mx.X = 50, 'RESIZE Y: the width stays');
  D.Free;
  Finish;
end.
