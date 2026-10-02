#!/bin/sh
# Tries to compile every unit of build/dn (made by tools/dn-materialize.sh) with FPC and
# prints a compact summary: how many units compile, and the first error of the others,
# grouped by the kind of message. The numbers are the work list for the porting patches
# of reason (д) in dn/patches and for the adapters in dn/new (PLAN.md, milestone 4).
# usage: tools/dn-probe.sh [FPC-MODE] [EXTRA FPC OPTIONS...]   (default mode: tp)
# Needs: fpc. The tree must exist (tools/dn-materialize.sh).
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
tree="$here/build/dn"
mode=${1:-tp}
[ $# -gt 0 ] && shift
out="$here/build/probe"
rm -rf "$out"; mkdir -p "$out/o" "$out/log" "$out/alias"
# DN is a Virtual Pascal project: its vpc.cfg maps units with -A (e.g. -ALFN=LFNVP;WINCLP=WINCLPVP),
# FPC has no such option, so the probe makes a copy of the source under the alias name
# (the real fix is a patch of reason (д) or a unit in dn/new)
cfg=$(ls "$tree" | grep -i '^vpc\.cfg$' | head -1)
if [ -n "$cfg" ]; then
    grep -i '^-A' "$tree/$cfg" | tr -d '\r' | sed 's/^-[Aa]//' | tr ';' '\n' | while IFS== read -r alias real; do
        [ -n "$alias" ] && [ -n "$real" ] || continue
        src=$(ls "$tree" | grep -i "^$real\.pas$" | head -1)
        [ -n "$src" ] || continue
        lower=$(echo "$alias" | tr 'A-Z' 'a-z')
        sed "s/^\([[:space:]]*[Uu][Nn][Ii][Tt][[:space:]]*\)$real\b/\1$alias/I" "$tree/$src" > "$out/alias/$lower.pas"
        echo "probe: alias $alias -> $real"
    done
fi
total=0; ok=0
for f in $(cd "$tree" && ls | grep -i '\.pas$' | sort); do
    # programs are not units: skip files that begin with 'program'
    if grep -qi '^[[:space:]]*program[[:space:]]' "$tree/$f"; then continue; fi
    total=$((total+1))
    b=$(echo "$f" | tr 'A-Z' 'a-z'); b=${b%.pas}
    rm -f "$out"/o/*
    if (cd "$tree" && timeout 60 fpc -M"$mode" -Fu"$tree" -Fu"$out/alias" -FU"$out/o" -vew -Cn "$@" "$f") > "$out/log/$b.txt" 2>&1; then
        ok=$((ok+1)); echo "ok $b" >> "$out/result.txt"
    else
        # the first error line, without the path
        e=$(grep -m1 -E 'Error|Fatal' "$out/log/$b.txt" | sed 's/^[^(]*(\([0-9]*\),[0-9]*) /\1 /')
        # the file where the first error is (a unit that fails stops all the units that use it)
        w=$(grep -m1 -E 'Error|Fatal' "$out/log/$b.txt" | sed -n 's/^\([^(]*\)(.*/\1/p' | tr 'A-Z' 'a-z')
        echo "fail $b $e" >> "$out/result.txt"
        echo "$w" >> "$out/roots.txt"
    fi
done
echo "probe: $ok of $total units compile (mode $mode)"
echo "the first errors, by kind:"
grep '^fail' "$out/result.txt" | sed 's/^fail [^ ]* [0-9]* //' \
    | sed 's/"[^"]*"/"X"/g; s/[0-9][0-9]*/N/g' | sort | uniq -c | sort -rn | head -${PROBE_TOP:-25}
echo "the files where the first error is (a failing unit stops every unit that uses it):"
sort "$out/roots.txt" 2>/dev/null | uniq -c | sort -rn | head -${PROBE_ROOTS:-15}
