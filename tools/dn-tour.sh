#!/bin/sh
# A smoke tour of DN in DOSBox-X: each scenario is a start of DN from a clean state, some keys (DNKEYS, see dn/new/dnapp.pas), a
# dump of the screen; the script prints for each scenario "ok" or the top of the stack of the exception, and keeps the screens
# in OUTDIR/<name>.txt. The scenarios run side by side, each in a directory of its own (OUTDIR/tour-NAME). Needs a build with line numbers (tools/build.sh dos with DN_EXTRA=-gl) in OUTDIR (DN.EXE, *.dlg, *.lng).
# usage: tools/dn-tour.sh OUTDIR [NAME...]      (no names: all the scenarios)
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
out=$(cd "$1" && pwd); shift
SCEN="tab:011B,0F09 f1help:011B,3B00 f2user:011B,3C00 f5copy:011B,3F00 f6ren:011B,4000 f7mkdir:011B,4100 f8del:011B,4200 altf1drive:011B,A6800 altf7find:011B,A6E00 altf10tree:011B,A6900 ctrll:011B,C260C ctrlo:011B,C180F altf5user:011B,A6C00 mousemenu:011B@D6:0,U6:0 mousedir:011B@D2:3,U2:3,D2:3,U2:3,DD2:3,U2:3 userscr:011B,1265,2E63,2368,186F,3920,2368,1769,1C0D,C180F insert:011B,5200,5000 plus:011B,4E2B menudisk:011B,4400,4D00,1C0D menuutil:011B,4400,4D00,4D00,1C0D menupanel:011B,4400,4D00,4D00,4D00,1C0D menumgr:011B,4400,4D00,4D00,4D00,4D00,1C0D menuopt:011B,4400,4D00,4D00,4D00,4D00,4D00,1C0D menuwin:011B,4400,4D00,4D00,4D00,4D00,4D00,4D00,1C0D"
[ $# -gt 0 ] && SCEN=$(for n in "$@"; do for s in $SCEN; do case $s in $n:*) printf '%s ' "$s";; esac; done; done)
# one scenario: its result line goes to OUTDIR/tour-NAME.res (the scenarios run side by side: they wait for the emulator, not for the CPU)
one() {
    s=$1
    name=${s%%:*}; keys=${s#*:}; mouse=''
    case $keys in *@*) mouse=${keys#*@}; keys=${keys%%@*};; esac   # name:keys@mouse (DNMOUSE, see dnapp.pas)
    d=$out/tour-$name; rm -rf "$d"; mkdir -p "$d"
    cp "$out"/[Dd][Nn].[Ee][Xx][Ee] "$d/DN.EXE"; cp "$out"/*.dlg "$out"/*.lng "$out"/*.hlp "$out/cwsdpmi.exe" "$d/"
    redir=' > OUT.TXT'; [ "$name" = userscr ] && redir=''   # userscr needs the output of the programs on the screen
    n=$(printf '%s' "$keys" | tr ',' '\n' | wc -l)
    m=0; [ -n "$mouse" ] && m=$(printf '%s' "$mouse" | tr ',' '\n' | wc -l)   # a mouse event a second too
    (cd "$d" && SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout -k 5 "${DOS_TIMEOUT:-100}" dosbox-x -silent -nogui -noconsole -defaultconf \
        -set "serial serial1=file file:SER.TXT" -c "mount c $d" -c "c:" -c "set DNDUMP=SCR.DAT" -c "set DNSERIAL=1" \
        -c "set DNDUMPSEC=$((n + m + 4))" -c "set DNKEYS=$keys" ${mouse:+-c "set DNMOUSE=$mouse"} -c "DN.EXE$redir" -c "exit" >/dev/null 2>&1) || true
    if grep -aq '^exception' "$d/SER.TXT" 2>/dev/null; then
        printf '%-12s EXCEPTION %s\n' "$name" "$(grep -a -A3 '^exception' "$d/SER.TXT" | head -4 | tr '\n' '|' | cut -c1-230)"
    elif [ "$name" = userscr ] && ! grep -aq 'UserScreen [0-9]*: hi$' "$d/SER.TXT" 2>/dev/null; then
        # "echo hi" then Ctrl-O: the user screen must hold the output of the command (the trace of DNRun.ShowUserScreenDos)
        printf '%-12s FAIL (no "hi" in the user screen)\n' "$name"
        if [ -f "$d/SER.TXT" ]; then
            tail -n 80 "$d/SER.TXT"
        fi
    elif [ "$name" = mousemenu ] && ! python3 "$here/tools/render-dump.py" "$d/SCR.DAT" 2>/dev/null | grep -q 'Rename/Move'; then
        printf '%-12s FAIL (a click on File did not open the menu)\n' "$name"
    elif [ "$name" = mousedir ] && ! python3 "$here/tools/render-dump.py" "$d/SCR.DAT" 2>/dev/null | grep -q 'C:.TEMP>'; then
        # a double click on the directory TEMP enters it (the key Ctrl-PgDn goes through MessageKey, Drivers)
        printf '%-12s FAIL (a double click did not enter the directory)\n' "$name"
    elif [ -f "$d/SCR.DAT" ]; then
        python3 "$here/tools/render-dump.py" "$d/SCR.DAT" 2>/dev/null | grep -v '^wrote\|^(no Pillow' > "$out/$name.txt" || true
        printf '%-12s ok\n' "$name"
    else
        printf '%-12s NO DUMP (hang or exit)\n' "$name"
    fi
}
for s in $SCEN; do
    rm -f "$out/tour-${s%%:*}.res"
    ( one "$s" > "$out/tour-${s%%:*}.res" 2>&1 ) &
done
wait
for s in $SCEN; do cat "$out/tour-${s%%:*}.res"; done
