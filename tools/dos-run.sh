#!/bin/sh
# Runs a go32v2 program in DOSBox-X without a display and prints its output.
# usage: tools/dos-run.sh DIR PROGRAM.EXE
# The program's stdout is redirected to DIR/OUT.TXT inside DOS and echoed here.
# CWSDPMI.EXE (the DPMI host, not committed) is fetched into DIR when missing.
# Exit status: 0 always; callers grep the output (DOSBox-X does not return the
# DOS exit code).
set -eu
dir=$(cd "$1" && pwd); exe=$2
if [ ! -f "$dir/CWSDPMI.EXE" ]; then
    tmp=$(mktemp -d)
    curl -fsSL --retry 4 -o "$tmp/csdpmi.zip" https://www.delorie.com/pub/djgpp/current/v2misc/csdpmi7b.zip
    unzip -q -j -o "$tmp/csdpmi.zip" bin/CWSDPMI.EXE -d "$dir"
    rm -rf "$tmp"
fi
rm -f "$dir/OUT.TXT"
cd "$dir"
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout -k 5 120 dosbox-x -silent -nogui -noconsole -defaultconf \
    -c "mount c $dir" -c "c:" -c "$exe > out.txt" -c "exit" >/dev/null 2>&1 || true
cat OUT.TXT
