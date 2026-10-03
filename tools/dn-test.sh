#!/bin/sh
# Unit tests of DN (dn/tests/t_*.pas), native: tools/dn-test.sh   (needs fpc on PATH; the DN units are compiled as for linux)
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
. "$here/tools/need-tv.sh"
w=${DN_TEST_WORK:-$here/build/dn-tests}; mkdir -p "$w/shims" "$w/obj"
python3 "$here/tools/gen-shim.py" "$here/dn/shims/shims.map" "$w/shims" "$here/tv/src" >/dev/null
fail=0
for t in "$here"/dn/tests/t_*.pas; do
    n=$(basename "$t" .pas)
    out=$(cd "$here/dn/tests" && fpc -Mdelphi -Sh- -Rintel -Se300 -dDPMI32 -dLINUX -Fu../src-linux -Fu../src -Fu"$w/shims" \
          -Fu../../tv/src -Fi. -Fi../shims -Fi../src -FU"$w/obj" -FE"$w/obj" "$t" 2>&1) || true
    if echo "$out" | grep -qE "Error|Fatal"; then echo "BUILD FAIL $n"; echo "$out" | grep -E "Error|Fatal" | head -3; fail=1; continue; fi
    r=$("$w/obj/$n" 2>&1 | tail -1); echo "$n: $r"
    case "$r" in "ALL OK"*) ;; *) fail=1;; esac
done
exit $fail
