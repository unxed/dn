{ A program for tv/tests/pty/test_vtrun.py: runs a shell command on the screen of the application (VtRunScreen), then shows the screen again (VtShowScreen). }
program rundemo;
{$I ../../src/tvdefs.inc}
uses TvUnix, TvVt, TvVtRun;
var
  Emu: TVtEmu;
  St: Integer;
begin
  if not UnixInit then
  begin
    WriteLn('no terminal');
    Halt(1);
  end;
  St := VtRunScreen(Emu, '/bin/sh', ['sh', '-c', 'echo hello; read x; echo got:$x; exit 5'], '', '$ mycommand', True);
  VtShowScreen(Emu);
  UnixDone;
  WriteLn('DONE ', St);
end.
