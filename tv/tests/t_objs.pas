program t_objs;
{$I ../src/tvdefs.inc}
uses SysUtils, TvUtil, TvObjs;
{$I testlib.inc}

type
  PA = ^TA;
  TA = object(TObject)
    A: Integer;
    B: array[0..9] of Byte;
    constructor Init;
  end;
  PB = ^TB;
  TB = object(TA)
    C: Int64;
    D: PObject;
    constructor Init;
  end;

  { a streamable point }
  PPt = ^TPt;
  TPt = object(TObject)
    X, Y: Integer;
    constructor Create(AX, AY: Integer);
    procedure Store(var S: TStream);
  end;

  { a collection that records its errors instead of stopping the program }
  PSafeColl = ^TSafeColl;
  TSafeColl = object(TCollection)
    LastCode, LastInfo, Errors: Integer;
    procedure Error(Code, Info: Integer); virtual;
    procedure FreeItem(Item: Pointer); virtual;
  end;

  PIntColl = ^TIntColl;
  TIntColl = object(TSortedCollection)
    function Compare(Key1, Key2: Pointer): Integer; virtual;
    procedure FreeItem(Item: Pointer); virtual;
  end;

var
  Freed: Integer = 0;
  Sum: Integer = 0;

constructor TA.Init;
begin
  inherited Init;
end;

constructor TB.Init;
begin
  inherited Init;
end;

constructor TPt.Create(AX, AY: Integer);
begin
  inherited Init;
  X := AX;
  Y := AY;
end;

procedure TPt.Store(var S: TStream);
begin
  S.Write(X, SizeOf(X));
  S.Write(Y, SizeOf(Y));
end;

function LoadPt(var S: TStream): PObject;
var
  P: PPt;
begin
  New(P, Create(0, 0));
  S.Read(P^.X, SizeOf(Integer));
  S.Read(P^.Y, SizeOf(Integer));
  Result := P;
end;

procedure StorePt(P: PObject; var S: TStream);
begin
  PPt(P)^.Store(S);
end;

var
  RPt: TStreamRec;

procedure TSafeColl.Error(Code, Info: Integer);
begin
  LastCode := Code;
  LastInfo := Info;
  Inc(Errors);
end;

procedure TSafeColl.FreeItem(Item: Pointer);
begin
  { the items are numbers, not objects }
end;

procedure TIntColl.FreeItem(Item: Pointer);
begin
end;

function TIntColl.Compare(Key1, Key2: Pointer): Integer;
begin
  if PtrInt(Key1) < PtrInt(Key2) then
    Result := -1
  else if PtrInt(Key1) > PtrInt(Key2) then
    Result := 1
  else
    Result := 0;
end;

function IsBig(Item: Pointer): Boolean;
begin
  Result := PtrInt(Item) > 50;
end;

procedure AddTo(Item: Pointer);
begin
  Inc(Sum, PtrInt(Item));
end;

const
  TmpName = 'T_OBJS.TMP';

var
  X: TB;
  M, M2: TMemoryStream;
  F: TDosStream;
  BF: TBufStream;
  Buf: array[0..9999] of Byte;
  Back: array[0..9999] of Byte;
  I: Integer;
  P: PStr;
  W: Word;
  Ok: Boolean;
  Used0: PtrUInt;
  C: PSafeColl;
  IC: PIntColl;
  SC: PStringCollection;
  PC: PCollection;
  Pt: PPt;
  O: PObject;
  Dummy: TObject;
  Bytes: array[0..3] of Byte;

