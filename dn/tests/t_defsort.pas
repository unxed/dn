program t_defsort;
{ Tests of ApplyDefaultSortMode (panelsetup.pas): the sort of the preset panels by the name of dn.ini (DefaultSortMode). }
{$mode objfpc}{$H-}
uses SysUtils, Commands, panelsetup;
{$I dntest.inc}

function AllPresets(M: Integer): Boolean;
var
  i: Integer;
  pc: TPanelClass;
begin
  Result := True;
  for i := 1 to 10 do
    for pc := Low(TPanelClass) to High(TPanelClass) do
      if PanSetupPreset[i][pc].Sort.SortMode <> M then
        Result := False;
end;

begin
  Check(AllPresets(psmLongExt), 'the default is the sort by the extension');
  ApplyDefaultSortMode('name');
  Check(AllPresets(psmLongName), 'name');
  ApplyDefaultSortMode('SIZE');
  Check(AllPresets(psmSize), 'size (any case)');
  ApplyDefaultSortMode('date');
  Check(AllPresets(psmTime), 'date');
  ApplyDefaultSortMode('unsorted');
  Check(AllPresets(psmUnsorted), 'unsorted');
  ApplyDefaultSortMode('bogus');
  Check(AllPresets(psmUnsorted), 'an unknown name changes nothing');
  ApplyDefaultSortMode('');
  Check(AllPresets(psmUnsorted), 'an empty name changes nothing');
  ApplyDefaultSortMode('ext');
  Check(AllPresets(psmLongExt), 'ext');
  Finish;
end.
