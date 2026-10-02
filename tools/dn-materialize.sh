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

# patches
while read -r p; do
    case "$p" in ''|'#'*) continue;; esac
    patch -p1 -d "$out" --no-backup-if-mismatch < "$here/dn/patches/$p" >/dev/null
    echo "  patch: $p"
done < "$here/dn/patches/series"

# mechanical edits (dn/edits/*.sed; each file names its reason): sed scripts over all the sources
if [ -d "$here/dn/edits" ]; then
    for e in "$here"/dn/edits/*.sed; do
        [ -f "$e" ] || continue
        find "$out" -maxdepth 1 -type f \( -iname '*.pas' -o -iname '*.inc' \) -print0 | LC_ALL=C xargs -0 sed -i -f "$e"
        echo "  edit: $(basename "$e")"
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
echo "dn-materialize: build/dn ready ($(find "$out" -type f | wc -l) files)"