begin
  Used0 := GetFPCHeapStatus.CurrHeapUsed;

  { --- TObject.Init zeroes the descendants ------------------------------------- }
  { SizeOf of a variable of an object type with a VMT reads the VMT: use the type }
  FillChar((PByte(@X) + SizeOf(Pointer))^, SizeOf(TB) - SizeOf(Pointer), $FF);
  X.Init;
  Ok := (X.A = 0) and (X.C = 0) and (X.D = nil);
  for I := 0 to 9 do
    if X.B[I] <> 0 then Ok := False;
  Check(Ok, 'Init zeroes the fields of the type and of its ancestors');
  X.Done;

  { --- memory stream ------------------------------------------------------------ }
  M.Init(0, 16);
  Check((M.GetPos = 0) and (M.GetSize = 0) and (M.Status = stOk), 'a new memory stream is empty');
  I := 12345;
  M.Write(I, SizeOf(I));
  Check((M.GetPos = 4) and (M.GetSize = 4), 'Write moves the position');
  M.Seek(0);
  I := 0;
  M.Read(I, SizeOf(I));
  Check((I = 12345) and (M.Status = stOk), 'Read gives it back');
  M.Read(I, SizeOf(I));
  Check((M.Status = stReadError) and (I = 0), 'Read past the end: stReadError and zeros');
  M.Reset;
  Check((M.Status = stOk) and (M.ErrorInfo = 0), 'Reset');
  for I := 0 to 9999 do
    Buf[I] := Byte(I * 7);
  M.Seek(0);
  M.Write(Buf, 10000);
  Check(M.GetSize = 10000, 'a stream grows over many blocks');
  M.Seek(5000);
  M.Read(Back, 100);
  Check(CompareByte(Back, Buf[5000], 100) = 0, 'and keeps its contents');
  M.Seek(20000);
  M.Write(I, 1);
  Check(M.GetSize = 20001, 'writing far beyond the end grows it');
  M.Seek(15000);
  M.Read(Bytes, 4);
  Check((Bytes[0] = 0) and (Bytes[3] = 0), 'the gap is zeros');
  M.Seek(100);
  M.Truncate;
  Check(M.GetSize = 100, 'Truncate cuts at the position');

  { strings }
  M.Seek(0);
  M.Truncate;
  P := NewStr('Привет');
  M.WriteStr(P);
  M.WriteStr(nil);
  DisposeStr(P);
  M.Seek(0);
  P := M.ReadStr;
  Check((P <> nil) and (P^ = 'Привет'), 'WriteStr and ReadStr');
  DisposeStr(P);
  P := M.ReadStr;
  Check(P = nil, 'a nil string is an empty one');

  { CopyFrom }
  M2.Init(0, 64);
  M.Seek(0);
  M2.CopyFrom(M, M.GetSize);
  Check((M2.GetSize = M.GetSize) and (M2.Status = stOk), 'CopyFrom copies the bytes');
  M2.Done;
  M.Done;

  { --- file streams -------------------------------------------------------------- }
  F.Init(TmpName, stCreate);
  Check(F.Status = stOk, 'a file is created');
  F.Write(Buf, 10000);
  Check((F.GetPos = 10000) and (F.GetSize = 10000), 'TDosStream: position and size');
  F.Seek(9000);
  F.Read(Back, 500);
  Check(CompareByte(Back, Buf[9000], 500) = 0, 'TDosStream: Seek and Read');
  F.Seek(9990);
  F.Read(Back, 100);
  Check(F.Status = stReadError, 'TDosStream: reading past the end');
  F.Reset;
  F.Seek(50);
  F.Truncate;
  Check(F.GetSize = 50, 'TDosStream: Truncate');
  F.Done;
  F.Init('NO_SUCH.DIR/NOFILE.TMP', stOpenRead);
  Check(F.Status = stInitError, 'opening a missing file: stInitError');
  F.Done;

  { buffered: more bytes than the buffer holds, in odd pieces }
  BF.Init(TmpName, stCreate, 256);
  for I := 0 to 99 do
    BF.Write(Buf[I * 100], 100);
  Check(BF.GetPos = 10000, 'TBufStream: position after many writes');
  Check(BF.GetSize = 10000, 'TBufStream: size');
  BF.Seek(0);
  I := 0;
  Ok := True;
  while I + 37 <= 10000 do
  begin
    BF.Read(Back[I], 37);
    I := I + 37;
  end;
  Check(BF.Status = stOk, 'TBufStream: reads in odd pieces');
  BF.Seek(0);
  BF.Read(Back, 10000);
  Check(CompareByte(Back, Buf, 10000) = 0, 'TBufStream: everything comes back');
  { change bytes in the middle, far from the buffer }
  Bytes[0] := $AA; Bytes[1] := $BB;
  BF.Seek(5001);
  BF.Write(Bytes, 2);
  BF.Seek(0);
  BF.Seek(7000);
  BF.Seek(5000);
  BF.Read(Back, 4);
  Check((Back[0] = Buf[5000]) and (Back[1] = $AA) and (Back[2] = $BB) and (Back[3] = Buf[5003]),
    'TBufStream: rewriting in the middle keeps the neighbours');
  BF.Done;
  F.Init(TmpName, stOpenRead);
  Check(F.GetSize = 10000, 'TBufStream: Done writes the buffer');
  F.Seek(5000);
  F.Read(Back, 4);
  Check((Back[1] = $AA) and (Back[2] = $BB) and (Back[0] = Buf[5000]), 'the file has the change');
  F.Done;
  { append to an existing file }
  BF.Init(TmpName, stOpen, 64);
  BF.Seek(BF.GetSize);
  BF.Write(Buf, 10);
  Check(BF.GetSize = 10010, 'TBufStream: append');
  BF.Done;
  F.Init(TmpName, stOpenRead);
  Check(F.GetSize = 10010, 'the appended file has the new size');
  F.Done;
  DeleteFile(TmpName);

  { --- registered types: Get and Put -------------------------------------------------- }
  FillChar(RPt, SizeOf(RPt), 0);
  RPt.ObjType := 4001;
  RPt.VmtLink := PtrUInt(TypeOf(TPt));
  RPt.Load := @LoadPt;
  RPt.Store := @StorePt;
  RegisterType(RPt);
  Check(FindStreamRec(4001) = @RPt, 'RegisterType');
  M.Init(0, 64);
  New(Pt, Create(3, -4));
  M.Put(Pt);
  M.Put(nil);
  Pt^.X := 99;
  M.Put(Pt);
  Dispose(Pt, Done);
  Check(M.Status = stOk, 'Put of a registered type');
  M.Seek(0);
  O := M.Get;
  Check((O <> nil) and (PPt(O)^.X = 3) and (PPt(O)^.Y = -4), 'Get makes the object again');
  O^.Free;
  Check(M.Get = nil, 'a nil object');
  O := M.Get;
  Check((O <> nil) and (PPt(O)^.X = 99), 'the next object');
  O^.Free;
  Dummy.Init;
  M.Put(@Dummy);
  Check(M.Status = stPutError, 'Put of a type that is not registered: stPutError');
  M.Reset;
  W := 7777;
  M.Seek(0);
  M.Truncate;
  M.Write(W, 2);
  M.Seek(0);
  Check((M.Get = nil) and (M.Status = stGetError) and (M.ErrorInfo = 7777), 'Get of an unknown number: stGetError');
  M.Done;
  Dummy.Done;
  Check(True, 'a number registered twice is ignored');
  RegisterType(RPt);
  Check(FindStreamRec(4001) = @RPt, 'the registry is not damaged');

  { --- collections ----------------------------------------------------------------------- }
  New(C, Init(2, 2));
  Check((C^.Count = 0) and (C^.Limit = 2) and (C^.Delta = 2), 'a new collection');
  C^.Insert(Pointer(10));
  C^.Insert(Pointer(20));
  C^.Insert(Pointer(30));
  Check((C^.Count = 3) and (C^.Limit = 4), 'the limit grows by Delta');
  C^.AtInsert(1, Pointer(15));
  Check((C^.At(1) = Pointer(15)) and (C^.At(2) = Pointer(20)) and (C^.Count = 4), 'AtInsert');
  Check(C^.IndexOf(Pointer(30)) = 4 - 1, 'IndexOf');
  Check(C^.IndexOf(Pointer(77)) = -1, 'IndexOf: not there');
  C^.AtPut(0, Pointer(11));
  Check(C^.At(0) = Pointer(11), 'AtPut');
  C^.Delete(Pointer(15));
  Check((C^.Count = 3) and (C^.At(1) = Pointer(20)), 'Delete');
  C^.AtDelete(0);
  Check((C^.Count = 2) and (C^.At(0) = Pointer(20)), 'AtDelete');
  C^.Insert(Pointer(60));
  C^.Insert(Pointer(70));
  Check(C^.FirstThat(@IsBig) = Pointer(60), 'FirstThat');
  Check(C^.LastThat(@IsBig) = Pointer(70), 'LastThat');
  Check(C^.FirstThat(@IsBig) <> nil, 'FirstThat finds something');
  Sum := 0;
  C^.ForEach(@AddTo);
  Check(Sum = 20 + 30 + 60 + 70, 'ForEach');
  C^.AtPut(1, nil);
  C^.Pack;
  Check((C^.Count = 3) and (C^.At(1) = Pointer(60)), 'Pack removes the nil items');
  C^.At(10);
  Check((C^.Errors = 1) and (C^.LastCode = coIndexError) and (C^.LastInfo = 10), 'At: index error');
  C^.AtInsert(99, Pointer(1));
  Check(C^.Errors = 2, 'AtInsert: index error');
  C^.DeleteAll;
  Check(C^.Count = 0, 'DeleteAll');
  Dispose(C, Done);
  { a collection that cannot grow }
  New(C, Init(1, 0));
  C^.Insert(Pointer(1));
  C^.Insert(Pointer(2));
  Check((C^.Errors = 1) and (C^.LastCode = coOverflow) and (C^.Count = 1), 'a full collection with Delta 0: coOverflow');
  Dispose(C, Done);

  { objects in a collection are freed by FreeAll and Done }
  New(PC, Init(2, 2));
  for I := 1 to 5 do
  begin
    New(Pt, Create(I, I));
    PC^.Insert(Pt);
  end;
  PC^.AtFree(0);
  Check(PC^.Count = 4, 'AtFree');
  PC^.Free(PC^.At(0));
  Check(PC^.Count = 3, 'Free');
  Dispose(PC, Done);

  { sorted }
  New(IC, Init(4, 4));
  IC^.Insert(Pointer(30));
  IC^.Insert(Pointer(10));
  IC^.Insert(Pointer(20));
  IC^.Insert(Pointer(20));
  Check((IC^.Count = 3) and (IC^.At(0) = Pointer(10)) and (IC^.At(1) = Pointer(20)) and (IC^.At(2) = Pointer(30)),
    'a sorted collection keeps its order and drops duplicates');
  Check(IC^.IndexOf(Pointer(30)) = 2, 'sorted IndexOf');
  Check(IC^.IndexOf(Pointer(25)) = -1, 'sorted IndexOf: not there');
  Check((not IC^.Search(Pointer(25), I)) and (I = 2), 'Search: where it would go');
  Check(IC^.Search(Pointer(10), I) and (I = 0), 'Search: found');
  IC^.Duplicates := True;
  IC^.Insert(Pointer(20));
  Check((IC^.Count = 4) and (IC^.At(1) = Pointer(20)) and (IC^.At(2) = Pointer(20)), 'with Duplicates: both stay');
  Dispose(IC, Done);

  { strings }
  New(SC, Init(4, 4));
  P := NewStr('pear'); SC^.Insert(P);
  P := NewStr('apple'); SC^.Insert(P);
  P := NewStr('fig'); SC^.Insert(P);
  P := NewStr('apple');
  if SC^.Search(P, I) then DisposeStr(P) else SC^.Insert(P);   { the collection takes what it keeps }
  Check(SC^.Count = 3, 'duplicates are dropped');
  Check((PStr(SC^.At(0))^ = 'apple') and (PStr(SC^.At(1))^ = 'fig') and (PStr(SC^.At(2))^ = 'pear'), 'sorted strings');
  P := NewStr('fig');
  Check((SC^.IndexOf(P) = 1), 'IndexOf compares the contents');
  DisposeStr(P);
  { Store and Load through a stream }
  M.Init(0, 64);
  SC^.Store(M);
  Check(M.Status = stOk, 'Store of a string collection');
  Dispose(SC, Done);
  M.Seek(0);
  New(SC, Load(M));
  Check((SC^.Count = 3) and (PStr(SC^.At(2))^ = 'pear') and (PStr(SC^.At(0))^ = 'apple'), 'Load gives the strings back');
  Dispose(SC, Done);
  M.Done;
  { a collection of registered objects through a stream }
  New(PC, Init(2, 2));
  New(Pt, Create(5, 6)); PC^.Insert(Pt);
  New(Pt, Create(7, 8)); PC^.Insert(Pt);
  M.Init(0, 64);
  PC^.Store(M);
  Dispose(PC, Done);
  M.Seek(0);
  New(PC, Load(M));
  Check((PC^.Count = 2) and (PPt(PC^.At(1))^.X = 7) and (PPt(PC^.At(0))^.Y = 6), 'a collection of objects through a stream');
  Dispose(PC, Done);
  M.Done;

  Check(GetFPCHeapStatus.CurrHeapUsed = Used0, 'no memory is left behind');
  Finish;
end.
