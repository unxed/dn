#!/bin/sh
# Unit tests of DN (dn/tests/t_*.pas), native: tools/dn-test.sh   (needs fpc on PATH; the DN units are compiled as for linux)
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
. "$here/tools/need-tv.sh"
CLASS_GATE_STRICT=1 "$here/tools/class-gate.sh"

w=${DN_TEST_WORK:-$here/build/dn-tests}; mkdir -p "$w/shims" "$w/obj"
python3 "$here/tools/gen-shim.py" "$here/dn/compat/shims/shims.map" "$w/shims" "$here/tv/src" >/dev/null
fail=0
for t in "$here"/dn/tests/t_*.pas; do
    n=$(basename "$t" .pas)
    od="$w/obj"; u8=-dDNUTF8; if grep -q "DN_TEST: code page build" "$t"; then od="$w/obj-cp"; u8=-dNOTUTF8; mkdir -p "$od"; fi         
    opts="-Sh- -Rintel -Se300 -dDPMI32 -dLINUX $u8 -Fu../compat/linux -Fu../compat -Fu../archives -Fu../src -Fu../lib/localecp -Fu../lib/zipcharset -Fu$w/shims
          -Fu../../tv/src -Fu../../tve/src -Fi../../tv/src -Fi. -Fi../compat/shims -Fi../src -Fi../lib/localecp -FU$od -FE$od"
    # tv/src/tvactions.pas has a comment inside a comment in its head, which the Delphi mode of DN does not read: it is compiled first in the mode of tv/
    (cd "$here/dn/tests" && fpc -Mobjfpc $opts ../../tv/src/tvactions.pas >/dev/null 2>&1) || true
    out=$(cd "$here/dn/tests" && fpc -Mdelphi $opts "$t" 2>&1) || true
    if echo "$out" | grep -qE "Error:|Fatal:"; then echo "BUILD FAIL $n"; echo "$out" | grep -E "Error:|Fatal:" | head -3; fail=1; continue; fi
    r=$(DN_RES_DIR=${DN_RES_DIR:-$([ -f "$here/out/linux64/english.dlg" ] && echo "$here/out/linux64")} "$od/$n" 2>&1 | tail -1); echo "$n: $r"
    case "$r" in "ALL OK"*) ;; *) fail=1;; esac
done
exit $fail
