DN for Windows (EXPERIMENTAL): the Windows build of the open DN OSP 2.14 on Turbo Vision (this repository: tv/ and dn/).
It is cross-compiled on Linux and checked on a real Windows console by CI (tools/dn-win-smoke.py).

  DN.EXE             run it in a console window (conhost, Windows Terminal, Wine); the console needs at least 80x25.
  *.LNG *.DLG *.HLP  the resources and the help, XLT\  the layout tables: they must be next to DN.EXE.

Keys: F10 menu, Tab switches the panel, Enter enters a directory, F1 help, F3 view, F4 edit, F5 copy, F7 make a directory,
Alt-X quit. Settings and history are written to the directory where DN is started (DN.INI, DN.HIS).
screenshots\*.txt are screens of the Windows build on a real Windows console (ConPTY, from CI: tools/dn-win-smoke.py).
The program draws with the console API (WriteConsoleOutputW), so it works in Wine and in Windows before 10 too; set the
environment variable DN_WIN_OUTPUT=vt to use the virtual terminal sequences (Windows 10 1809 or newer, Windows Terminal).
In Wine the bright background colors of DN are drawn without the intensity bit (the terminal of Wine draws them unevenly);
DN_WIN_BRIGHT_BG=1 turns that off, =0 turns it on in Windows.
Known: file names with non-ASCII letters are shown as the system code page gives them (not converted to the OEM page yet);
the Russian interface shows in the OEM page 866 (tools: see dn/TODO-later.md).
Based on Dos Navigator by RIT Research Labs.
DN is licensed as in LICENSE-DN.TXT, Turbo Vision as in LICENSE-TV.TXT and COPYRIGHT-TV-MAGIBLOT.TXT.
