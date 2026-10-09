program t_shim;
{ The shim unit Views (tools/gen-shim.py): DN names that give the names of tv/. }
{$mode objfpc}{$H-}
uses Views, TvGeom, TvViews;      { the originals, to compare with }
{$I dntest.inc}

var
  R: TRect;
  E: TEvent;
  V: TView;
  Ph: TPhaseType;

begin
  { a type, its methods and a constant of the shim are those of tv/ }
  R := TRect.Create(1, 2, 11, 5);
  Check((R.A.X = 1) and (R.B.Y = 5) and (SizeOf(TRect) = SizeOf(TvGeom.TRect)), 'TRect through the shim');
  Check((cmQuit = TvViews.cmQuit) and (sfVisible = TvViews.sfVisible), 'constants');
  Ph := phPostProcess;
  Check(Ph = TvViews.phPostProcess, 'the members of an enumeration are constants of the shim');
  { a variable of the shim is the variable of tv/ itself }
  UxWheelUnderCursor := False;
  Check(not TvViews.UxWheelUnderCursor, 'a variable is the same memory');
  UxWheelUnderCursor := True;
  { a routine of the shim calls that of tv/ }
  ClearEvent(E);
  E.What := evCommand;
  Check(E.What = evCommand, 'ClearEvent and TEvent');
  ClearEvent(E);
  Check(E.What = evNothing, 'ClearEvent clears');
  { an instance of the shim can be created and is a descendant of the original }
  V := TView.Create(R);
  Check(V <> nil, 'The view class was created');
  Check((V.Size.X = 10) and (V.Size.Y = 3), 'TView of the shim');
  V.Free;
  Finish;
end.
