program t_resload;
{ Every dialog and menu of the three languages loads through the stream loader (the bug class of the class migration: a wrong layout of a
  stored view, an unregistered type). Needs the resources of a build: DN_RES_DIR=<the directory with english.dlg ...> (tools/build.sh makes them);
  without them the test reports SKIPPED. Also: the three languages have the same set of keys, and a loaded view is not empty. }
{$mode objfpc}{$H-}
uses SysUtils, Classes, Streams, Commands, RegAll, rstrings, editwin, TvViews;
{$I dntest.inc}

const
  Langs: array[0..2] of String = ('english', 'russian', 'ukrain');

var
  Dir: String;
  L, I, Loaded, Tried: LongInt;
  R: TIdxResource;
  F: TBufStream;
  O: TStreamable;
  Keys: array[0..2] of String;     { the keys that have a stored view, as a string of 0/1 }
  Counts: array[0..2] of array of LongInt;     { the number of sub views of every stored group (a dialog, a window): the languages must agree }
  Differ: LongInt;
  Child: LongInt;

function SubViews(V: TView): LongInt;
var
  P: TView;
begin
  Result := -1;                          { not a group }
  if not (V is TGroup) then
    Exit;
  Result := 0;
  P := TGroup(V).Last;
  if P = nil then
    Exit;
  repeat
    Inc(Result);
    P := P.Next;
  until P = TGroup(V).Last;
end;

begin
  Dir := GetEnvironmentVariable('DN_RES_DIR');
  if (Dir = '') or not FileExists(IncludeTrailingPathDelimiter(Dir) + 'english.dlg') then
  begin
    WriteLn('SKIPPED: no resources (DN_RES_DIR=', Dir, ')');
    WriteLn('ALL OK (0 checks, skipped)');
    Halt(0);
  end;
  Dir := IncludeTrailingPathDelimiter(Dir);
  RegisterAll;
  RegisterEditSaver;
  for L := 0 to High(Langs) do
  begin
    F := TBufStream.Create(Dir + Langs[L] + '.dlg', stOpenRead, 1024);
    Check(F.Status = stOK, Langs[L] + ': the file opens');
    R := TIdxResource.Create(F);
    Check(R.Count >= 90, Langs[L] + ': the index has at least 90 keys');
    Keys[L] := '';
    SetLength(Counts[L], R.Count);
    Loaded := 0;
    Tried := 0;
    for I := 0 to R.Count - 1 do
    begin
      if R.Index^[I] = -1 then
      begin
        Keys[L] := Keys[L] + '0';
        Continue;
      end;
      Keys[L] := Keys[L] + '1';
      Counts[L][I] := -2;
      Inc(Tried);
      O := R.Get(TDlgIdx(I));
      if O <> nil then
      begin
        Inc(Loaded);
        if O is TView then
          Counts[L][I] := SubViews(TView(O));
      end
      else
        WriteLn('  key ', I, ' of ', Langs[L], ' did not load');
      O.Free;
    end;
    Check((Tried >= 50) and (Loaded = Tried), Langs[L] + ': all ' + IntToStr(Tried) + ' stored views load (' + IntToStr(Loaded) + ')');
    R.Free;
  end;
  Check(Keys[0] = Keys[1], 'english and russian have the same keys');
  Check(Keys[0] = Keys[2], 'english and ukrainian have the same keys');
  { a dialog is the same dialog in every language: the same number of controls (a stored view that is not a group has -1) }
  Differ := 0;
  for I := 0 to High(Counts[0]) do
    if (Counts[0][I] <> Counts[1][I]) or (Counts[0][I] <> Counts[2][I]) then
    begin
      WriteLn('  key ', I, ': sub views english ', Counts[0][I], ', russian ', Counts[1][I], ', ukrainian ', Counts[2][I]);
      Inc(Differ);
    end;
  Check(Differ = 0, 'every stored dialog has the same number of controls in the three languages (' + IntToStr(Differ) + ' differ)');
  Finish;
end.
