DN for Linux (static: no libraries needed). EXPERIMENTAL: the Linux build of the
open DN OSP 2.14 on Turbo Vision (this repository: tv/ and dn/). It needs a terminal of at least 80x25 (xterm, the Linux
console, kitty, alacritty...); Russian file names (UTF-8) are shown as Russian; names with other alphabets are shown wrong (DN is not UTF-8 inside yet).

  cd dist/linux && ./dn            (dist/linux: i386, dist/linux64: x86_64; the files of the program, *.LNG *.DLG *.HLP, must be next to it)

Keys: F10 menu, Tab switches the panel, Enter enters a directory, F1 help, F3 view, F4 edit, F5 copy, F7 make a directory,
Alt-X quit. DN names the files as DOS does: the disk C: is the root of the file system ("C:\home\you"). The first start
shows a notice of the beta (Esc closes it). Settings and history are written to the directory where DN is started (DN.INI,
DN.HIS).
screenshots/*.txt are the screens of tools/dn-linux-tour.py.
Based on Dos Navigator by RIT Research Labs.
DN is licensed as in LICENSE-DN.TXT, Turbo Vision as in LICENSE-TV.TXT and COPYRIGHT-TV-MAGIBLOT.TXT.
