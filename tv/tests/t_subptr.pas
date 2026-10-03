program t_subptr;
{ A group that stores a pointer to one of its OWN views after "inherited Store" and reads it back after "inherited Load" with
  GetSubViewPtr (the way TDoubleWindow of DN does: Separator, the panels). The pointer must be the loaded view at once;
  the bug it guards against: it stayed nil (the pointer went to the list of fixups of an enclosing group, which was gone), and a
  desktop saved with "Save desktop" could not be loaded ("Error reading desktop file"). }
{$I ../src/tvdefs.inc}
uses TvGeom, TvEvents, TvScreen, TvObjs, TvUtil, TvViews, TvWindow, TvDialog;
{$I testlib.inc}

type
  PTwoGroup = ^TTwoGroup;
  TTwoGroup = object(TGroup)
    PtrA, PtrB: PView;       { two of the views of the group }
    PtrC: PView;               { not a view of the group }
    constructor Load(var S: TStream);
    procedure Store(var S: TStream);
  end;

constructor TTwoGroup.Load(var S: TStream);
begin
  inherited Load(S);
  GetSubViewPtr(S, PtrA);
  GetSubViewPtr(S, PtrB);
  GetSubViewPtr(S, PtrC);
end;

procedure TTwoGroup.Store(var S: TStream);
begin
  inherited Store(S);
  PutSubViewPtr(S, PtrA);
  PutSubViewPtr(S, PtrB);
  PutSubViewPtr(S, PtrC);
end;

function BuildTwo(var S: TStream): PObject;
begin
  Result := New(PTwoGroup, Load(S));
end;

procedure StoreTwo(P: PObject; var S: TStream);
begin
  PTwoGroup(P)^.Store(S);
end;

function R(A, B, C, D: Integer): TRect;
begin
  Result.Assign(A, B, C, D);
end;

var
  RTwo: TStreamRec;
  G, L: PTwoGroup;
  M: TMemoryStream;
  V1, V2, V3: PView;
  Outside: PView;
begin
  ScreenCreate(80, 25);
  RegisterType(RView);
  RegisterType(RGroup);
  RegisterType(RFrame);
  RegisterType(RWindow);
  RegisterType(RStaticText);
  RTwo.ObjType := 4701;
  RTwo.VmtLink := PtrUInt(TypeOf(TTwoGroup));
  RTwo.Load := @BuildTwo;
  RTwo.Store := @StoreTwo;
  RegisterType(RTwo);

  New(G, Init(R(0, 0, 40, 10)));
  V1 := New(PStaticText, Init(R(1, 1, 10, 2), 'one'));
  V2 := New(PStaticText, Init(R(1, 3, 10, 4), 'two'));
  V3 := New(PStaticText, Init(R(1, 5, 10, 6), 'three'));
  G^.Insert(V1);
  G^.Insert(V2);
  G^.Insert(V3);
  G^.PtrA := V3;               { not the first by the order of insertion: the index must not be 1 }
  G^.PtrB := V1;
  G^.PtrC := nil;
  Outside := New(PStaticText, Init(R(1, 7, 10, 8), 'outside'));
  M.Init(0, 1024);
  M.Put(G);
  Check(M.Status = stOk, 'the group is stored');
  M.Seek(0);
  L := PTwoGroup(M.Get);
  Check((L <> nil) and (M.Status = stOk), 'the group is loaded');
  Check((L <> nil) and (L^.PtrA <> nil) and (PStaticText(L^.PtrA)^.Text^ = 'three'),
    'GetSubViewPtr after inherited Load gives the view of the group at once (PtrA)');
  Check((L <> nil) and (L^.PtrB <> nil) and (PStaticText(L^.PtrB)^.Text^ = 'one'), 'and the second pointer');
  Check((L <> nil) and (L^.PtrC = nil), 'a nil pointer stays nil');
  Check((L <> nil) and (L^.PtrA <> nil) and (L^.PtrA^.Owner = PGroup(L)) and (L^.PtrB^.Owner = PGroup(L)) and (L^.PtrA <> V3) and (L^.PtrB <> V1),
    'they are views of the loaded group, not of the stored one');
  Dispose(L, Done);
  Dispose(G, Done);
  Dispose(Outside, Done);
  M.Done;
  ScreenDestroy;
  Finish;
end.
