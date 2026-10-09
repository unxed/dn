{ The collections of DN that differ from those of tv/ (the interface part of the unit Collect): the sorted
  collection has Sort/QSort/QuickSort, the string collections can hold long strings (Init gets ALongStrings),
  there are collections of lines and of zero-terminated strings. The items of a string collection are pointers to
  ShortStrings (PStr), with ALongStrings to AnsiStrings (PLongString).
  In the streams (opstream, ipstream) they are 'Collect.TStringCollection', 'Collect.TStrCollection' and 'Collect.TLineCollection'. }
type
  TSortedCollection = class;

  TSortedCollection = class(TvObjs.TSortedCollection)
    procedure Sort;
    procedure QSort;
    procedure QuickSort(L, R: LongInt);
  end;

  TStringCollection = class;

  TStringCollection = class(TSortedCollection)
    LongStrings: Boolean;
    constructor Create(ALimit, ADelta: LongInt; ALongStrings: Boolean); overload;
    function Compare(Key1, Key2: Pointer): Integer; override;
    procedure FreeItem(Item: Pointer); override;
    function ReadItem(Ip: ipstream): Pointer; override;
    procedure WriteItem(Item: Pointer; Os: opstream); override;
    function StreamableName: ShortString; override;
  public
    class function Build: TStreamable; static;
  end;

  { a collection of streamable items (or nil): an item is written by WritePointer and read by ReadPointer }
  TObjCollection = class;

  TObjCollection = class(TCollection)
  protected
    function ReadItem(Ip: ipstream): Pointer; override;
    procedure WriteItem(Item: Pointer; Os: opstream); override;
    function StreamableName: ShortString; override;
  public
    class function Build: TStreamable; static;
  end;

  { a collection that a list box shows (TListBox takes a TCollection) and that no stream holds: reading or writing
    its items is the error peNotRegistered (EStreamableError), as for a TNSCollection }
  TNoStreamCollection = class;

  TNoStreamCollection = class(TCollection)
  protected
    function ReadItem(Ip: ipstream): Pointer; override;
    procedure WriteItem(Item: Pointer; Os: opstream); override;
  end;

  { not sorted: Insert appends }
  TUnSortedStrCollection = class;

  TUnSortedStrCollection = class(TStringCollection)
    procedure Insert(Item: Pointer); override;
  end;

  { the items are zero-terminated strings (PChar) }
  TStrCollection = class;

  TStrCollection = class(TSortedCollection)
    function Compare(Key1, Key2: Pointer): Integer; override;
    procedure FreeItem(Item: Pointer); override;
    function ReadItem(Ip: ipstream): Pointer; override;
    procedure WriteItem(Item: Pointer; Os: opstream); override;
    function StreamableName: ShortString; override;
  public
    class function Build: TStreamable; static;
  end;

  { a collection of lines (not sorted) }
  TLineCollection = class;

  TLineCollection = class(TCollection)
    LongStrings: Boolean;
    constructor Create(ALimit, ADelta: LongInt; ALongStrings: Boolean); overload;
    procedure FreeItem(Item: Pointer); override;
    function ReadItem(Ip: ipstream): Pointer; override;
    procedure WriteItem(Item: Pointer; Os: opstream); override;
    function StreamableName: ShortString; override;
  public
    class function Build: TStreamable; static;
  end;

  { a collection of the names of directories: the names are compared without the case }
  TDirCol = class;
  PDirCol = TDirCol;
  TDirCol = class(TStringCollection)
    function Compare(Key1, Key2: Pointer): Integer; override;
  end;
