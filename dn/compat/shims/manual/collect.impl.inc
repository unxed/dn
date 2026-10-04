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

constructor TStringCollection.Create(ALimit, ADelta: LongInt; ALongStrings: Boolean);
begin
  inherited Create(ALimit, ADelta);
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

function TStringCollection.GetItem(S: TStream): Pointer;
begin
  if LongStrings then
    Result := S.ReadLongStr
  else
    Result := S.ReadStr;
end;

procedure TStringCollection.PutItem(S: TStream; Item: Pointer);
begin
  if LongStrings then
    S.WriteLongStr(PLongString(Item))
  else
    S.WriteStr(PStr(Item));
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

constructor TLineCollection.Create(ALimit, ADelta: LongInt; ALongStrings: Boolean);
begin
  inherited Create(ALimit, ADelta);
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

function TLineCollection.GetItem(S: TStream): Pointer;
begin
  if LongStrings then
    Result := S.ReadLongStr
  else
    Result := S.ReadStr;
end;

procedure TLineCollection.PutItem(S: TStream; Item: Pointer);
begin
  if LongStrings then
    S.WriteLongStr(PLongString(Item))
  else
    S.WriteStr(PStr(Item));
end;

function TStrCollection.GetItem(S: TStream): Pointer;
begin
  Result := S.StrRead;
end;

procedure TStrCollection.PutItem(S: TStream; Item: Pointer);
begin
  S.StrWrite(PChar(Item));
end;

function TDirCol.Compare(Key1, Key2: Pointer): Integer;
begin
  if LongStrings then
    Result := CompareText(PLongString(Key1)^, PLongString(Key2)^)
  else
    Result := CompareText(PStr(Key1)^, PStr(Key2)^);
end;
