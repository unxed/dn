program t_color;
{$I ../src/tvdefs.inc}
uses TvGeom, TvColors, TvCell, TvCodePg, TvEvents, TvKeys, TvViews, TvObjs, TvUtil, TvMem, TvApp,
  TvDialog, TvWindow, TvList, TvCluster, TvColorSel;
{$I testlib.inc}

function R(A, B, C, D: Integer): TRect;
begin
  Result.Assign(A, B, C, D);
end;

procedure Key(V: PView; Code: Word);
var
  E: TEvent;
begin
  MakeKeyEvent(E, Code, 0);
  V^.HandleEvent(E);
end;

function Groups3: PColorGroup;
begin
  Result := ColorGroup('Window', ColorItem('Text', 1, ColorItem('Frame', 2, nil)),
    ColorGroup('Menu', ColorItem('Normal', 3, nil), nil));
end;

function Bios(const P: TPalette; I: Integer): Integer;
begin
  Result := AttrToBIOS(P[I]);
end;

var
  App: PApplication;
  Dlg: PColorDialog;
  Pal, Res: TPalette;
  Used0: PtrUInt;
  E: TEvent;

procedure Run;
begin
  Pal := MakePalette(#$1F#$2E#$70);
  MemInit(80, 25);
  New(App, Init);
  New(Dlg, Init(Pal, Groups3));
  App^.InsertWindow(Dlg);

  Check(Dlg^.Groups^.Range = 2, 'two groups are listed');
  Check(Dlg^.Groups^.GetText(0, 255) = 'Window', 'the group name');
  Check(Dlg^.Groups^.GetNumGroups = 2, 'GetNumGroups');
  Check(Dlg^.ForSel^.Color = $0F, 'the foreground selector shows the foreground of the first item ($1F)');
  Check(Dlg^.BakSel^.Color = 1, 'the background selector shows the background');
  Check(Dlg^.Display^.Color = @Dlg^.Pal[1], 'the display points to the color of the item');

  { the selector changes the color of the item }
  Dlg^.ForSel^.Select;
  Key(Dlg^.ForSel, kbRight);
  Check(Dlg^.ForSel^.Color = 0, 'Right wraps to color 0');
  Check(Bios(Dlg^.Pal, 1) = $10, 'the palette of the dialog is changed');
  Check(Bios(Pal, 1) = $1F, 'but the palette given to it is not');
  Key(Dlg^.ForSel, kbLeft);
  Check(Dlg^.ForSel^.Color = 15, 'Left wraps to 15');
  Key(Dlg^.ForSel, kbDown);
  Check(Dlg^.ForSel^.Color = 0, 'Down from the last color wraps to the first');
  Key(Dlg^.ForSel, kbUp);
  Check(Dlg^.ForSel^.Color = 15, 'Up from the first color wraps to the last');
  Dlg^.BakSel^.Select;
  Key(Dlg^.BakSel, kbRight);
  Check(Dlg^.BakSel^.Color = 2, 'the background selector moves too');
  Check(Bios(Dlg^.Pal, 1) = $2F, 'and the palette has the new background');
  Dlg^.BakSel^.Color := 7;
  Key(Dlg^.BakSel, kbRight);
  Check(Dlg^.BakSel^.Color = 0, 'the background has 8 colors');

  { another item of the group }
  Dlg^.Groups^.Owner^.Select;
  ClearEvent(E);
  E.What := evBroadcast;
  E.Command := cmNewColorItem;
  E.InfoPtr := Dlg^.Groups^.GetGroup(0);
  Dlg^.HandleEvent(E);
  Check(Dlg^.GroupIndex = Dlg^.Groups^.Focused, 'the dialog knows the group');

  { another group }
  Dlg^.Groups^.Select;
  Key(Dlg^.Groups, kbDown);
  Check(Dlg^.Groups^.Focused = 1, 'the group list moves');
  Check(Dlg^.Display^.Color = @Dlg^.Pal[3], 'the display points to the color of the first item of the second group');
  Check((Dlg^.ForSel^.Color = 0) and (Dlg^.BakSel^.Color = 7), 'the selectors show the color $70');

  { the data }
  Dlg^.GetData(Res);
  Check(Length(Res) = Length(Pal), 'GetData gives the palette');
  Check(Bios(Res, 1) = $0F, 'with the changes (white on color 0)');
  Check(Bios(Res, 3) = $70, 'and the others as they were');
  Check(ColorIndexes <> nil, 'the indexes of the groups are remembered');
  Check(ColorIndexes^.ColorSize = 2, 'for every group');
  Check(ColorIndexes^.GroupIndex = 1, 'with the last group');
  Check(Dlg^.DataSize = SizeOf(TPalette), 'the data size is that of a palette');

  { the color display of the invalid color 0 }
  Dlg^.Display^.Color^ := AttrFromBIOS($00);
  Dlg^.Display^.DrawView;
  Check(Bios(Dlg^.Pal, 3) = 0, 'the display accepts color 0');

  Dispose(App, Done);
  MemDone;
  FreeColorIndexes;
  Pal := nil;
  Res := nil;
end;

begin
  Quiet := True;
  Run;
  Quiet := False;
  Used0 := GetFPCHeapStatus.CurrHeapUsed;
  Run;
  Check(GetFPCHeapStatus.CurrHeapUsed = Used0, 'no memory is left behind');
  Finish;
end.
