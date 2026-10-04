{ objutil: the classes of DN over tv/. TStreamable is the streamable-class root of tv/ (TvObjs); it is re-exported here
  for the old unit order. ObjChangeType is the remaining resource-retyping entry point.
  It must be replaced by creation of the registered subclass before the migration is complete.
  The alias stays because of the
  order of the units in a uses clause: the units of DN (Collect...) that come before this one in a clause hide TvObjs, and a unit that
  adds TvObjs after them would take their names back. Written by us for DN. }
unit objutil;

{$mode objfpc}{$H-}

interface

uses
  TvObjs;

type
  TStreamable = TvObjs.TStreamable;

{ The new type of an existing class instance (NewType = TypeOf(a descendant with the same fields and no new fields)). }
procedure ObjChangeType(P: TStreamable; NewType: Pointer);

implementation

procedure ObjChangeType(P: TStreamable; NewType: Pointer);
begin
  PPointer(P)^ := NewType;
end;

end.
