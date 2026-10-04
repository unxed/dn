{ objutil: the classes of DN over tv/. TStreamable is the streamable-class root of tv/ (TvObjs); it is re-exported here
  for the old unit order. The helpers that tv/ does not have are FreeObject (Free and O := nil) and ObjChangeType
  (changes the VMT link of a class instance: its type). The alias stays because of the
  order of the units in a uses clause: the units of DN (Collect...) that come before this one in a clause hide TvObjs, and a unit that
  adds TvObjs after them would take their names back. Written by us for DN. }
unit objutil;

{$mode objfpc}{$H-}

interface

uses
  TvObjs;

type
  TStreamable = TvObjs.TStreamable;

{ Free and O := nil (O is a variable containing a class reference; nil is allowed). }
procedure FreeObject(var O);

{ The new type of an existing object (NewType = TypeOf(a descendant with the same fields and no new fields)). }
procedure ObjChangeType(P: TStreamable; NewType: Pointer);

implementation

procedure FreeObject(var O);
var
  OO: TStreamable absolute O;
begin
  if OO <> nil then
  begin
    OO.Free;
    OO := nil;
  end;
end;

procedure ObjChangeType(P: TStreamable; NewType: Pointer);
begin
  PPointer(P)^ := NewType;
end;

end.
