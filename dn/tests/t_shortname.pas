{$mode objfpc}{$H-}
program t_shortname;
{ FileShortName (filescol.pas): the short name of a file for the macros of the menus and the descriptions. Where the file system has no 8.3 names (Unix) it is the
  whole name, not the 12 bytes of the field FlName[False]; where it has them (DOS, Windows) it is that field. }
uses Defines, FilesCol, OSSystem, strutil;
{$I dntest.inc}
const
  Long = #$D0#$BE#$D1#$87#$D0#$B5#$D0#$BD#$D1#$8C'_'#$D0#$B4#$D0#$BB#$D0#$B8#$D0#$BD#$D0#$BD#$D0#$BE#$D0#$B5'_name.txt';
var
  FR: TFileRec;
  S: String;
begin
  FillChar(FR, SizeOf(FR), 0);
  FR.FlName[False] := Copy(Long, 1, 11);              { what the field holds: cut }
  CopyShortString(Long, FR.FlName[True]);
  S := FileShortName(FR);
  if OSHasShortNames then
    Check(Length(S) <= 12, 'with 8.3 names: the field of 12 bytes')
  else
  begin
    Check(S = Long, 'without 8.3 names: the whole name');
    Check(Length(S) > 12, 'the name is longer than the field');
  end;
  FillChar(FR, SizeOf(FR), 0);
  FR.FlName[False] := 'a.txt';
  CopyShortString('a.txt', FR.FlName[True]);
  Check(FileShortName(FR) = 'a.txt', 'a short name stays');
  Finish;
end.
