#!/bin/sh
# Makes dist/linux/: the Linux build of DN (i386, static) that can be tried without building it, with the screens of
# the pty tour as text. usage: DN_LINUX=PREFIX tools/dn-linux-dist.sh [linux|linux64|aarch64]  (aarch64: DN_AARCH64=PREFIX of tools/build-fpc-aarch64-linux.sh; the tour runs under qemu-aarch64-static)
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
T=${1:-linux}     # linux (i386, static), linux64 (x86_64) or aarch64 (ARM64, static)
[ "$T" = aarch64 ] && export PTY_RUN_PREFIX=${PTY_RUN_PREFIX:-qemu-aarch64-static}
dist=$here/dist/$T
tmp=${TMPDIR:-/tmp}; work=$tmp/dn-linux-dist
mkdir -p "$work" "$dist/screenshots"
# no symbols: small
DN_EXTRA="-Xs" "$here/tools/build.sh" "$T" "$work" >/dev/null
cp "$work/dn" "$dist/dn"
cp "$work"/*.lng "$work"/*.dlg "$work"/*.hlp "$dist/"
rm -rf "$dist/xlt"; cp -r "$work/xlt" "$dist/xlt"
cp "$here/dist/dos/LICENSE-DN.TXT" "$here/dist/dos/LICENSE-TV.TXT" "$here/dist/dos/COPYRIGHT-TV-MAGIBLOT.TXT" "$dist/"
python3 "$here/tools/dn-linux-tour.py" "$work" start f1help f3view f4edit f7mkdir f5copy menudisk quitask quit
for n in start f1help f3view f4edit f7mkdir f5copy menudisk; do
    grep -v '^[[:space:]]*$' "$work/tour-$n.txt" > "$dist/screenshots/$n.txt"
done
cat > "$dist/README.TXT" <<'EOS'
DN for Linux (static: no libraries needed). EXPERIMENTAL: the Linux build of the
open DN OSP 2.14 on Turbo Vision (this repository: tv/ and dn/). It needs a terminal of at least 80x25 (xterm, the Linux
console, kitty, alacritty...); DN is UTF-8 inside: file names, the viewer, the editor,
the clipboard (OSC 52) and Alt+Cyrillic work in any alphabet (wide CJK letters and combining marks are not yet counted right).
The old build with the code page inside: DN_UTF8=0 tools/build.sh.
The commands of the command line run in an embedded terminal (the screen of the user: Ctrl-O or Esc on an empty command line; DN_EMBED_TERM=0 gives the terminal to
the shell as before, DN_RUN_PAUSE=0|1|2 sets what happens when the command ends).

  cd dist/linux && ./dn            (dist/linux: i386, dist/linux64: x86_64, dist/aarch64: ARM64; the files of the program, *.lng *.dlg *.hlp, must be next to it)

Keys: F10 menu, Tab switches the panel, Enter enters a directory, F1 help, F3 view, F4 edit, F5 copy, F7 make a directory,
Alt-X quit. DN names the files as DOS does: the disk C: is the root of the file system ("C:\home\you"). The first start
shows a notice of the beta (Esc closes it). Settings and history are written to the directory where DN is started (DN.INI,
dn.his).
screenshots/*.txt are the screens of tools/dn-linux-tour.py.
Based on Dos Navigator by RIT Research Labs.
DN is licensed as in LICENSE-DN.TXT, Turbo Vision as in LICENSE-TV.TXT and COPYRIGHT-TV-MAGIBLOT.TXT.
EOS
( cd "$dist" && sha256sum dn *.lng *.dlg *.hlp > SHA256SUMS.TXT )
echo "dist/linux is made: $(ls "$dist" | wc -l) files"
