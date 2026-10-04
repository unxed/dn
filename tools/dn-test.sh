#!/bin/sh
# Unit tests of DN (dn/tests/t_*.pas), native: tools/dn-test.sh   (needs fpc on PATH; the DN units are compiled as for linux)
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
. "$here/tools/need-tv.sh"

# The migration is complete only when the legacy type spelling is absent from
# the repository sources.  Keep the pattern split so this check does not match
# its own implementation.
if rg -i -n --hidden -g '!.git/**' -g '!build/**' -g '!tv/**' 'obj[e]ct' "$here"; then
    echo "SOURCE GATE FAIL: legacy type spelling is still present" >&2
    exit 1
fi

w=${DN_TEST_WORK:-$here/build/dn-tests}; mkdir -p "$w/shims" "$w/obj"
python3 "$here/tools/gen-shim.py" "$here/dn/compat/shims/shims.map" "$w/shims" "$here/tv/src" >/dev/null
fail=0
for t in "$here"/dn/tests/t_*.pas; do
    n=$(basename "$t" .pas)
    out=$(cd "$here/dn/tests" && fpc -Mdelphi -Sh- -Rintel -Se300 -dDPMI32 -dLINUX -Fu../compat/linux -Fu../compat -Fu../archives -Fu../src -Fu"$w/shims" \
          -Fu../../tv/src -Fi. -Fi../compat/shims -Fi../src -FU"$w/obj" -FE"$w/obj" "$t" 2>&1) || true
    if echo "$out" | grep -qE "Error:|Fatal:"; then echo "BUILD FAIL $n"; echo "$out" | grep -E "Error:|Fatal:" | head -3; fail=1; continue; fi
    r=$("$w/obj/$n" 2>&1 | tail -1); echo "$n: $r"
    case "$r" in "ALL OK"*) ;; *) fail=1;; esac
done
exit $fail
