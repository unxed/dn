{ Resource subtype dispatch and native class-reference release. }
{$mode objfpc}{$H-}
program t_objutil;
uses SysUtils, objutil;
{$I dntest.inc}
var
  Released: Integer = 0;
type
  TA = class(TStreamable)
    N: Integer;
    function Name: Integer; virtual;
    destructor Destroy; override;
  end;
  TB = class(TA)
    function Name: Integer; override;
  end;

function TA.Name: Integer; begin Result := 1; end;
function TB.Name: Integer; begin Result := 2; end;

destructor TA.Destroy;
begin
  Inc(Released);
  inherited Destroy;
end;

var
  P: TA;
  Q: TStreamable;
begin
  P := TA.Create;
  P.N := 7;
  Check(P.Name = 1, 'the base type answers');
  ObjChangeType(P, System.TClass(TB));
  Check((P.Name = 2) and (P.N = 7), 'ObjChangeType: the virtual method is the one of the new type, the fields stay');
  Check(P.ClassType = TB, 'ClassType shows the new type');
  FreeAndNil(P);
  Check(P = nil, 'the released class reference is nil');
  Check(Released = 1, 'release dispatches the inherited destructor');
  FreeAndNil(P);
  Check(Released = 1, 'releasing nil does not destroy again');
  Q := nil;
  FreeAndNil(Q);
  Check(Q = nil, 'releasing a nil base reference is harmless');
  Finish;
end.
