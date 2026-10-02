#!/bin/sh
# Compiles one unit (or the program) of build/dn with the options of the port (dn/target.env), prints the
# first errors. usage: tools/dn-try.sh UNIT.pas [N]     N = how many lines (default 12)
# DN_CROSS=<dir of the unpacked go32v2 cross compiler, with lib/fpc/3.2.2/ppcross386> compiles for DOS (the real
# target: the native Dos unit differs, e.g. FileRec.Name is wide there)
# DN_LINK=<dir with djgpp/bin (DJGPP binutils)> also links (the program is written to $TMPDIR/dn-try-o/); prints the linker errors
# DN_TARGET=linux compiles build/dn-linux for i386-linux with the cross compiler of tools/build-fpc-i386-linux.sh
# (DN_LINUX=<its PREFIX>; the ppcross386 of DN_CROSS is used if DN_LINUX has none)
here=$(cd "$(dirname "$0")/.." && pwd)
. "$here/dn/targets.sh"
. "$DN_TARGET_ENV"
out=${TMPDIR:-/tmp}/dn-try-o; [ "$DN_TARGET" = dos ] || out=$out-$DN_TARGET; mkdir -p "$out"
cd "$here/build/$DN_TREE" || exit 1
if [ "$DN_TARGET" = linux ]; then
    : "${DN_LINUX:?set DN_LINUX (tools/build-fpc-i386-linux.sh PREFIX)}"
    PPC=$DN_LINUX/lib/fpc/3.2.2/ppcross386; [ -x "$PPC" ] || PPC=$DN_CROSS/lib/fpc/3.2.2/ppcross386
    PATH="$DN_LINUX/bin:$PATH" $PPC -Tlinux -Pi386 -XPi386-linux- $DN_FPC_OPTS -Se300 -Fu. -Fu"$here/dn/new" \
        -Fu"$here/tv/src" $DN_LINUX_FU -FU"$out" -FE"$out" $DN_EXTRA -vewn "$1" 2>&1 \
        | grep -a -E 'Error|Fatal|undefined|Linking|bytes' | head -${2:-12}
    exit 0
fi
if [ -n "$DN_CROSS" ]; then
    X=$DN_CROSS/lib/fpc/3.2.2; U=$X/units/go32v2
    LINKOPT=-Cn
    [ -n "$DN_LINK" ] && { PATH="$DN_LINK/djgpp/bin:$PATH"; LINKOPT=; }
    $X/ppcross386 -Tgo32v2 -XPi586-pc-msdosdjgpp- $DN_FPC_OPTS -Se300 -Fu. -Fu"$here/dn/new" \
        -Fu"$here/tv/src" -Fu"$U/*" -Fu"$U/rtl" -FU"$out" -FE"$out" $LINKOPT $DN_EXTRA -vewn "$1" 2>&1 | grep -a -E 'Error|Fatal|undefined|Linking|bytes' | head -${2:-12}
    exit 0
fi
fpc $DN_FPC_OPTS -Se300 -Fu. -Fu"$here/dn/new" -Fu"$here/tv/src" -FU"$out" -Cn -vewn "$1" 2>&1 \
    | grep -a -E 'Error|Fatal' | head -${2:-12}
