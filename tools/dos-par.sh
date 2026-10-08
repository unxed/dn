#!/bin/sh
# Runs go32v2 programs in DOSBox-X side by side (they wait for the emulator, not for the CPU): each one in a directory of its own
# (DIR/run-NAME, with a copy of the program and of CWSDPMI.EXE, and a HOME of its own), by tools/dos-run.sh; the output of each
# goes to DIR/NAME.txt. usage: tools/dos-par.sh DIR "PROGRAM.EXE [ARGS]"...   (the programs are in DIR; DOS_JOBS, default 8)
# Exit status: 0 always, as tools/dos-run.sh; callers grep DIR/NAME.txt.    (MIT, see LICENSE)
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
dir=$(cd "$1" && pwd); shift
if [ "${1:-}" = "--one" ]; then
    cmd=$2; exe=${cmd%% *}; n=${exe%.*}; n=${n%.EXE}; d="$dir/run-$n"
    rm -rf "$d"; mkdir -p "$d/home"
    cp "$dir/$exe" "$dir/CWSDPMI.EXE" "$d/"
    HOME="$d/home" "$here/tools/dos-run.sh" "$d" "$cmd" > "$dir/$n.txt" 2>&1 || true
    exit 0
fi
# the DPMI host once, before the copies (tools/dos-run.sh fetches it into a directory that lacks it)
if [ ! -f "$dir/CWSDPMI.EXE" ]; then
    tmp=$(mktemp -d)
    curl -fsSL --retry 4 -o "$tmp/csdpmi.zip" https://www.delorie.com/pub/djgpp/current/v2misc/csdpmi7b.zip
    unzip -q -j -o "$tmp/csdpmi.zip" bin/CWSDPMI.EXE -d "$dir"
    rm -rf "$tmp"
fi
for c in "$@"; do printf '%s\n' "$c"; done | tr '\n' '\0' | xargs -0 -P "${DOS_JOBS:-8}" -I{} "$here/tools/dos-par.sh" "$dir" --one {}
