{ The unit baseobjs of DN over tv/: DN has its own TEmptyObject/TObject there (the objects "taken out of the
  library"); here they are the TObject of tv/ (TvObjs), so that the views and the other objects of DN have one root.
  ObjChangeType changes the VMT link of an object (its type): the first pointer of the instance (an object type that
  has virtual methods; see tv/DESIGN.md on the VMT). }
unit baseobjs;

{$mode objfpc}{$H-}

interface

uses
  TvObjs;

type
  PObject = TvObjs.PObject;
  TObject = TvObjs.TObject;

{ Dispose(O, Done) and O := nil (O is a variable of a pointer to an object; nil is allowed). }
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
    Dispose(OO, Done);
    OO := nil;
  end;
end;

procedure ObjChangeType(P: PObject; NewType: Pointer);
begin
  PPointer(P)^ := NewType;
end;

end.
