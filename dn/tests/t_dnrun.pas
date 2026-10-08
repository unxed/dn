program t_dnrun;
{ Tests of src/dnrun.pas: the command line of DN for the shell (the paths of the host stay, $ and ` in them are escaped). }
{$mode objfpc}{$H-}
uses SysUtils, DNRun, osdep;
{$I dntest.inc}

begin
  Check(SysCommandLineToOs('7z l /nonex/a.7z >/nonex/!!!DN!!!.TMP') = '7z l /nonex/a.7z >/nonex/!!!DN!!!.TMP', 'a path after a blank and after the sign >');
  Check(SysCommandLineToOs('unzip "/no nex/a b.zip" x') = 'unzip "/no nex/a b.zip" x', 'a path in quotes ends at the quote, the blank inside stays');
  Check(SysCommandLineToOs('echo a:b c:') = 'echo a:b c:', 'not a path');
  Check(SysCommandLineToOs('ls dir/file') = 'ls dir/file', 'a relative name is left as it is');
  Check(SysCommandLineToOs('cat x=/nonex/y') = 'cat x=/nonex/y', 'a path after =');
  Check(SysCommandLineToOs('7z a /nonex/$DN0$.LST') = '7z a /nonex/\$DN0\$.LST', 'the shell does not read $ in a path');
  Check(SysCommandLineToOs('') = '', 'empty');
  Finish;
end.
