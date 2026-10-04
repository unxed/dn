{ The collections of DN that differ from those of tv/ (the interface part of the unit Collect): the sorted
  collection has Sort/QSort/QuickSort, the string collections can hold long strings (Init gets ALongStrings),
  there are collections of lines and of zero-terminated strings. The items of a string collection are pointers to
  ShortStrings (PStr), with ALongStrings to AnsiStrings (PLongString).
  TODO: the streams of the long strings, the resource collections. }
type
  TSortedCollection = class;
  PSortedCollection = TSortedCollection;
  TSortedCollection = class(TvObjs.TSortedCollection)
    procedure Sort;
    procedure QSort;
    procedure QuickSort(L, R: LongInt);
  end;

  TStringCollection = class;
  PStringCollection = TStringCollection;
  TStringCollection = class(TSortedCollection)
    LongStrings: Boolean;
    constructor Create(ALimit, ADelta: LongInt; ALongStrings: Boolean);
    function Compare(Key1, Key2: Pointer): Integer; override;
    procedure FreeItem(Item: Pointer); override;
    function GetItem(S: TStream): Pointer; override;
    procedure PutItem(S: TStream; Item: Pointer); override;
  end;

  { not sorted: Insert appends }
  TUnSortedStrCollection = class;
  PUnSortedStrCollection = TUnSortedStrCollection;
  TUnSortedStrCollection = class(TStringCollection)
    procedure Insert(Item: Pointer); override;
  end;

  { the items are zero-terminated strings (PChar) }
  TStrCollection = class;
  PStrCollection = TStrCollection;
  TStrCollection = class(TSortedCollection)
    function Compare(Key1, Key2: Pointer): Integer; override;
    procedure FreeItem(Item: Pointer); override;
    function GetItem(S: TStream): Pointer; override;
    procedure PutItem(S: TStream; Item: Pointer); override;
  end;

  { a collection of lines (not sorted) }
  TLineCollection = class;
  PLineCollection = TLineCollection;
  TLineCollection = class(TCollection)
    LongStrings: Boolean;
    constructor Create(ALimit, ADelta: LongInt; ALongStrings: Boolean);
    procedure FreeItem(Item: Pointer); override;
    function GetItem(S: TStream): Pointer; override;
    procedure PutItem(S: TStream; Item: Pointer); override;
  end;

  { a collection of the names of directories: the names are compared without the case }
  TDirCol = class;
  PDirCol = TDirCol;
  TDirCol = class(TStringCollection)
    function Compare(Key1, Key2: Pointer): Integer; override;
  end;
