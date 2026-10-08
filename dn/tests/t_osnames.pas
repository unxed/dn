program t_osnames;
{ Tests of compat/osnamesunix.pas: the names of the files of DN (the bytes of the code page) at the border of Unix (UTF-8). }
{$mode objfpc}{$H-}
uses SysUtils, TvCodePg, OSNamesUnix;
{$I dntest.inc}

var
  Dir, Real: string;
  F: Text;

begin
  CpSelect(866);
  NameConv := True;

  Check(NameToOs('abc') = 'abc', 'ASCII is not changed');
  Check(NameToOs(#$80) = #$D0#$90, 'the cp866 letter A (80h) becomes its UTF-8');
  Check(NameFromOs(#$D0#$90) = #$80, 'and back');
  Check(NameFromOs(NameToOs('x' + #$A0#$E0 + '.txt')) = 'x' + #$A0#$E0 + '.txt', 'a name of letters goes there and back');
  Check(NameFromOs(#$E6#$97#$A5) = #$E6#$97#$A5, 'a character that the page lacks (CJK) stays as the UTF-8 bytes');
  Check(NameFromOs(#$FF#$FE) = #$FF#$FE, 'bytes that are not UTF-8 stay as they are');

  NameConv := False;
  Check((NameToOs(#$80) = #$80) and (NameFromOs(#$D0#$90) = #$D0#$90), 'NameConv = False: no conversion');
  NameConv := True;

  Check(OsPath('C:\nonex\a.txt') = '/nonex/a.txt', 'the drive is dropped, the backslashes become slashes');
  Check(OsPath('C:') = '.', 'a bare drive is the current directory');

  Check(DisplayPath('C:\dev\shm\') = '/dev/shm/', 'for the screen: the drive is dropped and the backslashes become slashes (issue #23)');
  Check(DisplayPath('C:\') = '/', 'the root of the only disk is shown as /');
  Check(DisplayPath('C:') = '/', 'a bare drive is shown as the root');
  Check(DisplayPath('/home/x') = '/home/x', 'a path that is already a path of the system is not changed');
  Check(DisplayPath('x:y\z') = 'y/z', 'any drive letter goes');
  Check(DisplayPath('C:\' + #$80 + '\a') = '/' + #$80 + '/a', 'the bytes of the page of DN are not touched');

  Dir := GetTempDir + 't_osnames_' + IntToStr(GetProcessID) + '/';
  ForceDirectories(Dir);
  Real := Dir + 'Hello.TXT';
  AssignFile(F, Real);
  Rewrite(F);
  CloseFile(F);
  Check(OsPath('C:' + StringReplace(Dir, '/', '\', [rfReplaceAll]) + 'hello.txt') = Real, 'the case of an existing name is found');
  DeleteFile(Real);
  RemoveDir(Dir);

  Check(CommandLineToOs('ls C:\nonex\a') = 'ls /nonex/a', 'a path in a command line is converted');
  Check(CommandLineToOs('7z x -y C:\nonex\a.7z @C:\nonex\$DN0$.LST') = '7z x -y /nonex/a.7z @/nonex/\$DN0\$.LST', 'a list file after the sign @ (the archivers), the $ of its name is not for the shell');
  Check(CommandLineToOs('echo ' + #$80) = 'echo ' + #$D0#$90, 'a letter of the page in a command line is converted');
  Finish;
end.
