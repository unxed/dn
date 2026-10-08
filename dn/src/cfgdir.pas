{ CfgDir: the directories of the files of the user. The places come from TvAppDir of tv3 (the places of each system):
    the settings, the desktop, the histories   TvAppDir.ConfigDir('dn')  (~/.config/dn, ~/Library/Application Support/dn, %APPDATA%\dn)
    the log of the run and the crash reports   TvAppDir.StateDir('dn')   (~/.local/state/dn, ~/Library/Application Support/dn, %LOCALAPPDATA%\dn)
    the cache of dn.ini (dn.cbc)               TvAppDir.CacheDir('dn')   (~/.cache/dn, ~/Library/Caches/dn, %LOCALAPPDATA%\dn)
  DOS keeps all of them next to the program. The first start after a move copies the settings that a DN of the program directory made (and, on macOS,
  those of ~/.config/dn); the originals stay where they are. The logs and the crash reports in the directory of the settings move to that of the state.
  MIT, see LICENSE. }
unit CfgDir;

{$mode objfpc}
{$H-}

interface

{ The directory for the settings of the user as a path of DN ("C:\home\user\.config\dn\", with the backslash at the end), made if there was none; ProgramDir is the
  directory of the program (a path of DN): the files that it holds are copied once. ProgramDir itself when the target has no such directory or it cannot be made. }
function UserConfigDir(const ProgramDir: string): string;
{ The same for a directory OsDir of the system that is given: a test can name its own. OldDir (a path of the system with a separator at the end, or '') is an older
  directory of the settings of the user: its files are copied first. }
function UserConfigDirIn(const OsDir, ProgramDir: string; const OldDir: string = ''): string;

{ The directory for the log of the run and the crash reports as a path of DN, made if there was none; ConfigDir (a path of DN) is the directory of the settings: the
  logs and the reports that it holds move. ConfigDir itself when the target has no such directory or it cannot be made. }
function UserStateDir(const ConfigDir: string): string;
function UserStateDirIn(const OsDir, ConfigDir: string; const OldDir: string = ''): string;

{ The directory for the caches as a path of DN, made if there was none; the cache of dn.ini that ConfigDir holds is deleted. ConfigDir itself when the target has
  no such directory or it cannot be made. }
function UserCacheDir(const ConfigDir: string): string;
function UserCacheDirIn(const OsDir, ConfigDir: string): string;

{ The names of the files (in the directory of the program, and in the directory of the user) that DN made before the move. }
const
  MovedFiles: array[0..16] of string = (
    'dn.ini', 'dn.dsk', 'dn.clp', 'dn.his', 'dnhgl.grp', 'dn.mnu', 'dn.hgl', 'dn.spf', 'dn.ext', 'dn.edt', 'dn.vwr', 'dn.arc', 'dn.cfg', 'dn.old', 'dn.phn', 'dn.xrn', 'tetris.cfg');
  { The files of the state: the log of the run, that of the run before, the short report of a crash without a log; and the directory crash. }
  StateFiles: array[0..2] of string = ('dn.log', 'dn_prev.log', 'dn.err');
  { The cache of the settings. }
  CacheFiles: array[0..0] of string = ('dn.cbc');

{ Copy the files of MovedFiles that FromDir (a path of the system, with a separator at the end) holds into ToDir, unless ToDir already has dn.ini (the move was done);
  the directory colors with its palettes goes too. The number of the files copied. }
function MoveUserFiles(const FromDir, ToDir: string): Integer;
{ Move the files of StateFiles and the files of the directory crash from FromDir into ToDir (paths of the system with a separator at the end); a file that ToDir
  already has stays where it is. The number of the files moved. }
function MoveStateFiles(const FromDir, ToDir: string): Integer;

implementation

uses
  SysUtils, Classes, TvAppDir, Lfn, osdep, DnPath, TvPath;

function CopyOne(const Src, Dst: string): Boolean;
var
  I, O: TFileStream;
begin
  Result := False;
  try
    I := TFileStream.Create(Src, fmOpenRead or fmShareDenyNone);
    try
      O := TFileStream.Create(Dst, fmCreate);
      try
        O.CopyFrom(I, 0);
        Result := True;
      finally
        O.Free;
      end;
    finally
      I.Free;
    end;
  except
    Result := False;
  end;
end;

function MoveOne(const Src, Dst: string): Boolean;
begin
  Result := RenameFile(Src, Dst);
  if not Result and CopyOne(Src, Dst) then        { another file system }
    Result := DeleteFile(Src);
end;

function WithSep(const S: string): string;
begin
  Result := S;
  if (Result <> '') and (Result[Length(Result)] <> DirectorySeparator) then
    Result := Result + DirectorySeparator;
end;

function SameDir(const A, B: string): Boolean;
begin
  Result := WithSep(PathExpand(A)) = WithSep(PathExpand(B));
end;

{ A directory of the system as a path of DN with the separator of DN at the end. }
function DnDir(const OsDir: string): string;
begin
  Result := lFExpand(OsDir);
  if (Result <> '') and not IsPathSep(Result[Length(Result)]) then
    Result := Result + DnSep;
end;

{ The directory of the kind for DN on this system as a path of the system with a separator at the end, made; '' when it is not known or cannot be made, and on
  DOS (the directories of DN there are those of the program). }
function SystemDir(Kind: TAppDirKind): string;
var
  D: AnsiString;
begin
  Result := '';
  if NativeAppDirSystem = adsDos then
    Exit;
  D := AppDirPath(Kind, 'dn');
  if (D = '') or not MakeAppDir(D) then
    Exit;
  Result := WithSep(D);
end;

function MoveUserFiles(const FromDir, ToDir: string): Integer;
var
  K: Integer;
  SR: TSearchRec;
begin
  Result := 0;
  if FileExists(ToDir + 'dn.ini') then
    Exit;
  for K := Low(MovedFiles) to High(MovedFiles) do
    if FileExists(FromDir + MovedFiles[K]) and not FileExists(ToDir + MovedFiles[K]) then
      if CopyOne(FromDir + MovedFiles[K], ToDir + MovedFiles[K]) then
        Inc(Result);
  if DirectoryExists(FromDir + 'colors') then
  begin
    ForceDirectories(ToDir + 'colors');
    if FindFirst(FromDir + 'colors' + DirectorySeparator + '*', faAnyFile and not faDirectory, SR) = 0 then
    begin
      repeat
        if not FileExists(ToDir + 'colors' + DirectorySeparator + SR.Name) then
          if CopyOne(FromDir + 'colors' + DirectorySeparator + SR.Name, ToDir + 'colors' + DirectorySeparator + SR.Name) then
            Inc(Result);
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;
  end;
end;

function MoveStateFiles(const FromDir, ToDir: string): Integer;
var
  K: Integer;
  SR: TSearchRec;
  FromCrash, ToCrash: string;
begin
  Result := 0;
  if (FromDir = '') or SameDir(FromDir, ToDir) then
    Exit;
  for K := Low(StateFiles) to High(StateFiles) do
    if FileExists(FromDir + StateFiles[K]) and not FileExists(ToDir + StateFiles[K]) then
      if MoveOne(FromDir + StateFiles[K], ToDir + StateFiles[K]) then
        Inc(Result);
  FromCrash := FromDir + 'crash' + DirectorySeparator;
  ToCrash := ToDir + 'crash' + DirectorySeparator;
  if DirectoryExists(FromCrash) then
  begin
    ForceDirectories(ToCrash);
    if FindFirst(FromCrash + '*', faAnyFile and not faDirectory, SR) = 0 then
    begin
      repeat
        if not FileExists(ToCrash + SR.Name) then
          if MoveOne(FromCrash + SR.Name, ToCrash + SR.Name) then
            Inc(Result);
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;
    RemoveDir(FromCrash);                       { when it is empty }
  end;
end;

function UserConfigDir(const ProgramDir: string): string;
var
  Old: string;
begin
  Old := '';
  if NativeAppDirSystem = adsMac then           { DN on macOS kept its settings in ~/.config/dn before }
    Old := WithSep(AppDirIn(adConfig, 'dn', adsXdg, @AppDirGetEnv, ''));
  Result := UserConfigDirIn(SystemDir(adConfig), ProgramDir, Old);
end;

function UserConfigDirIn(const OsDir, ProgramDir: string; const OldDir: string): string;
var
  Os, From: string;
begin
  Result := ProgramDir;
  Os := OsDir;
  if Os = '' then
    Exit;
  if not ForceDirectories(Os) then
    Exit;
  if (OldDir <> '') and (OldDir <> Os) and DirectoryExists(OldDir) then
    MoveUserFiles(OldDir, Os);
  From := WithSep(SysOsPath(ProgramDir));
  if From <> Os then
    MoveUserFiles(From, Os);
  Result := DnDir(Os);
end;

function UserStateDir(const ConfigDir: string): string;
var
  Old: string;
begin
  Old := '';
  if NativeAppDirSystem = adsMac then
    Old := WithSep(AppDirIn(adConfig, 'dn', adsXdg, @AppDirGetEnv, ''));
  Result := UserStateDirIn(SystemDir(adState), ConfigDir, Old);
end;

function UserStateDirIn(const OsDir, ConfigDir: string; const OldDir: string): string;
begin
  Result := ConfigDir;
  if (OsDir = '') or not ForceDirectories(OsDir) then
    Exit;
  MoveStateFiles(WithSep(SysOsPath(ConfigDir)), OsDir);
  if (OldDir <> '') and DirectoryExists(OldDir) then
    MoveStateFiles(OldDir, OsDir);
  Result := DnDir(OsDir);
end;

function UserCacheDir(const ConfigDir: string): string;
begin
  Result := UserCacheDirIn(SystemDir(adCache), ConfigDir);
end;

function UserCacheDirIn(const OsDir, ConfigDir: string): string;
var
  K: Integer;
  From: string;
begin
  Result := ConfigDir;
  if (OsDir = '') or not ForceDirectories(OsDir) then
    Exit;
  From := WithSep(SysOsPath(ConfigDir));
  if not SameDir(From, OsDir) then
    for K := Low(CacheFiles) to High(CacheFiles) do
      if FileExists(From + CacheFiles[K]) then
        DeleteFile(From + CacheFiles[K]);
  Result := DnDir(OsDir);
end;

end.
