#!/bin/sh
# Compiles one unit (or the program) of build/dn with the options of the port, prints the first errors.
# usage: tools/dn-try.sh UNIT.pas [N]     N = how many lines (default 12)
here=$(cd "$(dirname "$0")/.." && pwd)
out=${TMPDIR:-/tmp}/dn-try-o; mkdir -p "$out"
cd "$here/build/dn" || exit 1
fpc -Mobjfpc -Rintel -Se300 -Fu. -Fu"$here/build/probe/alias" -Fu"$here/dn/new" -Fu"$here/tv/src" -FU"$out" -Cn -vewn -dDPMI32 "$1" 2>&1 \
    | grep -a -E 'Error|Fatal' | head -${2:-12}
