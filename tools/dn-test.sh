#!/bin/sh
# Unit tests of DN (dn/tests/t_*.pas), native: tools/dn-test.sh [t_name ...]   (needs fpc on PATH; the DN units are compiled as for linux)
# The units that the tests use are built once (one compiler run for the UTF-8 build, one for the code page build, beside the class
# gate); then the tests are built and run side by side (DN_TEST_JOBS, default nproc), each with a directory of its own for its
# objects, its TMPDIR and its HOME. Each test prints "ALL OK" as its last line when all checks pass.
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
w=${DN_TEST_WORK:-$here/build/dn-tests}; mkdir -p "$w"
w=$(cd "$w" && pwd)

# opts KIND: the options of the compiler for the units of the kind (u8: UTF-8 inside, cp: the code page inside), run in dn/tests
opts() {
    u8=-dDNUTF8; [ "$1" = cp ] && u8=-dNOTUTF8
    echo "-Mdelphi -Sh- -Rintel -Se300 -dDPMI32 -dLINUX $u8 -Fu../compat/linux -Fu../compat -Fu../archives -Fu../src -Fu../lib/localecp
          -Fu../lib/zipcharset -Fu$w/shims -Fu../../tv/src -Fu../../tve/src -Fi../../tv/src -Fi. -Fi../compat/shims -Fi../src -Fi../lib/localecp"
}
kind() { if grep -q "DN_TEST: code page build" "$here/dn/tests/$1.pas"; then echo cp; else echo u8; fi; }

if [ "${1:-}" = "--one" ]; then                         # one test: build it, run it, write $w/$n.res
    n=$2; k=$(kind "$n"); d="$w/t/$n"; rm -rf "$d"; mkdir -p "$d/tmp" "$d/home"
    out=$(cd "$here/dn/tests" && fpc -Fu"$w/lib-$k" $(opts "$k") -FU"$d" -FE"$d" "$n.pas" 2>&1) || true
    if echo "$out" | grep -qE "Error:|Fatal:"; then
        { echo "BUILD FAIL $n"; echo "$out" | grep -E "Error:|Fatal:" | head -3; } > "$w/$n.res"; exit 0
    fi
    res=${DN_RES_DIR:-$([ -f "$here/out/linux64/english.dlg" ] && echo "$here/out/linux64")}
    (cd "$here/dn/tests" && DN_RES_DIR=$res TMPDIR="$d/tmp" HOME="$d/home" "$d/$n" > "$w/$n.txt" 2>&1) || true
    r=$(tail -1 "$w/$n.txt"); echo "$n: $r" > "$w/$n.res"
    case "$r" in "ALL OK"*) ;; *) grep -E '^FAIL' "$w/$n.txt" | head -10 >> "$w/$n.res";; esac
    exit 0
fi

. "$here/tools/need-tv.sh"
(CLASS_GATE_STRICT=1 "$here/tools/class-gate.sh" > "$w/class-gate.txt" 2>&1; echo $? > "$w/class-gate.rc") &
mkdir -p "$w/shims"
python3 "$here/tools/gen-shim.py" "$here/dn/compat/shims/shims.map" "$w/shims" "$here/tv/src" >/dev/null

if [ $# -gt 0 ]; then tests=$(for n in "$@"; do basename "${n%.pas}"; done); else tests=$(ls "$here"/dn/tests/t_*.pas | xargs -n1 basename | sed 's/\.pas$//'); fi

# the units of the tests of a kind, once, in one compiler run (every test then reads them from $w/lib-KIND, first in its unit path);
# the two kinds side by side
for k in u8 cp; do
    names=$(for n in $tests; do [ "$(kind "$n")" = $k ] && echo "$here/dn/tests/$n.pas"; done)
    rm -rf "$w/lib-$k"; mkdir -p "$w/lib-$k"
    [ -z "$names" ] && continue
    { echo "program allunits;"; echo "uses"
      # the names of the uses clauses (the directives and comments dropped), each once
      awk 'tolower($0) ~ /^[[:space:]]*uses([[:space:]]|$)/ { p = 1 } p { print } p && /;/ { p = 0; nextfile }' $names | sed 's/{[^}]*}//g; s/^[[:space:]]*uses\b//I; s/;.*//' |
          tr ',' '\n' | tr -d ' \t\r' | grep -v '^$' | awk '!s[tolower($0)]++' | paste -sd, -
      echo "; begin end."; } > "$w/lib-$k/allunits.pas"
    (cd "$here/dn/tests" && fpc $(opts $k) -FU"$w/lib-$k" -FE"$w/lib-$k" "$w/lib-$k/allunits.pas" > "$w/lib-$k/build.txt" 2>&1) &
done
wait
fail=0
for k in u8 cp; do
    if [ -f "$w/lib-$k/build.txt" ] && grep -qE "Error:|Fatal:" "$w/lib-$k/build.txt"; then
        echo "BUILD FAIL the units of the tests ($k)"; grep -E "Error:|Fatal:" "$w/lib-$k/build.txt" | head -5; fail=1
    fi
done

cat "$w/class-gate.txt"; [ "$(cat "$w/class-gate.rc")" = 0 ] || fail=1
[ $fail = 0 ] || exit 1

for n in $tests; do rm -f "$w/$n.res"; done
echo "$tests" | xargs -P "${DN_TEST_JOBS:-$(nproc)}" -n1 "$here/tools/dn-test.sh" --one

for n in $tests; do
    if [ -f "$w/$n.res" ]; then cat "$w/$n.res"; else echo "NO RESULT $n"; fail=1; continue; fi
    head -1 "$w/$n.res" | grep -q ": ALL OK" || fail=1
done
exit $fail
