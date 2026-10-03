{ A program for tv/tests/pty/test_clip.py: puts a text on the clipboard with the terminal on, then ends. }
program clipdemo;
{$I ../../src/tvdefs.inc}
uses SysUtils, TvTermOs, TvUnix, TvClip;
begin
  if not UnixInit then
  begin
    WriteLn('no terminal');
    Halt(1);
  end;
  ClipboardSetText('Привет, мир');
  UnixFlush;
  Sleep(300);
  UnixDone;
end.
