#!/bin/sh
# ONE COMMAND: builds DOS Navigator from dn/src and tv/src with your FPC: the programs (rcp, the resource compiler, and dn), the resources
# (*.LNG, *.DLG, made by rcp from dn/src/RESOURCE) and the help (*.HLP, made by tv/tools/tvhc.pas).
#
# usage: tools/build.sh TARGET [OUTDIR]          TARGET: linux64 | linux | aarch64 | dos | win64 | win32        (OUTDIR default: out/TARGET)
#   linux64   x86_64 Linux, the fpc of your system (FPC=...)                          needs: fpc 3.2.x, python3
#   linux     i386 Linux (static; runs on a 64-bit kernel), DN_LINUX=PREFIX            needs: tools/build-fpc-i386-linux.sh PREFIX
#   aarch64   ARM64 Linux (static), DN_AARCH64=PREFIX                                needs: tools/build-fpc-aarch64-linux.sh PREFIX (+ the fpc of the host for the resources)
#   win64     Windows x86_64, DN_WIN=PREFIX                                           needs: tools/build-fpc-windows.sh PREFIX win64 (+ the fpc of the host for the resources)
#   win32     Windows i386, DN_WIN32=PREFIX                                           needs: tools/build-fpc-windows.sh PREFIX win32
#   dos       DOS (go32v2), DN_PREFIX=PREFIX                                           needs: tools/build-fpc-go32v2.sh PREFIX, dosbox-x (rcp runs in it)
# env: DN_UTF8=0 (linux, windows: the old DN with the code page inside; the default is UTF-8 inside); DN_EXTRA=-gl (more options of the compiler); DN_SRC=<a copy of dn/src> (e.g. with the traces of tools/dn-trace-*.py)
# Run DN (linux): cd OUTDIR && ./dn        (the *.LNG *.DLG *.HLP files are next to it)
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
. "$here/tools/need-tv.sh"
DN_TARGET=${1:?usage: tools/build.sh linux64|linux|dos|win64|win32 [OUTDIR]}; export DN_TARGET
# UTF-8 inside DN (-dDNUTF8) is the default on Linux and Windows; DN_UTF8=0 builds the old one (the code page inside); DOS: always the code page
case "$DN_TARGET" in linux*|aarch64) : "${DN_UTF8:=1}";; win*) : "${DN_UTF8:=1}";; *) DN_UTF8=0;; esac
export DN_UTF8
if [ "$DN_UTF8" != 0 ]; then case "${DN_EXTRA:-}" in *-dDNUTF8*) ;; *) DN_EXTRA="${DN_EXTRA:-} -dDNUTF8";; esac; fi
export DN_EXTRA
out=${2:-$here/out/$DN_TARGET}; mkdir -p "$out"; out=$(cd "$out" && pwd)
. "$here/tools/dn-env.sh"
src=${DN_SRC:-$here/dn/src}
exe=; case "$DN_TARGET" in dos|win*) exe=.exe;; esac
echo "== shims (generated from tv/src)"
dn_gen_shims
echo "== compile ($DN_TARGET)"
mkdir -p "$DN_OBJ"
progs="rcp dn"; case "$DN_TARGET" in win*|aarch64) progs=dn;; esac      # the resources of Windows are made by rcp of the host (they are the same for all the targets)
for p in $progs; do
    rm -f "$DN_OBJ/$p$exe"
    dn_compile $p.pas > "$DN_OBJ/$p.log" || true
    grep -a -E "Error|Fatal|undefined" "$DN_OBJ/$p.log" | head -20 || true
    [ -f "$DN_OBJ/$p$exe" ] || { echo "$p was not built (the whole log: $DN_OBJ/$p.log)" >&2; exit 1; }
