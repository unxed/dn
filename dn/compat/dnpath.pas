{ The path rules of DN: a thin layer over TvPath (tv/src/tvpath.pas), which holds the rules of each system, with the
  few things that only DN needs (the drive letter that stands for a path, the separator inside an archive).

  MIT. The rest of DN must not spell a separator or a drive letter by hand (tools/check-paths.py counts
  the places that still do and lets the number only fall). See docs/PATHS.md. }
{$I STDEFINE.INC}
unit DnPath;

interface

uses
  TvPath;

const
  { the separator of the host: "/" on Unix, "\" on DOS and Windows }
  DnSep = TvPath.PathSep;
  HasDrives = TvPath.PathHasDrives;
  { the separator inside an archive: DN has always kept the members of an archive with "\", on every host }
  ArcSep = '\';

{ a separator of the host (on DOS and Windows "/" is accepted as well) }
function IsPathSep(Ch: Char): Boolean;
{ the path ends with a separator }
function EndsWithSep(const S: string): Boolean;
{ the length of the root of an absolute path: "/" is 1, "C:\" is 3, "\\host\share\" its whole length; 0 when the path
  does not start at a root directory ("C:x", "x") }
function PathRootLen(const S: string): Integer;
{ the path starts at a root directory: "/x", "\x", "C:\x", "\\host\share" }
function IsAbsPath(const S: string): Boolean;
{ the letter that stands for the drive of a path: "C" for every path on a host without drives (the one tree is drive C inside DN) }
function DriveOf(const S: string): Char;
{ the root of drive C: "C:\" on DOS and Windows, "/" on Unix }
function DriveRoot(C: Char): string;
{ the path names a drive or a share (or is absolute on a host without drives): what a path of another drive looks like from here }
function IsQualified(const S: string): Boolean;
{ the path starts with a drive letter ("C:"); never on a host without drives }
function HasDriveLetter(const S: string): Boolean;
{ the separators of the other kind become those of the host }
function NormalizeSep(const S: string): string;

implementation

function IsPathSep(Ch: Char): Boolean;
begin
  Result := TvPath.IsPathSep(Ch);
end;

function EndsWithSep(const S: string): Boolean;
begin
  Result := TvPath.EndsWithSep(S);
end;

function PathRootLen(const S: string): Integer;
begin
  if TvPath.PathIsRooted(S) then
    Result := TvPath.PathRootLen(S)
  else
    Result := 0;
end;

function IsAbsPath(const S: string): Boolean;
begin
  Result := TvPath.PathIsRooted(S);
end;

function HasDriveLetter(const S: string): Boolean;
begin
  Result := HasDrives and (Length(TvPath.PathDrive(S)) = 2);
end;

function DriveOf(const S: string): Char;
begin
  if HasDriveLetter(S) then
    Result := UpCase(S[1])
  else
    Result := 'C';
end;

function DriveRoot(C: Char): string;
begin
{$IF HasDrives}
  Result := UpCase(C) + ':' + DnSep;
{$ELSE}
  Result := DnSep;
{$ENDIF}
end;

function IsQualified(const S: string): Boolean;
begin
{$IF HasDrives}
  Result := TvPath.PathDrive(S) <> '';
{$ELSE}
  Result := IsAbsPath(S);
{$ENDIF}
end;

function NormalizeSep(const S: string): string;
begin
  Result := TvPath.PathNative(S);
end;

end.
