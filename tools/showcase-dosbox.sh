#!/bin/sh
# Showcase: builds the DOS demo of tv/ (tv/demo/tvdemo.pas) and runs it in DOSBox-X, so that
# what we have can be tried by hand. The DOS code page (and so the single-byte translation of
# the screen) is the one DOS has chosen; to try another one, pass DOSBox-X commands that set it
# (e.g. `-c "chcp 866"` where your DOSBox-X has CHCP and the page files) before the program.
# usage: tools/showcase-dosbox.sh [extra dosbox-x options...]
# Needs: the cross compiler (tools/build-fpc-go32v2.sh), dosbox-x, curl, unzip.
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
fpc=${FPC_GO32V2:-$HOME/fpc-go32v2/bin/fpc-go32v2}
out="$here/build/showcase"
mkdir -p "$out"
if [ ! -x "$fpc" ]; then
    echo "showcase: no cross compiler at $fpc (run tools/build-fpc-go32v2.sh)" >&2
    exit 1
fi
(cd "$here/tv/demo" && "$fpc" -Fu../src -Fu. -FE"$out" tvdemo.pas | grep -E 'Error|Fatal' && exit 1) || true
test -f "$out/tvdemo.exe" || { echo "showcase: the demo did not build" >&2; exit 1; }
if [ ! -f "$out/CWSDPMI.EXE" ]; then
    tmp=$(mktemp -d)
    curl -fsSL --retry 4 -o "$tmp/csdpmi.zip" https://www.delorie.com/pub/djgpp/current/v2misc/csdpmi7b.zip
    unzip -q -j -o "$tmp/csdpmi.zip" bin/CWSDPMI.EXE -d "$out"
    rm -rf "$tmp"
fi
echo "showcase: running tvdemo.exe in DOSBox-X (the directory $out is the drive C:)"
exec dosbox-x -defaultconf -c "mount c $out" -c "c:" "$@" -c "tvdemo.exe"
