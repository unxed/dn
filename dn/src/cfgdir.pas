{ CfgDir: the directory of the files that the user changes (the settings, the desktop, the histories, the crash reports).
  The directory comes from OSSystem.OSConfigDir (the configuration of the user: ~/.config/dn, %APPDATA%\DN); DOS keeps the files next to the program. The first start
  after the move copies the files that a DN of the program directory made (the originals stay where they are).
  MIT (see LICENSE). }
unit CfgDir;

{$mode objfpc}
{$H-}

interface

{ The directory for the files of the user as a path of DN ("C:\home\user\.config\dn\", with the backslash at the end), made if there was none; ProgramDir is the
  directory of the program (a path of DN): the files that it holds are copied once. ProgramDir itself when the target has no such directory or it cannot be made. }
function UserConfigDir(const ProgramDir: string): string;
{ The same for a directory OsDir of the system that is given (OSConfigDir is that of the system): a test can name its own. }
function UserConfigDirIn(const OsDir, ProgramDir: string): string;

{ The names of the files (in the directory of the program, and in the directory of the user) that DN made before the move. }
const
  MovedFiles: array[0..17] of string = (
    'dn.ini', 'dn.cbc', 'dn.dsk', 'dn.clp', 'dn.his', 'dnhgl.grp', 'dn.mnu', 'dn.hgl', 'dn.spf', 'dn.ext', 'dn.edt', 'dn.vwr', 'dn.arc', 'dn.cfg', 'dn.old', 'dn.phn', 'dn.xrn', 'tetris.cfg');

{ Copy the files of MovedFiles that FromDir (a path of the system, with a separator at the end) holds into ToDir, unless ToDir already has dn.ini (the move was done);
  the directory colors with its palettes goes too. The number of the files copied. }
function MoveUserFiles(const FromDir, ToDir: string): Integer;

implementation

uses
  SysUtils, Classes, OSSystem, Lfn, osdep, DnPath;

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

function UserConfigDir(const ProgramDir: string): string;
begin
  Result := UserConfigDirIn(OSConfigDir, ProgramDir);
end;

function UserConfigDirIn(const OsDir, ProgramDir: string): string;
var
  Os, From: string;
begin
  Result := ProgramDir;
  Os := OsDir;
  if Os = '' then
    Exit;
  if not ForceDirectories(Os) then
    Exit;
  From := SysOsPath(ProgramDir);
  if (From <> '') and (From[Length(From)] <> DirectorySeparator) then
    From := From + DirectorySeparator;
  if From <> Os then
    MoveUserFiles(From, Os);
  Result := lFExpand(Os);
  if (Result <> '') and not IsPathSep(Result[Length(Result)]) then
    Result := Result + PathSep;
end;

end.
