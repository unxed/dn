#!/bin/sh
# Makes dist/dos/: the DOS build of DN that can be tried without building it (DN.EXE for go32v2, the resources, the DPMI
# host, the licence texts) and screenshots of it in DOSBox-X. Run it when something visible changed (not for every commit:
# the binary is in git). usage: tools/dn-dist.sh   (the same environment as tools/dn-run.sh: DN_PREFIX or DN_CROSS+DN_LINK,
# DN_LOCAL_TREE)
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
dist=$here/dist/dos
if [ -n "${DN_PREFIX:-}" ]; then : "${DN_LINK:=$DN_PREFIX}"; fi
: "${DN_LINK:?set DN_PREFIX or DN_LINK}"
tmp=${TMPDIR:-/tmp}; work=$tmp/dn-dist; rm -rf "$work"; mkdir -p "$work" "$dist/screenshots"
# a build without line numbers and symbols (small: -Xs); the tree, rcp, the resources: tools/dn-run.sh
DN_EXTRA="-Xs" DN_TRACE="" DN_KEYS="" tools/dn-run.sh "$work/run" >/dev/null 2>&1 || true
[ -f "$work/run/DN.EXE" ] && [ -f "$work/run/ENGLISH.DLG" ] || { echo "the build failed: run tools/dn-run.sh" >&2; exit 1; }
cp "$work/run/DN.EXE" "$dist/DN.EXE"
cp "$work"/run/*.DLG "$work"/run/*.LNG "$dist/"
cp "$work/run/CWSDPMI.EXE" "$dist/"
# the documentation of CWSDPMI (its terms: the doc goes with the program)
if [ ! -f "$dist/CWSDPMI.DOC" ]; then
    curl -fsSL --retry 4 -o "$work/csdpmi.zip" https://www.delorie.com/pub/djgpp/current/v2misc/csdpmi7b.zip
    unzip -q -j -o "$work/csdpmi.zip" bin/cwsdpmi.doc -d "$work"; mv "$work/cwsdpmi.doc" "$dist/CWSDPMI.DOC"
fi
# a screenshot: scen NAME SECONDS KEYS   (a clean directory: the state that DN saves would change the run)
scen() {
    d=$work/$1; rm -rf "$d"; mkdir -p "$d"
    cp "$dist"/DN.EXE "$dist"/*.DLG "$dist"/*.LNG "$dist"/CWSDPMI.EXE "$d/"
    (cd "$d" && SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout -k 5 150 dosbox-x -silent -nogui -noconsole -defaultconf \
        -c "mount c $d" -c "c:" -c "set DNDUMP=SCR.DAT" -c "set DNDUMPSEC=$2" ${3:+-c "set DNKEYS=$3"} -c "DN.EXE > OUT.TXT" \
        -c "exit" >/dev/null 2>&1) || true
    if [ -f "$d/SCR.DAT" ]; then
        python3 "$here/tools/render-dump.py" "$d/SCR.DAT" "$dist/screenshots/$1.png" >/dev/null
        python3 "$here/tools/render-dump.py" "$d/SCR.DAT" 2>/dev/null | grep -v '^wrote\|^(no Pillow' > "$dist/screenshots/$1.txt" || true
    else
        echo "no screen dump: $1" >&2
    fi
}
scen start 4 ""
scen panels 5 "011B"
scen menu 7 "011B,4400,1C0D"
scen mkdir 6 "011B,4100"
scen quit 6 "011B,A2D00"
( cd "$dist" && sha256sum DN.EXE *.DLG *.LNG CWSDPMI.EXE > SHA256SUMS.TXT )
echo "dist/dos is made: $(ls "$dist" | wc -l) files"
