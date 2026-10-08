#!/bin/sh
# Unit tests of tv/ (tv/tests/t_*.pas), native: tools/tv-test.sh [t_name ...]   (needs fpc on PATH)
# The units and the programs are built into build/tv-tests, not into the source directories. Every test prints "ALL OK" at the end.
# The units of tv/src are built once (beside the class gate); then the tests are built and run side by side (TV_TEST_JOBS, default
# nproc), each with a directory of its own for its objects, its TMPDIR and its HOME.
# Another CPU: TV_FPC=/path/fpc-aarch64-linux (the compiler) and TV_RUN=qemu-aarch64-static (what runs the programs); t_pty needs the programs of the host, it fails there.
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
w=${TV_TEST_WORK:-$here/build/tv-tests}; mkdir -p "$w"
w=$(cd "$w" && pwd)

if [ "${1:-}" = "--one" ]; then                         # one test: build it, run it, write $w/$n.res
    n=$2; d="$w/t/$n"; rm -rf "$d"; mkdir -p "$d/tmp" "$d/home"
    out=$(cd "$here/tv/tests" && ${TV_FPC:-fpc} -Fu"$w/lib" -Fu../src -Fu. -FU"$d" -FE"$d" "$n.pas" 2>&1) || true
    if echo "$out" | grep -qE "Error|Fatal"; then
        { echo "BUILD FAIL $n"; echo "$out" | grep -E "Error|Fatal" | head -3; } > "$w/$n.res"; exit 0
    fi
    (cd "$here/tv/tests" && TMPDIR="$d/tmp" HOME="$d/home" ${TV_RUN:-} "$d/$n" > "$w/$n.txt" 2>&1) || true
    r=$(tail -1 "$w/$n.txt"); echo "$n: $r" > "$w/$n.res"
    case "$r" in "ALL OK"*) ;; *) grep -E '^FAIL' "$w/$n.txt" | head -10 >> "$w/$n.res";; esac
    exit 0
fi

. "$here/tools/need-tv.sh"
("$here/tv/tools/class-gate.sh" > "$w/class-gate.txt" 2>&1; echo $? > "$w/class-gate.rc") &
if [ $# -gt 0 ]; then tests=$(for n in "$@"; do basename "${n%.pas}"; done); else tests=$(ls "$here"/tv/tests/t_*.pas | xargs -n1 basename | sed 's/\.pas$//'); fi

# the units of tv/src, once, in one compiler run (every test then reads them from $w/lib, which comes first in its unit path)
rm -rf "$w/lib"; mkdir -p "$w/lib"
{ echo "program allunits;"; echo "uses"
  ls "$here"/tv/src/*.pas | grep -v '/tvtermoswin\.pas$' | xargs -n1 basename | sed 's/\.pas$//' | paste -sd, -
  echo "; begin end."; } > "$w/lib/allunits.pas"
out=$(cd "$here/tv/tests" && ${TV_FPC:-fpc} -Fu../src -Fu. -FU"$w/lib" -FE"$w/lib" "$w/lib/allunits.pas" 2>&1) || true
wait
fail=0
cat "$w/class-gate.txt"; [ "$(cat "$w/class-gate.rc")" = 0 ] || fail=1
if echo "$out" | grep -qE "Error|Fatal"; then echo "BUILD FAIL the units of tv/src"; echo "$out" | grep -E "Error|Fatal" | head -5; exit 1; fi
[ $fail = 0 ] || exit 1

for n in $tests; do rm -f "$w/$n.res"; done
echo "$tests" | xargs -P "${TV_TEST_JOBS:-$(nproc)}" -n1 "$here/tools/tv-test.sh" --one

for n in $tests; do
    if [ -f "$w/$n.res" ]; then cat "$w/$n.res"; else echo "NO RESULT $n"; fail=1; continue; fi
    head -1 "$w/$n.res" | grep -q ": ALL OK" || fail=1
done
exit $fail
