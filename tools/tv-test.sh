#!/bin/sh
# Unit tests of tv/ (tv/tests/t_*.pas), native: tools/tv-test.sh [t_name ...]   (needs fpc on PATH)
# The units and the programs are built into build/tv-tests, not into the source directories. Every test prints "ALL OK" at the end.
# Another CPU: TV_FPC=/path/fpc-aarch64-linux (the compiler) and TV_RUN=qemu-aarch64-static (what runs the programs); t_pty needs the programs of the host, it fails there.
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
w=${TV_TEST_WORK:-$here/build/tv-tests}; mkdir -p "$w"
cd "$here/tv/tests"
if [ $# -gt 0 ]; then tests=$(for n in "$@"; do echo "${n%.pas}.pas"; done); else tests=$(ls t_*.pas); fi
fail=0
for t in $tests; do
    n=${t%.pas}
    out=$(${TV_FPC:-fpc} -Fu../src -Fu. -FU"$w" -FE"$w" "$t" 2>&1) || true
    if echo "$out" | grep -qE "Error|Fatal"; then echo "BUILD FAIL $n"; echo "$out" | grep -E "Error|Fatal" | head -3; fail=1; continue; fi
    ${TV_RUN:-} "$w/$n" > "$w/$n.txt" 2>&1 || true
    r=$(tail -1 "$w/$n.txt"); echo "$n: $r"
    case "$r" in "ALL OK"*) ;; *) fail=1; grep -E '^FAIL' "$w/$n.txt" | head -10;; esac
done
exit $fail
