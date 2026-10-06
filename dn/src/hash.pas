unit Hash;

interface
uses
  Collect, objutil;

type
  THashIndex = Longint;
  THashTable = array[0..0] of THashIndex;

  THash = class;
  {`2 Hash table, auxiliary to a collection. Created after
  the collection is filled, since it requires knowing the final
  number of elements. Used for very fast search
  of an element in a collection, usually unsorted.
     Collisions are resolved by rehashing,
  so hash-table overflow is absolutely inadmissible,
  and nearly full occupancy is highly undesirable.
    Hash-table size is a power of 2 exceeding the number of elements
  by 10% or more. If there is not enough memory to create such a table,
  after Init HT=nil.
  `}
  THash = class
    HT: ^THashTable;
      {` Hash table.
      Contains indices into Items^ or EmptyIndex (free) `}
    Count: Integer;
      {` Number of HT elements`}
    Items: PItemList;
      {` Copy of the collection Items `}
    hf: integer;
      {` Index into HT, 0..Count-1 `}
    RehashStep: integer;
      {` Rehash step of the last search. Rehashing
      is done by adding this step modulo HT size.
      The step must be coprime with Count, i.e., since
      Count is a power of two, RehashStep must be odd `}
    procedure Hash(Item: Pointer); virtual;
      {` Based on Item^ contents, compute the starting
      hash index hf and the rehash step RehashStep.
      This method must be overridden.`}
    function Equal(Item1, Item2: Pointer): Boolean; virtual;
      {` Whether keys Item1^ and Item2^ match.
      This method must be overridden. `}
    constructor Create(BaseColl: TCollection);
      {` allocate memory for HT^ and clear HT `}
    function GetHashIndex(Item: Pointer; var N: THashIndex): Boolean;
      {` Search for an element in the hash table.
      If found (result True) N is the index in HT.
      If not found (result False) N is the index in HT where
      it should be written. `}
    function AddItem(CollIndex: Integer): Boolean;
      {` Write a new element Items^[CollIndex]^ into the hash table.
      Result False if an element with such a key already exists `}
    destructor Destroy; override;
    end;

implementation

const
  EmptyIndex = $FFFFFFFF;

constructor THash.Create(BaseColl: TCollection);
  var
    Size: Longint;
    MinCount: Integer;
  begin
  inherited Create;
  MinCount := BaseColl.Count * 11 div 10; // 10% reserve
  Count := 1024;
  while Count < MinCount do
    Count := Count*2;
  Size := Count * SizeOf(Longint);
  GetMem(HT, Size);
  if HT <> nil then
    FillChar(HT^, Size, $FF);
  Items := BaseColl.Items;
  end;

destructor THash.Destroy;
  begin
  if HT <> nil then
    FreeMem(HT);
  inherited Destroy;
  end;

procedure THash.Hash(Item: Pointer);
  begin
  RunError(211);
  end;

function THash.Equal(Item1, Item2: Pointer): Boolean;
  begin
  RunError(211);
  end;

function THash.GetHashIndex(Item: Pointer; var N: THashIndex): Boolean;
  begin
  Hash(Item);
  while True do
    begin
    N := HT^[hf];
    if N = EmptyIndex then
      begin
      Result := False;
      Break; { not found }
      end;
    if Equal(Item, Items^[N]) then
      begin
      Result := True;
      Break; { found }
      end;
    { rehash }
    hf := (hf + RehashStep) mod Count;
    end;
  { not found }
  end;

function THash.AddItem(CollIndex: Integer): Boolean;
  var
    N: THashIndex;
  begin
  Result := not GetHashIndex(Items^[CollIndex], N);
  if Result then
    HT^[hf] := CollIndex;
  end;

end.
