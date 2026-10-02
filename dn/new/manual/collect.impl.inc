procedure TSortedCollection.QuickSort(L, R: LongInt);
var
  I, J: LongInt;
  Pivot, T: Pointer;
begin
  repeat
    I := L;
    J := R;
    Pivot := Items^[(L + R) div 2];
    repeat
      while Compare(KeyOf(Items^[I]), KeyOf(Pivot)) < 0 do
        Inc(I);
      while Compare(KeyOf(Items^[J]), KeyOf(Pivot)) > 0 do
        Dec(J);
      if I <= J then
      begin
        T := Items^[I];
        Items^[I] := Items^[J];
        Items^[J] := T;
        Inc(I);
        Dec(J);
      end;
    until I > J;
    if L < J then
      QuickSort(L, J);
    L := I;
  until I >= R;
end;

procedure TSortedCollection.Sort;
begin
  if Count > 1 then
    QuickSort(0, Count - 1);
end;

procedure TSortedCollection.QSort;
begin
  Sort;
end;

constructor TStringCollection.Init(ALimit, ADelta: LongInt; ALongStrings: Boolean);
begin
  inherited Init(ALimit, ADelta);
  LongStrings := ALongStrings;
end;

function TStringCollection.Compare(Key1, Key2: Pointer): Integer;
begin
  if LongStrings then
  begin
    if PLongString(Key1)^ < PLongString(Key2)^ then Result := -1
    else if PLongString(Key1)^ > PLongString(Key2)^ then Result := 1
    else Result := 0;
  end
  else if PStr(Key1)^ < PStr(Key2)^ then Result := -1
  else if PStr(Key1)^ > PStr(Key2)^ then Result := 1
  else Result := 0;
end;

procedure TStringCollection.FreeItem(Item: Pointer);
begin
  if LongStrings then
    Dispose(PLongString(Item))
  else
    DisposeStr(PStr(Item));
end;

function TStringCollection.GetItem(var S: TStream): Pointer;
begin
  Result := S.ReadStr;      { TODO: long strings }
end;

procedure TStringCollection.PutItem(var S: TStream; Item: Pointer);
begin
  S.WriteStr(PStr(Item));   { TODO: long strings }
end;

procedure TUnSortedStrCollection.Insert(Item: Pointer);
begin
  AtInsert(Count, Item);
end;

function TStrCollection.Compare(Key1, Key2: Pointer): Integer;
begin
  Result := StrComp(PChar(Key1), PChar(Key2));
end;

procedure TStrCollection.FreeItem(Item: Pointer);
begin
  StrDispose(PChar(Item));
end;

constructor TLineCollection.Init(ALimit, ADelta: LongInt; ALongStrings: Boolean);
begin
  inherited Init(ALimit, ADelta);
  LongStrings := ALongStrings;
end;

procedure TLineCollection.FreeItem(Item: Pointer);
begin
  if Item = nil then
    Exit;
  if LongStrings then
    Dispose(PLongString(Item))
  else
    DisposeStr(PStr(Item));
end;
