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

  Check(OsPath('/nonex/a.txt') = '/nonex/a.txt', 'a name of the host is kept as it is');
  Check(OsPath('') = '.', 'an empty name is the current directory');
  Check(OsPath('/nonex/a\b') = '/nonex/a\b', 'a backslash in a name of Unix is a letter');

  Dir := GetTempDir + 't_osnames_' + IntToStr(GetProcessID) + '/';
  ForceDirectories(Dir);
  Real := Dir + 'Hello.TXT';
  AssignFile(F, Real);
  Rewrite(F);
  CloseFile(F);
  Check(OsPath(Dir + 'hello.txt') = Real, 'the case of an existing name is found');
  DeleteFile(Real);
  RemoveDir(Dir);

  Check(CommandLineToOs('ls /nonex/a') = 'ls /nonex/a', 'a path in a command line is kept');
  Check(CommandLineToOs('7z x -y /nonex/a.7z @/nonex/$DN0$.LST') = '7z x -y /nonex/a.7z @/nonex/\$DN0\$.LST', 'a list file after the sign @ (the archivers), the $ of its name is not for the shell');
  Check(CommandLineToOs('echo ' + #$80) = 'echo ' + #$D0#$90, 'a letter of the page in a command line is converted');
  Finish;
end.
