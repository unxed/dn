program t_actions;
{ The menus and the status lines of the resources are built from the actions (dn/src/resource/actions.dna, DnActions): every
  menu item that gives a command and every status item that gives a key is an action of the table of its language (the same
  command, key, key text and help context), the three languages have the same actions, and the table goes into TvActions.
  Needs the resources of a build: DN_RES_DIR=<the directory with english.dlg ...>; without them the resource part is SKIPPED. }
{$mode objfpc}{$H-}
uses SysUtils, Classes, Streams, Commands, RegAll, rstrings, editwin, TvViews, Menus, DnActions, DnActReg, TvActions;
{$I dntest.inc}

const
  Langs: array[0..2] of String = ('english', 'russian', 'ukrain');

var
  Dir: String;
  L, I, Items, Missing, StatusKeys, StatusMissing: LongInt;
  R: TIdxResource;
  F: TBufStream;
  O: TStreamable;
  T: array[0..2] of TActionTable;
  SameNames: Boolean;

function PS(P: Pointer): String;
begin
  if P = nil then Result := '' else Result := PShortString(P)^;
end;

procedure WalkMenu(Tab: TActionTable; M: PMenu);
var
  P: PMenuItem;
  K: Integer;
  Found: Boolean;
begin
  if M = nil then
    Exit;
  P := M^.Items;
  while P <> nil do
  begin
    if (P^.Name <> nil) and (P^.Command = 0) then
      WalkMenu(Tab, P^.SubMenu)
    else if (P^.Name <> nil) and (P^.Command <> 0) then
    begin
      Inc(Items);
      Found := False;      { an item that was disabled when it was made keeps no key text (Menus.NewItem) }
      for K := 0 to Tab.Count - 1 do
        with Tab.Items[K] do
          if (Command = P^.Command) and (KeyCode = P^.KeyCode) and (HelpCtx = P^.HelpCtx) and
            (((P^.Flags and miParam) = 0) or (KeyText = PS(P^.Param))) then
            Found := True;
      if not Found then
      begin
        Inc(Missing);
        WriteLn('  no action for the menu item ', PS(P^.Name));
      end;
    end;
    P := P^.Next;
  end;
end;

procedure WalkStatus(Tab: TActionTable; S: TStatusLine);
var
  D: PStatusDef;
  P: PStatusItem;
  K: Integer;
  Found: Boolean;
begin
  D := S.Defs;
  while D <> nil do
  begin
    P := D^.Items;
    while P <> nil do
    begin
      if P^.KeyCode <> 0 then
      begin
        Inc(StatusKeys);
        Found := False;
        for K := 0 to Tab.Count - 1 do
          if (Tab.Items[K].Command = P^.Command) and (Tab.Items[K].KeyCode = P^.KeyCode) then
            Found := True;
        if not Found then
        begin
          Inc(StatusMissing);
          WriteLn('  no action for the status item ', PS(P^.Text));
        end;
      end;
      P := P^.Next;
    end;
    D := D^.Next;
  end;
end;

begin
  { the keys of DN in the form of tv3 }
  Check(DnKeyToTv(kbF3) = $3D00, 'DnKeyToTv: F3');
  Check(DnKeyToTv(kbAltF12) = $8C00, 'DnKeyToTv: Alt+F12');
  Check(DnKeyToTv(kbCtrlO) = $000F, 'DnKeyToTv: Ctrl+O');
  Check(DnKeyToTv(kbShiftIns) = $0500, 'DnKeyToTv: Shift+Ins');
  Check(DnKeyToTv(kbCtrlIns) = $0400, 'DnKeyToTv: Ctrl+Ins');

  Dir := GetEnvironmentVariable('DN_RES_DIR');
  if (Dir = '') or not FileExists(IncludeTrailingPathDelimiter(Dir) + 'english.dlg') then
  begin
    WriteLn('SKIPPED: no resources (DN_RES_DIR=', Dir, ')');
    Finish;
    Halt(0);
  end;
  Dir := IncludeTrailingPathDelimiter(Dir);
  RegisterAll;
  RegisterEditSaver;
  for L := 0 to High(Langs) do
  begin
    F := TBufStream.Create(Dir + Langs[L] + '.dlg', stOpenRead, 1024);
    R := TIdxResource.Create(F);
    O := R.Get(dlgActions);
    Check(O is TActionTable, Langs[L] + ': the table of the actions loads');
    if not (O is TActionTable) then
      Halt(1);
    T[L] := TActionTable(O);
    Check(T[L].Count > 300, Langs[L] + ': ' + IntToStr(T[L].Count) + ' actions');
    Items := 0;
    Missing := 0;
    StatusKeys := 0;
    StatusMissing := 0;
    for I := 0 to R.Count - 1 do
    begin
      if (R.Index^[I] = -1) or (TDlgIdx(I) = dlgActions) then
        Continue;
      O := R.Get(TDlgIdx(I));
      if O is TMenuView then
        WalkMenu(T[L], TMenuView(O).Menu)
      else if O is TStatusLine then
        WalkStatus(T[L], TStatusLine(O));
      O.Free;
    end;
    Check((Items > 250) and (Missing = 0), Langs[L] + ': every menu item with a command is an action (' + IntToStr(Items) + ' items, ' +
      IntToStr(Missing) + ' not)');
    Check((StatusKeys > 400) and (StatusMissing = 0), Langs[L] + ': every key of the status line is an action (' + IntToStr(StatusKeys) +
      ' keys, ' + IntToStr(StatusMissing) + ' not)');
    R.Free;
  end;
  SameNames := (T[0].Count = T[1].Count) and (T[0].Count = T[2].Count);
  if SameNames then
    for I := 0 to T[0].Count - 1 do
      SameNames := SameNames and (T[0].Items[I].Name = T[1].Items[I].Name) and (T[0].Items[I].Name = T[2].Items[I].Name);
  Check(SameNames, 'the three languages have the same actions');
  Check(T[0].Items[T[0].IndexOf('main.ViewFile')].Caption = 'M~a~in viewer', 'english: the caption of main.ViewFile comes from its menu item');

  { the registry of tv3 }
  ClearActions;
  RegisterActionTable(T[0]);
  Check(ActionCount = T[0].Count, 'TvActions holds every action (' + IntToStr(ActionCount) + ')');
  I := FindAction('main.viewfile');
  Check((I >= 0) and (ActionAt(I).Command = cmViewFile) and (ActionAt(I).Key = $3D00) and (ActionAt(I).HelpCtx = T[0].Items[T[0].IndexOf('main.ViewFile')].HelpCtx),
    'TvActions: main.ViewFile is F3, cmViewFile');
  Check(FindActionByCommand(cmViewFile) >= 0, 'TvActions: found by the command');
  WriteLn('  keys on two actions or more (english): ', Length(ActionKeyConflicts) > 0);
  Finish;
end.
