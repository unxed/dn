#!/bin/sh
# Checks the separation of the projects in this repository (see README.md):
#  - tv/ does not use anything but its own units and the RTL;
#  - every tv/src unit says where it comes from: "Translated from magiblot/tvision @"
#    (then it points to COPYRIGHT.magiblot) or "MIT";
#  - tv/ does not mention dn/;
#  - dn/ does not contain files of tv/ (same names) and no Borland sources by name;
#  - dn/PROVENANCE.md (the origin of the files of dn/src) is up to date.
# usage: tools/check-layout.sh      (from the root of the repository)
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
. "$here/tools/need-tv.sh"
fail=0
err() { echo "layout: $*" >&2; fail=1; }

# 1. units used by tv/
own=$(ls tv/src/*.pas tv/tests/*.pas | sed 's|.*/||; s|\.pas$||' | tr 'A-Z' 'a-z' | sort -u | tr '\n' ' ')
allowed="system sysutils dos go32 objpas math strings classes baseunix unix termio"
for f in tv/src/*.pas tv/tests/*.pas tv/dostests/*.pas tv/demo/*.pas; do
    [ -f "$f" ] || continue
    # the "uses" clauses: from "uses" to the first ";"
    units=$(awk 'BEGIN{IGNORECASE=1} /^[ \t]*uses[ \t]*$|^[ \t]*uses[ \t]/{u=1} u{print} u&&/;/{u=0}' "$f" \
        | sed 's/{[^}]*}//g; s/(\*.*\*)//g; s/^[ \t]*uses//I' | tr ',;' '\n\n' | tr -d ' \t\r' \
        | tr 'A-Z' 'a-z' | grep -v '^$' | sort -u)
    for u in $units; do
        case " $own $allowed " in *" $u "*) ;; *) err "$f uses the unit '$u' that is not part of tv/ or the RTL";; esac
    done
done

# 2. origin notes
for f in tv/src/*.pas; do
    if grep -q 'Translated from magiblot/tvision @' "$f"; then
        grep -q 'COPYRIGHT.magiblot' "$f" || err "$f is translated but does not point to COPYRIGHT.magiblot"
    elif ! grep -q 'MIT' "$f"; then
        err "$f has no origin note (Translated from magiblot/tvision @ ... / MIT)"
    fi
done

# 3. tv/ does not know dn/
if grep -rIl --include='*.pas' --include='*.inc' -E '(^|[^A-Za-z])dn/|DOS Navigator|DNApp' tv/src tv/tests tv/dostests tv/demo 2>/dev/null | grep .; then
    err "tv/ sources mention dn/ or DOS Navigator (see the lines above)"
fi

# 4. dn/ is not a copy of tv/
if [ -d dn ]; then
    for f in tv/src/*.pas; do
        b=$(basename "$f")
        [ -e "dn/$b" ] && err "dn/$b has the name of a unit of tv/ (the projects keep their units apart)"
    done
    find dn -type d -name ref | grep . && err "dn/ must not hold a reference corpus"
fi

# 5. the manifest of the origin of the files of dn/src
python3 bootstrap/tools/dn-manifest.py --check >/dev/null || err "dn/PROVENANCE.md is not up to date (run bootstrap/tools/dn-manifest.py)"

[ "$fail" -eq 0 ] && echo "layout: ok"
exit "$fail"
