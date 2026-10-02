{ The resource types of DN that its own Streams unit had (the interface part of the unit Streams).
  TODO: resources are not loaded yet (tv/ has no Load/Store of views): these are stubs with the names and the
  calls that DN makes; Get gives nil / an empty string. }
const
  { the sharing bits of the open mode of a file (DOS: the bits 4..7 of the mode; VP has the same names); TDosStream of
    tv/ ignores them (DN: Init(Name, (stOpenRead and fmDeny) or fmDenyWrite) asks for "deny write") }
  fmDenyAll = $10;
  fmDenyWrite = $20;
  fmDenyRead = $30;
  fmDenyNone = $40;
  fmDeny = $70;
  fmDenyChild = $80;

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
