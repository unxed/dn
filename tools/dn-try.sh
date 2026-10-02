#!/bin/sh
# Compiles one unit (or the program) of build/dn with the options of the port (dn/target.env), prints the
# first errors. usage: tools/dn-try.sh UNIT.pas [N]     N = how many lines (default 12)
# DN_CROSS=<dir of the unpacked go32v2 cross compiler, with lib/fpc/3.2.2/ppcross386> compiles for DOS (the real
# target: the native Dos unit differs, e.g. FileRec.Name is wide there)
here=$(cd "$(dirname "$0")/.." && pwd)
. "$here/dn/target.env"
out=${TMPDIR:-/tmp}/dn-try-o; mkdir -p "$out"
cd "$here/build/dn" || exit 1
if [ -n "$DN_CROSS" ]; then
    X=$DN_CROSS/lib/fpc/3.2.2; U=$X/units/go32v2
    $X/ppcross386 -Tgo32v2 -XPi586-pc-msdosdjgpp- $DN_FPC_OPTS -Se300 -Fu. -Fu"$here/dn/new" \
        -Fu"$here/tv/src" -Fu"$U/*" -Fu"$U/rtl" -FU"$out" -Cn -vewn "$1" 2>&1 | grep -a -E 'Error|Fatal' | head -${2:-12}
    exit 0
fi
fpc $DN_FPC_OPTS -Se300 -Fu. -Fu"$here/dn/new" -Fu"$here/tv/src" -FU"$out" -Cn -vewn "$1" 2>&1 \
    | grep -a -E 'Error|Fatal' | head -${2:-12}
