program t_cfgdir;
{ Tests of src/cfgdir.pas: the directory of the files of the user is made, the files of a DN of the program directory are copied once. }
{$mode objfpc}{$H-}
uses SysUtils, Classes, CfgDir;
{$I dntest.inc}

procedure Put(const Name, Text: string);
var
  T: Text;
begin
  Assign(T, Name);
  Rewrite(T);
  Write(T, Text);
  Close(T);
end;

function Get(const Name: string): string;
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    L.LoadFromFile(Name);
    Result := Trim(L.Text);
  finally
    L.Free;
  end;
end;

var
  Root, Prog, Conf, R: string;
begin
  Root := GetTempDir + 't_cfgdir_' + IntToStr(GetProcessID) + DirectorySeparator;
  Prog := Root + 'prog' + DirectorySeparator;
  Conf := Root + 'conf' + DirectorySeparator + 'dn' + DirectorySeparator;
  ForceDirectories(Prog + 'colors');
  Put(Prog + 'dn.ini', 'ini of the program dir');
  Put(Prog + 'dn.his', 'histories');
  Put(Prog + 'colors' + DirectorySeparator + 'my.pal', 'palette');
  Put(Prog + 'english.lng', 'not a file of the user');

  R := UserConfigDirIn(Conf, Prog);
  Check(DirectoryExists(Conf), 'the directory of the user is made');
  Check((R <> '') and (R[Length(R)] = '/'), 'the result is a path of the host with a separator at the end: ' + R);
  Check(Get(Conf + 'dn.ini') = 'ini of the program dir', 'dn.ini is copied');
  Check(Get(Conf + 'dn.his') = 'histories', 'the histories are copied');
  Check(Get(Conf + 'colors' + DirectorySeparator + 'my.pal') = 'palette', 'the palettes are copied');
  Check(not FileExists(Conf + 'english.lng'), 'the resources are not');
  Check(FileExists(Prog + 'dn.ini'), 'the originals stay');

  { the move is done once: what the user changed is not written over, a file that he deleted does not come back }
  Put(Conf + 'dn.ini', 'changed');
  DeleteFile(Conf + 'dn.his');
  Put(Prog + 'dn.ini', 'ini again');
  UserConfigDirIn(Conf, Prog);
  Check(Get(Conf + 'dn.ini') = 'changed', 'a second start does not copy over dn.ini');
  Check(not FileExists(Conf + 'dn.his'), 'a deleted file does not come back');

  { the same directory for both: nothing to copy; no directory of the user: the program directory }
  Check(UserConfigDirIn('', 'C:\prog\') = 'C:\prog\', 'no directory of the user: the directory of the program');
  Finish;
end.
