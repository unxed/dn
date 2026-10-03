program t_dnscreen;
{ Tests of compat/dnscreen.pas (the screen of DN over tv/). }
{$mode objfpc}{$H-}
uses SysUtils, osdep, dnscreen, TvScreen, TvCell, TvColors;
{$I dntest.inc}

var
  Pt: TSysPoint;
  Cells: PWord;
  CX, CY: Word;
  Y1, Y2: Integer;
  Vis: Boolean;

begin
  ScreenCreate(80, 25);
  Check(GetScreenMode(@Pt, True) = 3, 'GetScreenMode: 80x25 is the mode 3');
  Check((Pt.X = 80) and (Pt.Y = 25), 'GetScreenMode gives the size');
  ClearScreenCells;
  Cells := ReadScreenCells;
  Check((Cells <> nil) and (Cells[0] = $0720) and (Cells[80 * 25 - 1] = $0720), 'ClearScreenCells: blanks, attribute 7');
  Cells[81] := $1E41;                                    { 'A' at (1,1) }
  WriteScreenCells(81, 1);
  Check((ScreenBuffer[81].Character.Text[0] = Ord('A')) and (AttrAsBIOSByte(ScreenBuffer[81].Attribute) = $1E),
    'WriteScreenCells writes the cells to the screen of tv/');
  Cells := ReadScreenCells;
  Check(Cells[81] = $1E41, 'ReadScreenCells reads them back');
  MoveCursorTo(5, 7);
  GetCursorXY(CX, CY);
  Check((CX = 5) and (CY = 7), 'cursor position');
  SetCursorType(14, 15, True);
  GetCursorType(Y1, Y2, Vis);
  Check(Vis and (Y2 = 15) and (Y1 = 14), 'cursor type round trip');
  SetCursorType(0, 0, False);
  GetCursorType(Y1, Y2, Vis);
  Check(not Vis, 'hidden cursor');
  Check(SetScreenSize(80, 25) and not SetScreenSize(80, 50), 'SetScreenSize: only the size that is there');
  ScreenDestroy;
  Finish;
end.
