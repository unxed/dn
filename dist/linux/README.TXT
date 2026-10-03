DN for Linux (static: no libraries needed). EXPERIMENTAL: the Linux build of the
open DN OSP 2.14 on Turbo Vision (this repository: tv/ and dn/). It needs a terminal of at least 80x25 (xterm, the Linux
console, kitty, alacritty...); DN is UTF-8 inside: file names, the viewer, the editor,
the clipboard (OSC 52) and Alt+Cyrillic work in any alphabet (wide CJK letters and combining marks are not yet counted right).
The old build with the code page inside: DN_UTF8=0 tools/build.sh.
The commands of the command line run in an embedded terminal (the screen of the user: Ctrl-O or Esc on an empty command line; DN_EMBED_TERM=0 gives the terminal to
the shell as before, DN_RUN_PAUSE=0|1|2 sets what happens when the command ends).

  cd dist/linux && ./dn            (dist/linux: i386, dist/linux64: x86_64; the files of the program, *.LNG *.DLG *.HLP, must be next to it)

Keys: F10 menu, Tab switches the panel, Enter enters a directory, F1 help, F3 view, F4 edit, F5 copy, F7 make a directory,
Alt-X quit. DN names the files as DOS does: the disk C: is the root of the file system ("C:\home\you"). The first start
shows a notice of the beta (Esc closes it). Settings and history are written to the directory where DN is started (DN.INI,
DN.HIS).
screenshots/*.txt are the screens of tools/dn-linux-tour.py.
Based on Dos Navigator by RIT Research Labs.
DN is licensed as in LICENSE-DN.TXT, Turbo Vision as in LICENSE-TV.TXT and COPYRIGHT-TV-MAGIBLOT.TXT.
