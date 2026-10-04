{ Tests of dn/new/objutil.pas: FreeObject and ObjChangeType over the TObject of tv/ }
{$mode objfpc}{$H-}
program t_objutil;
uses objutil;
{$I dntest.inc}
type
  PA = ^TA;
  TA = object(TObject)
    N: Integer;
    function Name: Integer; virtual;
  end;
  PB = ^TB;
  TB = object(TA)
    function Name: Integer; virtual;
  end;

function TA.Name: Integer; begin Result := 1; end;
function TB.Name: Integer; begin Result := 2; end;

var
  P: PA;
  Q: PObject;
begin
  New(P, Init);
  P^.N := 7;
  Check(P^.Name = 1, 'the base type answers');
  ObjChangeType(P, TypeOf(TB));
  Check((P^.Name = 2) and (P^.N = 7), 'ObjChangeType: the virtual method is the one of the new type, the fields stay');
  Check(TypeOf(P^) = TypeOf(TB), 'TypeOf shows the new type');
  FreeObject(P);
  Check(P = nil, 'FreeObject sets the pointer to nil');
  FreeObject(P);
  Q := nil;
  FreeObject(Q);
  Check(Q = nil, 'FreeObject of nil is harmless');
  Finish;
end.
