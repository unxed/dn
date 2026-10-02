{ The resource types of DN that its own Streams unit had (the interface part of the unit Streams).
  TODO: resources are not loaded yet (tv/ has no Load/Store of views): these are stubs with the names and the
  calls that DN makes; Get gives nil / an empty string. }
type
  PStringList = ^TStringList;
  TStringList = object(TObject)
    { the string with the number Key of the resource; '' if there is none }
    function Get(Key: Word): String;
  end;

  PIdxResource = ^TIdxResource;
  TIdxResource = object(TObject)
    { the object with the index Key in the resource; nil if there is none }
    function Get(Key: LongInt): PObject;
  end;
