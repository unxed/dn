{ The collections of DN that differ from those of tv/ (the interface part of the unit Collect): the sorted
  collection has Sort/QSort/QuickSort, the string collections can hold long strings (Init gets ALongStrings),
  there are collections of lines and of zero-terminated strings. The items of a string collection are pointers to
  ShortStrings (PStr), with ALongStrings to AnsiStrings (PLongString).
  TODO: the streams of the long strings, the resource collections. }
type
  PSortedCollection = ^TSortedCollection;
  TSortedCollection = object(TvObjs.TSortedCollection)
    procedure Sort;
    procedure QSort;
    procedure QuickSort(L, R: LongInt);
  end;

  PStringCollection = ^TStringCollection;
  TStringCollection = object(TSortedCollection)
    LongStrings: Boolean;
    constructor Init(ALimit, ADelta: LongInt; ALongStrings: Boolean);
    function Compare(Key1, Key2: Pointer): Integer; virtual;
    procedure FreeItem(Item: Pointer); virtual;
    function GetItem(var S: TStream): Pointer; virtual;
    procedure PutItem(var S: TStream; Item: Pointer); virtual;
  end;

  { not sorted: Insert appends }
  PUnSortedStrCollection = ^TUnSortedStrCollection;
  TUnSortedStrCollection = object(TStringCollection)
    procedure Insert(Item: Pointer); virtual;
  end;

  { the items are zero-terminated strings (PChar) }
  PStrCollection = ^TStrCollection;
  TStrCollection = object(TSortedCollection)
    function Compare(Key1, Key2: Pointer): Integer; virtual;
    procedure FreeItem(Item: Pointer); virtual;
  end;

  { a collection of lines (not sorted) }
  PLineCollection = ^TLineCollection;
  TLineCollection = object(TCollection)
    LongStrings: Boolean;
    constructor Init(ALimit, ADelta: LongInt; ALongStrings: Boolean);
    procedure FreeItem(Item: Pointer); virtual;
  end;
