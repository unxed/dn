program t_shim;
{ The shim unit Views (tools/gen-shim.py): DN names that give the names of tv/. }
{$mode objfpc}{$H-}
uses Views, TvGeom, TvViews;      { the originals, to compare with }
{$I dntest.inc}

var
  R: TRect;
  E: TEvent;
  V: PView;
  Ph: TPhaseType;

begin
  { a type, its methods and a constant of the shim are those of tv/ }
  R.Assign(1, 2, 11, 5);
  Check((R.A.X = 1) and (R.B.Y = 5) and (SizeOf(TRect) = SizeOf(TvGeom.TRect)), 'TRect through the shim');
  Check((cmQuit = TvViews.cmQuit) and (sfVisible = TvViews.sfVisible), 'constants');
  Ph := phPostProcess;
  Check(Ph = TvViews.phPostProcess, 'the members of an enumeration are constants of the shim');
  { a variable of the shim is the variable of tv/ itself }
  ShowMarkers := True;
  Check(TvViews.ShowMarkers, 'a variable is the same memory');
  ShowMarkers := False;
  { a routine of the shim calls that of tv/ }
  ClearEvent(E);
  E.What := evCommand;
  Check(E.What = evCommand, 'ClearEvent and TEvent');
  ClearEvent(E);
  Check(E.What = evNothing, 'ClearEvent clears');
  { an object of the shim can be created and is a descendant of the original }
  New(V, Init(R));
  Check(V <> nil, 'New(V, Init(R))');
  Check((V^.Size.X = 10) and (V^.Size.Y = 3), 'TView of the shim');
  Dispose(V, Done);
  Finish;
end.
