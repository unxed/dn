#!/bin/sh
# Makes the tree of DOS Navigator from the public archive: unpack, drop the files of
# dn/exclude.list, apply dn/patches/series, add dn/new/. The result is build/dn/ (not
# committed; its code is DN's own, the Borland-origin files are not in it).
# usage: tools/dn-materialize.sh [NAME]
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
. "$here/dn/upstream.env"
name=${1:-$DN_BASE}
eval file=\$${name}_FILE
raw="$here/build/raw-$name"
out="$here/build/dn"
if [ -n "${DN_LOCAL_TREE:-}" ]; then
    # for work without the network: an unpacked copy of the archive (analysis only, never committed)
    rm -rf "$out"; mkdir -p "$out"
    src="$DN_LOCAL_TREE"; raw=$(dirname "$src")
else
    archive=$("$here/tools/dn-fetch.sh" "$name" | tail -1)
    rm -rf "$raw" "$out"
    mkdir -p "$raw" "$out"
    case "$file" in
        *.rar) unrar x -y -idq "$archive" "$raw/" ;;
        *.zip) unzip -q -o "$archive" -d "$raw" ;;
        *) echo "dn-materialize: unknown archive type $file" >&2; exit 2 ;;
    esac
    # the sources may be in a subdirectory of the archive: take the one with most .pas files
    src=$(find "$raw" -type d | while read -r d; do
            n=$(find "$d" -maxdepth 1 -iname '*.pas' | wc -l); echo "$n $d"; done | sort -rn | head -1 | cut -d' ' -f2-)
fi
cp -a "$src"/. "$out"/
echo "dn-materialize: sources from ${src#$raw/} ($(find "$out" -type f | wc -l) files)"

# exclusions
grep -v '^[[:space:]]*#' "$here/dn/exclude.list" | grep -v '^[[:space:]]*$' | while read -r pat; do
    find "$out" -ipath "$out/$pat" -type f -print -delete
done | sed 's|^|  excluded: |' || true

# the libraries of the target (DN OSP keeps the units that differ between the systems in LIB.D32, LIB.OLF,
# LIB.WLF: events, files, country_, fltl, fnotify...): those of the target go to the root of the tree,
# the others are dropped. VPSYSD32.PAS is the Virtual Pascal runtime (not DN code): our dn/new/vpsyslow.pas
# takes its place.
. "$here/dn/target.env"
if [ -n "${DN_LIB_DIR:-}" ]; then
    ld=$(ls "$out" | grep -i "^$DN_LIB_DIR\$" | head -1)
    if [ -n "$ld" ]; then
        for f in "$out/$ld"/*; do
            b=$(basename "$f"); l=$(echo "$b" | tr 'A-Z' 'a-z')
            case "$l" in
                vpsysd32.pas) ;;
                *.pas|*.inc) cp -f "$f" "$out/$b"; echo "  lib: $b" ;;
            esac
        done
    fi
    for d in "$out"/LIB.* "$out"/lib.*; do
        [ -d "$d" ] && rm -rf "$d"
    done
fi

# patches
while read -r p; do
    case "$p" in ''|'#'*) continue;; esac
    patch -p1 -d "$out" --no-backup-if-mismatch < "$here/dn/patches/$p" >/dev/null
    echo "  patch: $p"
done < "$here/dn/patches/series"

# the regions that repeat Borland code are replaced by our text (dn/rewrite/*.rw; before any other edit,
# the anchors are lines of the pristine sources)
if [ -d "$here/dn/rewrite" ]; then
    python3 "$here/tools/dn-rewrite.py" "$out" "$here/dn/rewrite" | grep -v '^  (no sha1' | sed 's|^|  rewrite: |'
fi
# mechanical edits (dn/edits/*.sed; each file names its reason): sed scripts over all the sources
if [ -d "$here/dn/edits" ]; then
    for e in "$here"/dn/edits/*.sh; do
        [ -f "$e" ] || continue
        sh "$e" "$out"
        echo "  edit: $(basename "$e")"
    done
    for e in "$here"/dn/edits/*.sed; do
        [ -f "$e" ] || continue
        find "$out" -maxdepth 1 -type f \( -iname '*.pas' -o -iname '*.inc' \) -print0 | LC_ALL=C xargs -0 sed -i -f "$e"
        echo "  edit: $(basename "$e")"
    done
    for e in "$here"/dn/edits/*.py; do
        [ -f "$e" ] || continue
        find "$out" -maxdepth 1 -type f -iname '*.pas' -print0 | xargs -0 python3 "$e" | sed 's|^.*/||; s|^|  edit '"$(basename "$e")"': |'
    done
fi

# new files
if [ -d "$here/dn/new" ]; then
    (cd "$here/dn/new" && find . -type f ! -name .gitkeep) | while read -r f; do
        mkdir -p "$out/$(dirname "$f")"; cp "$here/dn/new/$f" "$out/$f"; echo "  new: $f"; done
fi
# the shim units: the names of the TV units of Borland that DN uses, from our tv/ (tools/gen-shim.py)
if [ -f "$here/dn/new/shims.map" ]; then
    python3 "$here/tools/gen-shim.py" "$here/dn/new/shims.map" "$out" "$here/tv/src" | sed 's|^|  shim: |'
fi
# the names of the units in lower case (FPC on a case-sensitive file system looks for unit.pas and UNIT.PAS only,
# not for TopView_.PAS)
for f in "$out"/*.[Pp][Aa][Ss]; do
    [ -f "$f" ] || continue
    b=$(basename "$f"); l=$(echo "$b" | tr 'A-Z' 'a-z')
    [ "$b" = "$l" ] || mv "$f" "$out/$l"
done
# the unit aliases of vpc.cfg (-ALFN=LFNVP;WINCLP=WINCLPVP: VP maps the unit name LFN to the unit LFNVP, so both names
# mean one unit). FPC has no such option: the unit gets the name that the others use (file, `unit` line, and the
# other mentions of the old name in the sources).
cfg=$(ls "$out" | grep -i '^vpc\.cfg$' | head -1)
if [ -n "$cfg" ]; then
    grep -i '^-A' "$out/$cfg" | tr -d '\r' | sed 's/^-[Aa]//' | tr ';' '\n' | while IFS== read -r alias real; do
        [ -n "$alias" ] && [ -n "$real" ] || continue
        lr=$(echo "$real" | tr 'A-Z' 'a-z'); la=$(echo "$alias" | tr 'A-Z' 'a-z')
        [ -f "$out/$lr.pas" ] || continue
        mv "$out/$lr.pas" "$out/$la.pas"
        find "$out" -maxdepth 1 -type f -iname '*.pas' -print0 | LC_ALL=C xargs -0 sed -i "s/\b$real\b/$alias/Ig"
        echo "  alias: unit $real is named $alias"
    done
    find "$out" -maxdepth 1 -type f -iname '*.pas' -print0 | xargs -0 python3 "$here/tools/dedup-uses.py" | sed 's|^|  |'
fi
echo "dn-materialize: build/dn ready ($(find "$out" -type f | wc -l) files)"
