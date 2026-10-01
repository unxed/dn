{ TvGeom: points and rectangles.

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/objects.h (TPoint, TRect).
  Borland disclaimer and MIT notice: tv/COPYRIGHT.magiblot.

  A TRect is half-open: A is inside, B is outside. It is empty when B is not
  below and to the right of A. }
unit TvGeom;

{$I tvdefs.inc}

interface

type
  TPoint = record
    X, Y: Integer;
  end;
  PPoint = ^TPoint;

  TRect = object
    A, B: TPoint;
    procedure Assign(XA, YA, XB, YB: Integer);
    procedure Copy(const R: TRect);
    procedure Move(ADX, ADY: Integer);
    procedure Grow(ADX, ADY: Integer);
    procedure Intersect(const R: TRect);
    procedure Union(const R: TRect);
    function Contains(const P: TPoint): Boolean;
    function Equals(const R: TRect): Boolean;
    function Empty: Boolean;
  end;

function Point(AX, AY: Integer): TPoint; inline;
function PointAdd(const P1, P2: TPoint): TPoint; inline;
function PointSub(const P1, P2: TPoint): TPoint; inline;
function PointEq(const P1, P2: TPoint): Boolean; inline;

implementation

function Point(AX, AY: Integer): TPoint;
begin
  Result.X := AX;
  Result.Y := AY;
end;

function PointAdd(const P1, P2: TPoint): TPoint;
begin
  Result.X := P1.X + P2.X;
  Result.Y := P1.Y + P2.Y;
end;

function PointSub(const P1, P2: TPoint): TPoint;
begin
  Result.X := P1.X - P2.X;
  Result.Y := P1.Y - P2.Y;
end;

function PointEq(const P1, P2: TPoint): Boolean;
begin
  Result := (P1.X = P2.X) and (P1.Y = P2.Y);
end;

procedure TRect.Assign(XA, YA, XB, YB: Integer);
begin
  A.X := XA; A.Y := YA;
  B.X := XB; B.Y := YB;
end;

procedure TRect.Copy(const R: TRect);
begin
  A := R.A;
  B := R.B;
end;

procedure TRect.Move(ADX, ADY: Integer);
begin
  Inc(A.X, ADX); Inc(A.Y, ADY);
  Inc(B.X, ADX); Inc(B.Y, ADY);
end;

procedure TRect.Grow(ADX, ADY: Integer);
begin
  Dec(A.X, ADX); Dec(A.Y, ADY);
  Inc(B.X, ADX); Inc(B.Y, ADY);
end;

procedure TRect.Intersect(const R: TRect);
begin
  if R.A.X > A.X then A.X := R.A.X;
  if R.A.Y > A.Y then A.Y := R.A.Y;
  if R.B.X < B.X then B.X := R.B.X;
  if R.B.Y < B.Y then B.Y := R.B.Y;
end;

procedure TRect.Union(const R: TRect);
begin
  if R.A.X < A.X then A.X := R.A.X;
  if R.A.Y < A.Y then A.Y := R.A.Y;
  if R.B.X > B.X then B.X := R.B.X;
  if R.B.Y > B.Y then B.Y := R.B.Y;
end;

function TRect.Contains(const P: TPoint): Boolean;
begin
  Result := (P.X >= A.X) and (P.X < B.X) and (P.Y >= A.Y) and (P.Y < B.Y);
end;

function TRect.Equals(const R: TRect): Boolean;
begin
  Result := PointEq(A, R.A) and PointEq(B, R.B);
end;

function TRect.Empty: Boolean;
begin
  Result := (A.X >= B.X) or (A.Y >= B.Y);
end;

end.
