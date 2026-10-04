{ objutil: the classes of DN over tv/. The TObject of DN is the TObject of tv/ (TvObjs): here are the two names as aliases (DN's own
  TObject was taken out of the library; the original is dn/exclude.list) and two helpers that tv/ does not have: FreeObject
  (Free and O := nil) and ObjChangeType (changes the VMT link of an object: its type). The aliases stay because of the
  order of the units in a uses clause: the units of DN (Collect...) that come before this one in a clause hide TvObjs, and a unit that
  adds TvObjs after them would take their names back. }
unit objutil;

{$mode objfpc}{$H-}

interface

uses
  TvObjs;

type
  PObject = TvObjs.PObject;
  TObject = System.TObject;

{ Free and O := nil (O is a variable containing a class reference; nil is allowed). }
procedure FreeObject(var O);

{ The new type of an existing object (NewType = TypeOf(a descendant with the same fields and no new fields)). }
procedure ObjChangeType(P: PObject; NewType: Pointer);

implementation

procedure FreeObject(var O);
var
  OO: PObject absolute O;
begin
  if OO <> nil then
  begin
    OO.Free;
    OO := nil;
  end;
end;

procedure ObjChangeType(P: PObject; NewType: Pointer);
begin
  PPointer(P)^ := NewType;
end;

end.
