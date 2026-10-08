{ The one place that knows how a path of the host looks: the separator, whether drives exist, what an absolute path is.

  MIT. The rest of DN must not spell a separator or a drive letter by hand (tools/check-paths.py counts
  the places that still do and lets the number only fall). See docs/PATHS.md. }
{$I STDEFINE.INC}
unit DnPath;

interface

const
  { the separator of the host: "/" on Unix, "\" on DOS and Windows }
{$IFDEF UNIX}
  PathSep = '/';
  HasDrives = False;
{$ELSE}
  PathSep = '\';
  HasDrives = True;
{$ENDIF}
  { the separator inside an archive: DN has always kept the members of an archive with "\", on every host }
  ArcSep = '\';

{ a separator of the host (on DOS and Windows "/" is accepted as well) }
function IsPathSep(C: Char): Boolean;
{ the path ends with a separator }
function EndsWithSep(const S: string): Boolean;
{ the length of the root of an absolute path: "/" is 1, "C:\" is 3, "\\host\share\" its whole length; 0 when the path is relative }
function PathRootLen(const S: string): Integer;
function IsAbsPath(const S: string): Boolean;
{ the letter that stands for the drive of a path: "C" for every path on a host without drives (the one tree is drive C inside DN) }
function DriveOf(const S: string): Char;
{ the root of drive C: "C:\" on DOS and Windows, "/" on Unix }
function DriveRoot(C: Char): string;
{ the path names a drive or a share (or is absolute on a host without drives): what a path of another drive looks like from here }
function IsQualified(const S: string): Boolean;
{ the separators of the other kind become those of the host }
function NormalizeSep(const S: string): string;

implementation

function IsPathSep(C: Char): Boolean;
begin
{$IFDEF UNIX}
  Result := C = '/';
{$ELSE}
  Result := (C = '\') or (C = '/');
{$ENDIF}
end;

function EndsWithSep(const S: string): Boolean;
begin
  Result := (S <> '') and IsPathSep(S[Length(S)]);
end;

function PathRootLen(const S: string): Integer;
{$IFNDEF UNIX}
var
  I, N: Integer;
{$ENDIF}
begin
  Result := 0;
{$IFDEF UNIX}
  if (S <> '') and (S[1] = '/') then
    Result := 1;
{$ELSE}
  if (Length(S) >= 3) and (S[2] = ':') and IsPathSep(S[3]) then
    Result := 3
  else if (Length(S) >= 2) and IsPathSep(S[1]) and IsPathSep(S[2]) then
  begin
    N := 0;                       { \\host\share\ : the root ends after the third separator }
    for I := 3 to Length(S) do
      if IsPathSep(S[I]) then
      begin
        Inc(N);
        if N = 2 then
          Exit(I);
      end;
    Result := Length(S);
  end
  else if (S <> '') and IsPathSep(S[1]) then
    Result := 1;
{$ENDIF}
end;

function IsAbsPath(const S: string): Boolean;
begin
  Result := PathRootLen(S) > 0;
end;

function DriveOf(const S: string): Char;
begin
  if HasDrives and (Length(S) >= 2) and (S[2] = ':') then
    Result := UpCase(S[1])
  else
    Result := 'C';
end;

function DriveRoot(C: Char): string;
begin
  if HasDrives then
    Result := UpCase(C) + ':\'
  else
    Result := PathSep;
end;

function IsQualified(const S: string): Boolean;
begin
  if HasDrives then
    Result := ((Length(S) >= 2) and (S[2] = ':')) or ((Length(S) >= 2) and (S[1] = '\') and (S[2] = '\'))
  else
    Result := IsAbsPath(S);
end;

function NormalizeSep(const S: string): string;
var
  I: Integer;
begin
  Result := S;
{$IFNDEF UNIX}
  for I := 1 to Length(Result) do
    if Result[I] = '/' then
      Result[I] := '\';
{$ENDIF}
end;

end.
