program t_dnpath;
{ Tests of compat/dnpath.pas on Unix: the rules of TvPath, and what DN adds (the drive letter of a path). }
{$mode objfpc}{$H-}
uses DnPath;
{$I dntest.inc}

begin
  Check(DnSep = '/', 'the separator of Unix');
  Check(not HasDrives, 'Unix has no drives');
  Check(IsPathSep('/') and not IsPathSep('\'), 'a backslash is a letter of a name');
  Check(EndsWithSep('/a/') and not EndsWithSep('/a\'), 'the end of a directory');
  Check(PathRootLen('/a') = 1, 'the root of Unix');
  Check(PathRootLen('a/b') = 0, 'a relative path has no root');
  Check(PathRootLen('C:\a') = 0, '"C:\a" is a relative name of Unix');
  Check(IsAbsPath('/a') and not IsAbsPath('C:\a') and not IsAbsPath('\a'), 'only "/" starts an absolute path');
  Check(not HasDriveLetter('C:\a') and not HasDriveLetter('C:'), 'no drive letters on Unix');
  Check(DriveOf('/a') = 'C', 'the one tree is drive C inside DN');
  Check(DriveRoot('D') = '/', 'the root of any drive is "/"');
  Check(IsQualified('/a') and not IsQualified('C:\a') and not IsQualified('\\srv\sh'), 'qualified: absolute');
  Check(NormalizeSep('a\b/c') = 'a\b/c', 'the separators of Unix stay as they are');
  Finish;
end.
