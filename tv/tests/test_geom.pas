program test_geom;
{$I ../src/tvdefs.inc}
uses TvGeom;
{$I testlib.inc}

var
  R, S, T: TRect;
begin
  R.Assign(1, 2, 11, 7);
  Check((R.A.X = 1) and (R.A.Y = 2) and (R.B.X = 11) and (R.B.Y = 7), 'Assign');

  T.Copy(R);
  Check(T.Equals(R), 'Copy/Equals');

  R.Move(3, -1);
  Check((R.A.X = 4) and (R.A.Y = 1) and (R.B.X = 14) and (R.B.Y = 6), 'Move');

  R.Grow(2, 1);
  Check((R.A.X = 2) and (R.A.Y = 0) and (R.B.X = 16) and (R.B.Y = 7), 'Grow');
  R.Grow(-2, -1);
  Check((R.A.X = 4) and (R.A.Y = 1) and (R.B.X = 14) and (R.B.Y = 6), 'Grow back');

  { half-open: A inside, B outside }
  R.Assign(0, 0, 10, 5);
  Check(R.Contains(Point(0, 0)), 'Contains A');
  Check(R.Contains(Point(9, 4)), 'Contains B-1');
  Check(not R.Contains(Point(10, 4)), 'not Contains B.X');
  Check(not R.Contains(Point(9, 5)), 'not Contains B.Y');
  Check(not R.Contains(Point(-1, 0)), 'not Contains left');

  Check(not R.Empty, 'not Empty');
  S.Assign(3, 3, 3, 9);
  Check(S.Empty, 'Empty (zero width)');
  S.Assign(5, 5, 2, 9);
  Check(S.Empty, 'Empty (inverted)');

  R.Assign(0, 0, 10, 10);
  S.Assign(5, 6, 20, 8);
  T.Copy(R);
  T.Intersect(S);
  Check((T.A.X = 5) and (T.A.Y = 6) and (T.B.X = 10) and (T.B.Y = 8), 'Intersect');

  S.Assign(20, 20, 30, 30);
  T.Copy(R);
  T.Intersect(S);
  Check(T.Empty, 'Intersect disjoint is Empty');

  S.Assign(-5, 4, 6, 15);
  T.Copy(R);
  T.Union(S);
  Check((T.A.X = -5) and (T.A.Y = 0) and (T.B.X = 10) and (T.B.Y = 15), 'Union');

  Check(PointEq(PointAdd(Point(1, 2), Point(10, 20)), Point(11, 22)), 'PointAdd');
  Check(PointEq(PointSub(Point(10, 20), Point(1, 2)), Point(9, 18)), 'PointSub');
  Check(not PointEq(Point(1, 2), Point(2, 1)), 'PointEq false');

  Finish;
end.
