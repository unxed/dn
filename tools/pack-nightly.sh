#!/bin/sh
# Packs a build of DN for the nightly release: tools/pack-nightly.sh OUTDIR NAME KIND DEST
#   OUTDIR  the directory that tools/build.sh made (dn or dn.exe, *.lng, *.dlg, *.hlp, xlt/, cwsdpmi.exe for DOS)
#   NAME    the target as shown in the file name (linux64, linux-arm64, linux32, win64, win32, dos, dos-utf8)
#   KIND    tar (tar.gz) or zip
#   DEST    the directory for the archive: DEST/dn-<short commit>-NAME.tar.gz or .zip
# The archive has the program, its resources, the layout tables, the default dn.ini, the licence texts and NIGHTLY.txt (the commit, the date).
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
out=$1; name=$2; kind=$3; dest=$4
sha=$(git -C "$here" rev-parse --short HEAD)
stage=$(mktemp -d)/dn-$sha-$name
mkdir -p "$stage" "$dest"
for f in dn dn.exe cwsdpmi.exe; do [ -f "$out/$f" ] && cp "$out/$f" "$stage/"; done
cp "$out"/*.lng "$out"/*.dlg "$out"/*.hlp "$stage/"
cp -r "$here/dn/data/xlt" "$stage/xlt"
cp "$here/dn/data/dn.ini" "$stage/"
for f in LICENSE-DN.TXT LICENSE-TV.TXT COPYRIGHT-TV-MAGIBLOT.TXT; do cp "$here/dist/linux64/$f" "$stage/"; done
{
    echo "DN nightly build"
    echo "commit:  $(git -C "$here" rev-parse HEAD)"
    echo "date:    $(git -C "$here" log -1 --format=%cI)"
    echo "target:  $name"
    echo "source:  https://github.com/unxed/dn"
    echo "This is the build of every commit of the branch main: it may be unfinished."
} > "$stage/NIGHTLY.txt"
base=$(dirname "$stage"); dir=$(basename "$stage")
case "$kind" in
    tar) tar -C "$base" -czf "$dest/$dir.tar.gz" "$dir" ;;
    zip) (cd "$base" && zip -qr "$OLDPWD/$dest/$dir.zip" "$dir") ;;
    *) echo "KIND: tar or zip" >&2; exit 2 ;;
esac
ls -l "$dest"
