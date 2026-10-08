program t_cfgdir;
{ Tests of src/cfgdir.pas: the directories of the user are made, the files of a DN of the program directory (and of an older directory) are copied once,
  the logs and the crash reports move to the directory of the state, the cache of dn.ini of the directory of the settings goes. }
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
  Root, Prog, Conf, R, Old, NewD, State, Cache: string;
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

  { an older directory of the settings (~/.config/dn on macOS) is copied first, then the program directory adds what it lacks }
  Old := Root + 'old' + DirectorySeparator;
  NewD := Root + 'new' + DirectorySeparator;
  ForceDirectories(Old);
  Put(Old + 'dn.ini', 'ini of the old dir');
  Put(Prog + 'dn.mnu', 'menu');
  UserConfigDirIn(NewD, Prog, Old);
  Check(Get(NewD + 'dn.ini') = 'ini of the old dir', 'the older directory of the user wins over the program directory');
  Check(not FileExists(NewD + 'dn.mnu'), 'nothing more once dn.ini is there');

  { the state: the logs and the crash reports of the directory of the settings move }
  State := Root + 'state' + DirectorySeparator + 'dn' + DirectorySeparator;
  Put(Conf + 'dn.log', 'log');
  Put(Conf + 'dn_prev.log', 'prev');
  ForceDirectories(Conf + 'crash');
  Put(Conf + 'crash' + DirectorySeparator + 'crash001.txt', 'report');
  R := UserStateDirIn(State, Conf);
  Check(DirectoryExists(State), 'the directory of the state is made');
  Check((R <> '') and (R[Length(R)] = '/'), 'the state: a path with a separator at the end: ' + R);
  Check((Get(State + 'dn.log') = 'log') and not FileExists(Conf + 'dn.log'), 'dn.log moves');
  Check((Get(State + 'dn_prev.log') = 'prev') and not FileExists(Conf + 'dn_prev.log'), 'dn_prev.log moves');
  Check((Get(State + 'crash' + DirectorySeparator + 'crash001.txt') = 'report') and not DirectoryExists(Conf + 'crash'), 'the crash reports move');
  Put(Conf + 'dn.log', 'stale');
  Put(State + 'dn.log', 'current');
  UserStateDirIn(State, Conf);
  Check(Get(State + 'dn.log') = 'current', 'a log that is there is not written over');
  Check(UserStateDirIn('', Conf) = Conf, 'no directory of the state: that of the settings');
  Check(MoveStateFiles(State, State) = 0, 'the same directory: nothing moves');

  { the cache }
  Cache := Root + 'cache' + DirectorySeparator + 'dn' + DirectorySeparator;
  Put(Conf + 'dn.cbc', 'cache');
  R := UserCacheDirIn(Cache, Conf);
  Check(DirectoryExists(Cache) and (R <> '') and (R[Length(R)] = '/'), 'the directory of the cache is made: ' + R);
  Check(not FileExists(Conf + 'dn.cbc'), 'the old cache of dn.ini goes');
  Check(UserCacheDirIn('', Conf) = Conf, 'no directory of the cache: that of the settings');
  Finish;
end.
