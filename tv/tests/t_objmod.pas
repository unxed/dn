program t_objmod;
{ Checks the object model the translation relies on: Borland-style `object`
  types with virtual methods, constructors/destructors, New(P, Init(...)),
  Dispose(P, Done), inherited calls, overriding across units, pointers to a
  base type that hold descendants, and a record passed by var to virtual methods. }
{$I ../src/tvdefs.inc}
uses TvGeom, ObjModA;
{$I testlib.inc}

type
  { a descendant in another unit than its ancestors, with a new field and a
    new virtual method }
  PCircle = ^TCircle;
  TCircle = object(TShape)
    Radius: Integer;
    constructor Init(AName: ShortString; ARadius: Integer);
    destructor Done; virtual;
    function Area: Integer; virtual;
    function Describe: ShortString; virtual;
    procedure Grow(var R: TRect); virtual;
  end;

  PSquare = ^TSquare;
  TSquare = object(TShape)
    Side: Integer;
    constructor Init(AName: ShortString; ASide: Integer);
    function Area: Integer; virtual;
  end;

constructor TCircle.Init(AName: ShortString; ARadius: Integer);
begin
  inherited Init(AName);
  Radius := ARadius;
end;

destructor TCircle.Done;
begin
  Inc(DoneCount, 100);
  inherited Done;
end;

function TCircle.Area: Integer;
begin
  Result := 3 * Radius * Radius;
end;

function TCircle.Describe: ShortString;
begin
  Result := 'circle:' + inherited Describe;
end;

procedure TCircle.Grow(var R: TRect);
begin
  R.Grow(Radius, Radius);
end;

constructor TSquare.Init(AName: ShortString; ASide: Integer);
begin
  inherited Init(AName);
  Side := ASide;
end;

function TSquare.Area: Integer;
begin
  Result := Side * Side;
end;

var
  P: PShape;
  C: PCircle;
  S: PSquare;
  R: TRect;
  Items: array[0..2] of PShape;
  I, Total: Integer;
begin
  { New(P, Init(...)) with a descendant stored in a base pointer }
  New(C, Init('c1', 2));
  P := C;
  Check(P^.Area = 12, 'virtual call through a base pointer reaches the override');
  Check(P^.Describe = 'circle:shape:c1', 'inherited call inside an override');
  Check(P^.Name = 'c1', 'field set by the ancestor constructor');
  Check(C^.Radius = 2, 'field of the descendant');

  { a method that the descendant does not override uses the ancestor's }
  New(S, Init('s1', 3));
  P := S;
  Check(P^.Area = 9, 'second descendant');
  Check(P^.Describe = 'shape:s1', 'ancestor method for a descendant without override');

  { var parameters in virtual methods }
  R.Assign(5, 5, 10, 10);
  P := C;
  P^.Grow(R);
  Check((R.A.X = 3) and (R.B.X = 12), 'record by var through a virtual method');
  P := S;
  P^.Grow(R);
  Check((R.A.X = 3) and (R.B.X = 12), 'the ancestor Grow does nothing');

  { Dispose(P, Done) runs the descendant's destructor first, then the ancestor's }
  DoneCount := 0;
  P := C;
  Dispose(P, Done);
  Check(DoneCount = 101, 'Dispose(P, Done) calls the virtual destructor chain');
  Dispose(S, Done);
  Check(DoneCount = 102, 'Dispose of the second descendant');

  { a list of different shapes, as a group of views would hold }
  New(C, Init('a', 1));
  New(S, Init('b', 4));
  Items[0] := C;
  Items[1] := S;
  Items[2] := TShapeFactory.MakeUnit;
  Total := 0;
  for I := 0 to 2 do
    Inc(Total, Items[I]^.Area);
  Check(Total = 3 + 16 + 1, 'polymorphic loop over base pointers, one object made in another unit');
  for I := 0 to 2 do
    Dispose(Items[I], Done);
  Check(DoneCount = 102 + 100 + 3, 'all disposed through the base pointer');

  { class-like static data: size and vmt pointer are in place }
  Check(SizeOf(TShape) > SizeOf(Pointer), 'objects with virtual methods carry a VMT pointer');
  Check(TypeOf(TCircle) <> TypeOf(TSquare), 'TypeOf differs for different types');

  Finish;
end.
