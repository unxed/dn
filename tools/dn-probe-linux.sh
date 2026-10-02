#!/bin/sh
# Compiles every unit of build/dn-linux for i386-linux and prints the first error of each unit that fails (the work list of
# the Linux layer, PLAN.md). Units are compiled in the order of the dependencies by the compiler itself: a unit that fails
# stops the units that use it, so the first errors are the root causes. usage: DN_LINUX=PREFIX tools/dn-probe-linux.sh [UNIT...]
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
export DN_TARGET=linux
. "$here/dn/targets.sh"; . "$DN_TARGET_ENV"
: "${DN_LINUX:?set DN_LINUX}"
tree="$here/build/$DN_TREE"; out=${TMPDIR:-/tmp}/dn-probe-linux-o; rm -rf "$out"; mkdir -p "$out"
PPC=$DN_LINUX/lib/fpc/3.2.2/ppcross386
cd "$tree"
units=${*:-$(ls | grep -i '\.pas$' | tr 'A-Z' 'a-z' | sed 's/\.pas$//' | sort)}
ok=0; bad=0
for u in $units; do
    grep -qi '^[[:space:]]*program[[:space:]]' "$u.pas" && continue
    r=$(PATH="$DN_LINUX/bin:$PATH" $PPC -Tlinux -Pi386 -XPi386-linux- $DN_FPC_OPTS -Se300 -Fu. -Fu"$here/dn/new" -Fu"$here/tv/src" \
        -Fu"$DN_LINUX/units/i386-linux" -FU"$out" -FE"$out" -Cn -vewn "$u.pas" 2>&1 | grep -a -E 'Error|Fatal: (Can|Compilation aborted)' | grep -a -v "Compilation aborted" | head -1)
    if [ -z "$r" ]; then ok=$((ok+1)); else bad=$((bad+1)); echo "$u: $r"; fi
done
echo "ok: $ok  failed: $bad"
