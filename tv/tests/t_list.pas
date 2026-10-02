program t_list;
{$I ../src/tvdefs.inc}
uses TvGeom, TvCell, TvCodePg, TvEvents, TvKeys, TvViews, TvObjs, TvUtil, TvMem, TvApp,
  TvDialog, TvWindow, TvList;
{$I testlib.inc}

type
  PMyList = ^TMyList;
  TMyList = object(TListBox)
    Selected: Integer;
    procedure SelectItem(Item: Integer); virtual;
  end;

procedure TMyList.SelectItem(Item: Integer);
begin
  Selected := Item;
  inherited SelectItem(Item);
end;

function R(A, B, C, D: Integer): TRect;
begin
  Result.Assign(A, B, C, D);
end;

procedure Key(V: PView; Code: Word; Mods: Word = 0);
var
  E: TEvent;
begin
  MakeKeyEvent(E, Code, Mods);
  V^.HandleEvent(E);
end;

function Items(N: Integer): PCollection;
var
  C: PStringCollection;
  I: Integer;
  S: ShortString;
begin
  New(C, Init(N, 5));
  for I := 0 to N - 1 do
  begin
    Str(I, S);
    C^.AtInsert(C^.Count, NewStr('Item ' + S));
  end;
  Result := C;
end;

var
  App: PApplication;
  Dlg: PDialog;
  Bar: PScrollBar;
  L: PMyList;
  L2: PListBox;
  Used0: PtrUInt;
  Rec: TListBoxRec;
  L3: PListBox;
  Keep: PCollection;
  E: TEvent;

begin
  CpSelect(866);
  Used0 := GetFPCHeapStatus.CurrHeapUsed;
  MemInit(80, 25);
  New(App, Init);
  New(Dlg, Init(R(10, 5, 60, 14), 'List'));
  New(Bar, Init(R(20, 2, 21, 7)));
  Dlg^.Insert(Bar);
  New(L, Init(R(2, 2, 20, 7), 1, Bar));
  L^.Selected := -1;
  Dlg^.Insert(L);
  New(L2, Init(R(24, 2, 48, 5), 2, nil));
  Dlg^.Insert(L2);
  L^.Select;
  App^.InsertWindow(Dlg);

  Check((L^.Range = 0) and (L^.Focused = 0) and (L^.TopItem = 0), 'a new list is empty');
  Check((L^.Options and (ofFirstClick or ofSelectable)) = (ofFirstClick or ofSelectable), 'options');
  Check(MemText(8, 12, 19) = ' <empty>', 'an empty list shows <empty>');
  Check(Bar^.PgStep = 4, 'the page step of the scroll bar is the height minus one');

  L^.NewList(Items(12));
  Check((L^.Range = 12) and (L^.Focused = 0), 'NewList sets the range');
  Check((Bar^.MaxVal = 11) and (Bar^.Value = 0), 'and the range of the scroll bar');
  Check(MemText(8, 12, 18) = ' Item 0', 'the first row');
  Check(MemText(12, 12, 18) = ' Item 4', 'the last row');
  Check(L^.GetText(3, 255) = 'Item 3', 'GetText');
  Check(L^.GetText(3, 4) = 'Item', 'GetText cuts the text');

  Key(L, kbDown);
  Check((L^.Focused = 1) and (Bar^.Value = 1), 'Down focuses the next item');
  Key(L, kbUp);
  Key(L, kbUp);
  Check(L^.Focused = 0, 'Up stops at the first item');
  Key(L, kbPgDn);
  Check((L^.Focused = 5) and (L^.TopItem = 1), 'PgDn moves by a page and scrolls');
  Check(MemText(8, 12, 18) = ' Item 1', 'the list is scrolled');
  Key(L, kbEnd);
  Check(L^.Focused = L^.TopItem + 4, 'End goes to the last visible item');
  Key(L, kbHome);
  Check(L^.Focused = L^.TopItem, 'Home goes to the first visible item');
  Key(L, kbCtrlPgDn);
  Check((L^.Focused = 11) and (L^.TopItem = 7), 'Ctrl-PgDn goes to the end');
  Key(L, kbDown);
  Check(L^.Focused = 11, 'Down stops at the last item');
  Key(L, kbCtrlPgUp);
  Check((L^.Focused = 0) and (L^.TopItem = 0), 'Ctrl-PgUp goes to the start');
  Key(L, kbRight);
  Check(L^.Focused = 0, 'Right is ignored in a list of one column');

  { selection }
  Key(L, kbDown);
  Key(L, Ord(' '));
  Check(L^.Selected = 1, 'Space selects the focused item');

  { the scroll bar drives the list }
  Bar^.SetValue(6);
  Check(L^.Focused = 6, 'the scroll bar focuses an item');

  { the mouse }
  MemClear;
  MemMouse(evMouseUp, 15, 8);
  ClearEvent(E);
  E.What := evMouseDown;
  E.Where.X := 15;
  E.Where.Y := 9;
  E.Buttons := mbLeftButton;
  L^.HandleEvent(E);
  Check(L^.Focused = L^.TopItem + 1, 'a click focuses the item under it');
  L^.Selected := -1;
  MemClear;
  MemMouse(evMouseUp, 15, 10);
  ClearEvent(E);
  E.What := evMouseDown;
  E.Where.X := 15;
  E.Where.Y := 10;
  E.Buttons := mbLeftButton;
  E.EventFlags := meDoubleClick;
  L^.HandleEvent(E);
  Check((L^.Focused = L^.TopItem + 2) and (L^.Selected = L^.Focused), 'a double click selects it');

  { two columns }
  L2^.NewList(Items(7));
  Check(MemText(8, 34, 40) = ' Item 0', 'the first column');
  Check(MemText(8, 47, 53) = ' Item 3', 'the second column starts with the item after the first column');
  L2^.Select;
  Key(L2, kbRight);
  Check(L2^.Focused = 3, 'Right moves by a column');
  Key(L2, kbLeft);
  Check(L2^.Focused = 0, 'Left moves back');
  Key(L2, kbPgDn);
  Check(L2^.Focused = 6, 'PgDn moves by a page of the columns');

  { the data }
  L^.GetData(Rec);
  Check((Rec.List = L^.List) and (Rec.Selection = L^.Focused), 'GetData');
  Rec.List := Items(3);
  Rec.Selection := 2;
  L^.SetData(Rec);
  Check((L^.Range = 3) and (L^.Focused = 2), 'SetData replaces the items and focuses one');
  L^.NewList(nil);
  Check((L^.Range = 0) and (L^.List = nil), 'NewList(nil) empties the list');

  Check(SizeOf(TListBoxRec) = SizeOf(Pointer) + 4, 'the data record: a pointer and a 32-bit number, no padding');
  New(L3, Init(R(0, 0, 10, 3), 1, nil));
  L3^.NewList(Items(2));
  Keep := L3^.List;
  ListBoxOwnsList := False;
  Dispose(L3, Done);
  Check(Keep^.Count = 2, 'ListBoxOwnsList = False: Done leaves the list to its owner');
  Dispose(Keep, Done);
  ListBoxOwnsList := True;

  Dispose(App, Done);
  MemDone;
  Check(GetFPCHeapStatus.CurrHeapUsed = Used0, 'no memory is left behind');
  Finish;
end.
