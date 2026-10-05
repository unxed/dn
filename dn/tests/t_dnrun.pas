program t_dnrun;
{ Tests of src/dnrun.pas: the command line of DN for the shell (the paths C:\dir\name become the paths of the system). }
{$mode objfpc}{$H-}
uses SysUtils, DNRun, osdep;
{$I dntest.inc}

begin
  Check(SysCommandLineToOs('7z l C:\nonex\a.7z >C:\nonex\!!!DN!!!.TMP') = '7z l /nonex/a.7z >/nonex/!!!DN!!!.TMP', 'a path after a blank and after the sign >');
  Check(SysCommandLineToOs('unzip "C:\no nex\a b.zip" x') = 'unzip "/no nex/a b.zip" x', 'a path in quotes ends at the quote, the blank inside stays');
  Check(SysCommandLineToOs('echo a:b c:') = 'echo a:b c:', 'not a path: no backslash after the colon');
  Check(SysCommandLineToOs('ls dir\file') = 'ls dir\file', 'a relative name is left as it is');
  Check(SysCommandLineToOs('cat x=C:\nonex\y') = 'cat x=/nonex/y', 'a path after =');
  Check(SysCommandLineToOs('') = '', 'empty');
  Finish;
end.
