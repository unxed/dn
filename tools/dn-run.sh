#!/bin/sh
# Builds the DN of this repository for DOS (go32v2) and runs it in DOSBox-X without a display. The whole way:
#   1. the tree of DN (tools/dn-materialize.sh)            skip it: DN_NO_MATERIALIZE=1 (keeps build/dn as it is)
#   2. rcp.exe (the resource compiler) and dn.exe          (tools/dn-try.sh)
#   3. rcp.exe in DOSBox-X: the dialogs and strings -> ENGLISH.DLG/.LNG, RUSSIAN.*, UKRAIN.*
#   4. dn.exe in DOSBox-X: after DNDUMPSEC seconds (default 4) the screen is dumped and DN stops; the dump is rendered
# usage: tools/dn-run.sh [OUTDIR]       (default out/dnrun; all its files are rewritten)
# needs: the cross compiler and DJGPP binutils made by tools/build-fpc-go32v2.sh PREFIX (DN_PREFIX=PREFIX), or
#        DN_CROSS=<dir with lib/fpc/3.2.2/ppcross386> and DN_LINK=<dir with djgpp/bin>; dosbox-x; unrar, unzip, curl,
#        python3, patch (for the tree); CWSDPMI.EXE is fetched by tools/dos-run.sh into OUTDIR
# env: DN_LOCAL_TREE=<unpacked archive>  use it instead of fetching;  DN_TRACE=1  also write the trace of the start to
#      OUTDIR/SER.TXT through the emulated COM1 (the files of DOS are lost when DN dies, the port is not);
#      DUMPSEC=N  seconds before the dump;  DN_KEYS=1C0D,3B00  keys (hex: scan code and character) put into the keyboard buffer one
#      a second before the dump (1C0D Enter, 011B Esc, 3B00 F1);  DN_EXTRA=...  more options of the compiler (e.g. -gl: line numbers)
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
out=${1:-$here/out/dnrun}; mkdir -p "$out"; out=$(cd "$out" && pwd)
if [ -n "${DN_PREFIX:-}" ]; then
    : "${DN_CROSS:=$DN_PREFIX/fpc}"; : "${DN_LINK:=$DN_PREFIX}"
fi
[ -n "${DN_CROSS:-}" ] && [ -n "${DN_LINK:-}" ] || { echo "set DN_PREFIX (tools/build-fpc-go32v2.sh PREFIX) or DN_CROSS and DN_LINK" >&2; exit 1; }
export DN_CROSS DN_LINK
tmp=${TMPDIR:-/tmp}; export TMPDIR=$tmp
[ -n "${DN_NO_MATERIALIZE:-}" ] || "$here/tools/dn-materialize.sh" dnosp214 >/dev/null
echo "== build"
for p in rcp dn; do
    "$here/tools/dn-try.sh" $p.pas | grep -E "Error|Fatal|bytes code" || true
    [ -f "$tmp/dn-try-o/$p.exe" ] || { echo "$p.exe was not built" >&2; exit 1; }
done
# CWSDPMI.EXE (the DPMI host) is fetched by dos-run.sh; a trivial run is enough to get it
[ -f "$out/CWSDPMI.EXE" ] || { cp "$tmp/dn-try-o/rcp.exe" "$out/RCP.EXE"; "$here/tools/dos-run.sh" "$out" RCP.EXE >/dev/null 2>&1 || true; }
echo "== resources (rcp.exe in DOSBox-X)"
b=$here/build/dn
cp "$tmp/dn-try-o/rcp.exe" "$out/RCP.EXE"
cp "$b/rcpvpd.ini" "$b/dnhelp.pas" "$b/commands.pas" "$b/stdefine.inc" "$out/"
rm -rf "$out/RESOURCE"; cp -r "$b/RESOURCE" "$out/RESOURCE"; mkdir -p "$out/EXE.D32"
dbx() {   # dbx 'DOS command line' [extra dosbox-x options]
    cmd=$1; shift
    (cd "$out" && SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout -k 5 "${DOS_TIMEOUT:-150}" dosbox-x -silent -nogui \
        -noconsole -defaultconf "$@" -c "mount c $out" -c "c:" -c "set DNDUMP=SCR.DAT" -c "set DNDUMPSEC=${DUMPSEC:-4}" \
        ${DN_KEYS:+-c "set DNKEYS=$DN_KEYS"} ${DN_TRACE:+-c "set DNSERIAL=1"} -c "$cmd" -c "exit" >/dev/null 2>&1) || true
}
dbx "RCP.EXE D > RCP.TXT"
tr -d '\r' < "$out/RCP.TXT" | sed 's/([0-9]*)//g' | grep -E "Writing|rror|nresolved" || true
cp "$out"/EXE.D32/*.LNG "$out"/EXE.D32/*.DLG "$out/" 2>/dev/null || { echo "no resources were made" >&2; exit 1; }
echo "== DN (dosbox-x)"
cp "$tmp/dn-try-o/dn.exe" "$out/DN.EXE"
rm -f "$out/SCR.DAT" "$out/DNLOG.TXT" "$out/DNERR.TXT" "$out/SER.TXT"
# the state that DN saves (a file that a dead run left empty is a "damaged" file for the next one)
rm -rf "$out/DN.HIS" "$out/DN.INI" "$out/DN.ERR" "$out/DN0.SWP" "$out/DNINI.IN_" "$out/TEM"
if [ -n "${DN_TRACE:-}" ]; then dbx "DN.EXE > OUT.TXT" -set "serial serial1=file file:SER.TXT"; else dbx "DN.EXE > OUT.TXT"; fi
[ -f "$out/DNLOG.TXT" ] && cat "$out/DNLOG.TXT"
if [ -f "$out/SCR.DAT" ]; then
    python3 "$here/tools/render-dump.py" "$out/SCR.DAT" "$out/SCR.PNG" || true
    echo "screen: $out/SCR.DAT (text above), $out/SCR.PNG if Pillow is installed"
else
    echo "no screen dump: DN died before the first idle. Look at $out/DNERR.TXT (the tail of the trace; run again with DN_TRACE=1)" >&2
fi
