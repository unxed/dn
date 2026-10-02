#!/bin/sh
# Makes dist/linux/: the Linux build of DN (i386, static) that can be tried without building it, with the screens of
# the pty tour as text. usage: DN_LINUX=PREFIX tools/dn-linux-dist.sh
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
dist=$here/dist/linux
tmp=${TMPDIR:-/tmp}; work=$tmp/dn-linux-dist
mkdir -p "$work" "$dist/screenshots"
# no symbols: small
DN_EXTRA="-Xs" "$here/tools/build.sh" linux "$work" >/dev/null
cp "$work/dn" "$dist/dn"
cp "$work"/*.LNG "$work"/*.DLG "$work"/*.HLP "$dist/"
cp "$here/dist/dos/LICENSE-DN.TXT" "$here/dist/dos/LICENSE-TV.TXT" "$here/dist/dos/COPYRIGHT-TV-MAGIBLOT.TXT" "$dist/"
python3 "$here/tools/dn-linux-tour.py" "$work" start f1help f3view f4edit f7mkdir f5copy menudisk quitask quit
for n in start f1help f3view f4edit f7mkdir f5copy menudisk; do
    grep -v '^[[:space:]]*$' "$work/tour-$n.txt" > "$dist/screenshots/$n.txt"
done
cat > "$dist/README.TXT" <<'EOS'
DN for Linux (i386, static: runs on a 64-bit Linux kernel, no libraries needed). EXPERIMENTAL: the Linux build of the
open DN OSP 2.14 on Turbo Vision (this repository: tv/ and dn/). It needs a terminal of at least 80x25 (xterm, the Linux
console, kitty, alacritty...); UTF-8 file names are not converted yet (Russian text is shown as it is stored).

  cd dist/linux && ./dn            (the files of the program, *.LNG *.DLG *.HLP, must be next to it)

Keys: F10 menu, Tab switches the panel, Enter enters a directory, F1 help, F3 view, F4 edit, F5 copy, F7 make a directory,
Alt-X quit. DN names the files as DOS does: the disk C: is the root of the file system ("C:\home\you"). The first start
shows a notice of the beta (Esc closes it). Settings and history are written to the directory where DN is started (DN.INI,
DN.HIS).
screenshots/*.txt are the screens of tools/dn-linux-tour.py.
DN is licensed as in LICENSE-DN.TXT, Turbo Vision as in LICENSE-TV.TXT and COPYRIGHT-TV-MAGIBLOT.TXT.
EOS
( cd "$dist" && sha256sum dn *.LNG *.DLG *.HLP > SHA256SUMS.TXT )
echo "dist/linux is made: $(ls "$dist" | wc -l) files"
