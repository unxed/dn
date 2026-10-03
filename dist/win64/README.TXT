DN for Windows (EXPERIMENTAL): the Windows build of the open DN OSP 2.14 on Turbo Vision (this repository: tv/ and dn/).
It is cross-compiled on Linux and checked on a real Windows console by CI (tools/dn-win-smoke.py).

  dn.exe             run it in a console window (conhost, Windows Terminal, Wine); the console needs at least 80x25.
  *.lng *.dlg *.hlp  the resources and the help, xlt\  the layout tables: they must be next to dn.exe.

Keys: F10 menu, Tab switches the panel, Enter enters a directory, F1 help, F3 view, F4 edit, F5 copy, F7 make a directory,
Alt-X quit. Settings and history are written to the directory where DN is started (dn.ini, dn.his).
screenshots\*.txt are screens of the Windows build on a real Windows console (ConPTY, from CI: tools/dn-win-smoke.py).
The program draws with the console API (WriteConsoleOutputW), so it works in Wine and in Windows before 10 too; set the
environment variable DN_WIN_OUTPUT=vt to use the virtual terminal sequences (Windows 10 1809 or newer, Windows Terminal).
In Wine the bright background colors of DN are drawn without the intensity bit (the terminal of Wine draws them unevenly);
DN_WIN_BRIGHT_BG=1 turns that off, =0 turns it on in Windows.
DN is UTF-8 inside: file names of any alphabet (the wide API of Windows), the Russian interface, the viewer, the editor and
the clipboard work; wide CJK letters and combining marks are not counted right yet. The old build with the code page inside:
DN_UTF8=0 tools/build.sh win64.
Based on Dos Navigator by RIT Research Labs.
DN is licensed as in LICENSE-DN.TXT, Turbo Vision as in LICENSE-TV.TXT and COPYRIGHT-TV-MAGIBLOT.TXT.
