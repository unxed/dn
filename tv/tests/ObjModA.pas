{ Test support for t_objmod: the ancestor object types live in their own unit. }
unit ObjModA;

{$I ../src/tvdefs.inc}

interface

uses
  TvGeom;

type
  PShape = ^TShape;
  TShape = object
    Name: ShortString;
    constructor Init(AName: ShortString);
    destructor Done; virtual;
    function Area: Integer; virtual;
    function Describe: ShortString; virtual;
    procedure Grow(var R: TRect); virtual;
  end;

  TShapeFactory = object
    class function MakeUnit: PShape; static;
  end;

var
  DoneCount: Integer = 0;

implementation

type
  PUnit = ^TUnit;
  TUnit = object(TShape)
    function Area: Integer; virtual;
  end;

constructor TShape.Init(AName: ShortString);
begin
  Name := AName;
end;

destructor TShape.Done;
begin
  Inc(DoneCount);
end;

function TShape.Area: Integer;
begin
  Result := 0;
end;

function TShape.Describe: ShortString;
begin
  Result := 'shape:' + Name;
end;

procedure TShape.Grow(var R: TRect);
begin
end;

function TUnit.Area: Integer;
begin
  Result := 1;
end;

class function TShapeFactory.MakeUnit: PShape;
var
  U: PUnit;
begin
  New(U, Init('unit'));
  Result := U;
end;

end.
