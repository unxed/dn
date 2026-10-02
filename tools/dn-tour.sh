#!/bin/sh
# A smoke tour of DN in DOSBox-X: each scenario is a start of DN from a clean state, some keys (DNKEYS, see dn/new/dnapp.pas), a
# dump of the screen; the script prints for each scenario "ok" or the top of the stack of the exception, and keeps the screens
# in OUTDIR/<name>.txt. Needs a build with line numbers (tools/dn-run.sh with DN_EXTRA=-gl) in OUTDIR (DN.EXE, *.DLG, *.LNG).
# usage: tools/dn-tour.sh OUTDIR [NAME...]      (no names: all the scenarios)
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
out=$(cd "$1" && pwd); shift
SCEN="tab:011B,0F09 f1help:011B,3B00 f2user:011B,3C00 f5copy:011B,3F00 f6ren:011B,4000 f7mkdir:011B,4100 f8del:011B,4200 altf1drive:011B,A6800 altf7find:011B,A6E00 altf10tree:011B,A6900 ctrll:011B,C260C ctrlo:011B,C180F altf5user:011B,A6C00 insert:011B,5200,5000 plus:011B,4E2B menudisk:011B,4400,4D00,1C0D menuutil:011B,4400,4D00,4D00,1C0D menupanel:011B,4400,4D00,4D00,4D00,1C0D menumgr:011B,4400,4D00,4D00,4D00,4D00,1C0D menuopt:011B,4400,4D00,4D00,4D00,4D00,4D00,1C0D menuwin:011B,4400,4D00,4D00,4D00,4D00,4D00,4D00,1C0D"
[ $# -gt 0 ] && SCEN=$(for n in "$@"; do for s in $SCEN; do case $s in $n:*) printf '%s ' "$s";; esac; done; done)
for s in $SCEN; do
    name=${s%%:*}; keys=${s#*:}
    d=$out/tour-$name; rm -rf "$d"; mkdir -p "$d"
    cp "$out/DN.EXE" "$out"/*.DLG "$out"/*.LNG "$out"/*.HLP "$out/CWSDPMI.EXE" "$d/"
    n=$(printf '%s' "$keys" | tr ',' '\n' | wc -l)
    (cd "$d" && SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout -k 5 "${DOS_TIMEOUT:-100}" dosbox-x -silent -nogui -noconsole -defaultconf \
        -set "serial serial1=file file:SER.TXT" -c "mount c $d" -c "c:" -c "set DNDUMP=SCR.DAT" -c "set DNSERIAL=1" \
        -c "set DNDUMPSEC=$((n + 4))" -c "set DNKEYS=$keys" -c "DN.EXE > OUT.TXT" -c "exit" >/dev/null 2>&1) || true
    if grep -aq '^exception' "$d/SER.TXT" 2>/dev/null; then
        printf '%-12s EXCEPTION %s\n' "$name" "$(grep -a -A3 '^exception' "$d/SER.TXT" | head -4 | tr '\n' '|' | cut -c1-230)"
    elif [ -f "$d/SCR.DAT" ]; then
        python3 "$here/tools/render-dump.py" "$d/SCR.DAT" 2>/dev/null | grep -v '^wrote\|^(no Pillow' > "$out/$name.txt" || true
        printf '%-12s ok\n' "$name"
    else
        printf '%-12s NO DUMP (hang or exit)\n' "$name"
    fi
done