done
case "$DN_TARGET" in
win*|aarch64)
    echo "== resources and help (made by the build for linux64: the same files for all the targets)"
    host=$tmp/dn-res-host
    "$here/tools/build.sh" linux64 "$host" >/dev/null
    cp "$host"/*.LNG "$host"/*.DLG "$host"/*.HLP "$out/"
    cp "$DN_OBJ/dn$exe" "$out/dn$exe"
    rm -rf "$out/XLT"; cp -r "$here/dn/data/XLT" "$out/XLT"      # the layout tables (ru441.xlt: DN looks for them in XLT next to the program)
    echo "built: $out/dn$exe   (the resources and the help are next to it)"
    exit 0 ;;
esac
echo "== resources (rcp)"
w=$out/rcp.work; rm -rf "$w"; mkdir -p "$w/EXE.D32"
# DN names its files in capitals; the file system may be case sensitive: the names that DN asks for
cp "$src/rcpvpd.ini" "$w/RCPVPD.INI"; cp "$src/dnhelp.pas" "$w/DNHELP.PAS"; cp "$src/commands.pas" "$w/COMMANDS.PAS"; cp "$src/stdefine.inc" "$w/STDEFINE.INC"
cp -r "$src/RESOURCE" "$w/RESOURCE"
case "${DN_EXTRA:-}" in *-dDNUTF8*)      # DN inside in UTF-8 (the branch utf8-inside): the texts of the resources are UTF-8
    for f in "$w"/RESOURCE/RUSSIAN/dn.dn? "$w"/RESOURCE/UKRAIN/dn.dn?; do iconv -f cp866 -t utf-8 "$f" > "$f.u8" && mv "$f.u8" "$f"; done ;;
esac
if [ "$DN_TARGET" = dos ]; then
    cp "$DN_OBJ/rcp.exe" "$w/RCP.EXE"
    "$here/tools/dos-run.sh" "$w" RCP.EXE >/dev/null 2>&1 || true          # fetches CWSDPMI.EXE
    ( cd "$w" && SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout -k 5 "${DOS_TIMEOUT:-150}" dosbox-x -silent -nogui -noconsole -defaultconf \
        -c "mount c $w" -c "c:" -c "RCP.EXE D > RCP.TXT" -c "exit" >/dev/null 2>&1 ) || true
    [ -f "$w/RCP.TXT" ] && tr -d '\r' < "$w/RCP.TXT" | sed 's/([0-9]*)//g' | grep -E "Writing|rror|nresolved" || true
else
    cp "$DN_OBJ/rcp" "$w/rcp"
    ( cd "$w" && ./rcp D 2>&1 | sed 's/([0-9]*)//g' | grep -E "Writing|rror|nresolved|Undefined" || true )
fi
cp "$w"/EXE.D32/*.LNG "$w"/EXE.D32/*.DLG "$out/" 2>/dev/null || { echo "no resources were made" >&2; exit 1; }
echo "== help (tv/tools/tvhc.pas, native)"
th=$tmp/tvhc-o; mkdir -p "$th"
fpc -Fu"$here/tv/src" -FU"$th" -FE"$th" -vew "$here/tv/tools/tvhc.pas" | grep -E "Error|Fatal" || true
for l in ENGLISH RUSSIAN UKRAIN; do
    htx=$src/RESOURCE/$l/dnhelp.htx
    case "${DN_EXTRA:-}" in *-dDNUTF8*)      # the help in UTF-8 as well (the text is CP866 in the sources)
        if [ "$l" != ENGLISH ]; then htx=$tmp/dnhelp-$l.htx; iconv -f cp866 -t utf-8 "$src/RESOURCE/$l/dnhelp.htx" > "$htx"; fi ;;
    esac
    "$th/tvhc" "$htx" "$out/$l.HLP" /4DN_OSP | sed 's|^|  |'
done
cp "$DN_OBJ/dn$exe" "$out/dn$exe"
rm -rf "$out/XLT"; cp -r "$here/dn/data/XLT" "$out/XLT"      # the layout tables (ru441.xlt: DN looks for them in XLT next to the program)
[ "$DN_TARGET" != dos ] || [ -f "$out/CWSDPMI.EXE" ] || cp "$w/CWSDPMI.EXE" "$out/" 2>/dev/null || true
echo "built: $out/dn$exe   (the resources and the help are next to it)"
