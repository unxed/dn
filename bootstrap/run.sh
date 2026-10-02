#!/bin/sh
# BOOTSTRAP: makes the source tree of DOS Navigator (the first commit of dn/src) from the public archive of DN OSP 2.14:
# unpack, carve, drop the files of exclude.list, take the units of the system, apply the patches, the rewrites and the
# edits, add our new files, make the names lower case, take the aliases of vpc.cfg. The whole path is described in
# bootstrap/README.md; it is the record of how dn/src came to be, not a part of the daily work (after the first commit dn/src is
# changed by ordinary commits).
#
# usage: bootstrap/run.sh [OUTDIR]       (default: build/bootstrap)     result: OUTDIR/src (the tree), OUTDIR/data (the data of DN)
# env:   DN_LOCAL_TREE=<an unpacked archive>  instead of fetching (no network); the same files give the same result
#        BOOT_KEEP_WORK=1                     keep OUTDIR/work (the whole tree before the selection of the files)
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
boot=$here/bootstrap
. "$boot/upstream.env"
. "$boot/tree.env"
name=$DN_BASE
eval file=\$${name}_FILE
OUT=${1:-$here/build/bootstrap}
mkdir -p "$OUT"; OUT=$(cd "$OUT" && pwd)
out=$OUT/work
rm -rf "$out" "$OUT/src" "$OUT/data"; mkdir -p "$out"
if [ -n "${DN_LOCAL_TREE:-}" ]; then
    src="$DN_LOCAL_TREE"
else
    raw=$OUT/raw
    archive=$("$boot/fetch.sh" "$name" | tail -1)
    rm -rf "$raw"; mkdir -p "$raw"
    case "$file" in
        *.rar) unrar x -y -idq "$archive" "$raw/" ;;
        *.zip) unzip -q -o "$archive" -d "$raw" ;;
        *) echo "bootstrap: unknown archive type $file" >&2; exit 2 ;;
    esac
    # the sources may be in a subdirectory of the archive: take the one with most .pas files
    src=$(find "$raw" -type d | while read -r d; do
            n=$(find "$d" -maxdepth 1 -iname '*.pas' | wc -l); echo "$n $d"; done | sort -rn | head -1 | cut -d' ' -f2-)
fi
cp -a "$src"/. "$out"/
echo "bootstrap: the archive ($file), $(find "$out" -type f | wc -l) files"

# the classes of DN itself in the files that are excluded as a whole: carved into new units (carve.list)
if [ -f "$boot/carve.list" ]; then
    python3 "$boot/tools/dn-carve.py" "$boot/carve.list" "$out" | sed 's|^|  carve: |'
fi
# the units of the system: DN OSP keeps the units that differ between the systems in LIB.D32 (DOS, 32-bit), LIB.OLF, LIB.WLF
# (events, files, country_, fltl, fnotify...): those of BOOT_LIB_DIR go to the root of the tree, the others are dropped.
# VPSYSD32.PAS is the Virtual Pascal runtime (not DN code): our vpsyslow.pas (bootstrap/new) takes its place.
if [ -n "${BOOT_LIB_DIR:-}" ]; then
    ld=$(ls "$out" | grep -i "^$BOOT_LIB_DIR\$" | head -1)
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

# the exclusions (exclude.list; after the units of the system are in the root, they may come from there too): the files that are replaced by the new TV (tv/) or by our text; their code is of Borland origin
grep -v '^[[:space:]]*#' "$boot/exclude.list" | grep -v '^[[:space:]]*$' | while read -r pat; do
    find "$out" -ipath "$out/$pat" -type f -print -delete
done | sed 's|^|  excluded: |' || true

# the patches (patches/series)
while read -r p; do
    case "$p" in ''|'#'*) continue;; esac
    patch -p1 -d "$out" --no-backup-if-mismatch < "$boot/patches/$p" >/dev/null
    echo "  patch: $p"
done < "$boot/patches/series"

# the regions that repeat Borland code are replaced by our text (rewrite/*.rw; before any other edit,
# the anchors are lines of the pristine sources)
if [ -d "$boot/rewrite" ]; then
    python3 "$boot/tools/dn-rewrite.py" "$out" "$boot/rewrite" | grep -v '^  (no sha1' | sed 's|^|  rewrite: |'
fi
# the mechanical edits (edits/*.sh, *.sed, *.py: in this order, each in the order of the names; each file names its reason)
for e in "$boot"/edits/*.sh; do
    [ -f "$e" ] || continue
    sh "$e" "$out"
    echo "  edit: $(basename "$e")"
done
for e in "$boot"/edits/*.sed; do
    [ -f "$e" ] || continue
    find "$out" -maxdepth 1 -type f \( -iname '*.pas' -o -iname '*.inc' \) -print0 | LC_ALL=C xargs -0 sed -i -f "$e"
    echo "  edit: $(basename "$e")"
done
for e in "$boot"/edits/*.py; do
    [ -f "$e" ] || continue
    find "$out" -maxdepth 1 -type f -iname '*.pas' -print0 | xargs -0 python3 "$e" | sed 's|^.*/||; s|^|  edit '"$(basename "$e")"': |'
done

# our new files (bootstrap/new): the replacements of the excluded units and the adapters
if [ -d "$boot/new" ]; then
    (cd "$boot/new" && find . -type f ! -name .gitkeep) | while read -r f; do
        mkdir -p "$out/$(dirname "$f")"; cp "$boot/new/$f" "$out/$f"; echo "  new: $f"; done
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
    find "$out" -maxdepth 1 -type f -iname '*.pas' -print0 | xargs -0 python3 "$boot/tools/dedup-uses.py" | sed 's|^|  |'
fi

# THE SELECTION: what goes to the repository. Sources (*.pas, *.inc), the texts of the resources (RESOURCE: the dialogs, the strings,
# the help, in three languages) and rcpvpd.ini (the resource compiler); the data that DN reads when it runs (EXE.D32: the tables of
# the code pages, the palettes, the default settings) go to data/. Not taken: the binaries of the archive (DN.COM, icons), the build
# scripts of Virtual Pascal (*.cmd, *.vpo, vpc.cfg, *._vp), and the old copies of units (*.001 ...): nothing of them is a source of our builds.
mkdir -p "$OUT/src" "$OUT/data"
(cd "$out" && find . -maxdepth 1 -type f \( -iname '*.pas' -o -iname '*.inc' -o -iname 'rcpvpd.ini' -o -iname 'read.me' \)) | while read -r f; do
    cp "$out/$f" "$OUT/src/$f"
done
cp -r "$out/RESOURCE" "$OUT/src/RESOURCE"
find "$OUT/src/RESOURCE" -type f \( -iname '*.cmd' \) -delete
ed=$(ls "$out" | grep -i '^EXE\.D32$' | head -1)
if [ -n "$ed" ]; then
    (cd "$out/$ed" && find . -type f ! -iname 'DN.COM' ! -iname '*.exe') | while read -r f; do
        mkdir -p "$OUT/data/$(dirname "$f")"; cp "$out/$ed/$f" "$OUT/data/$f"
    done
fi
[ -n "${BOOT_KEEP_WORK:-}" ] || rm -rf "$out"
echo "bootstrap: ready: $OUT/src ($(find "$OUT/src" -type f | wc -l) files), $OUT/data ($(find "$OUT/data" -type f | wc -l) files)"
