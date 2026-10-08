#!/bin/sh
# Packs a build of DN for a GitHub release: tools/dn-pack.sh OUTDIR NAME KIND DEST [VERSION]
#   OUTDIR   the directory that tools/build.sh made (dn or dn.exe, *.lng, *.dlg, *.hlp, xlt/, cwsdpmi.exe for DOS)
#   NAME     the target as shown in the file name (linux64, linux-aarch64, linux32, win64, win32, dos, dos-utf8)
#   KIND     tar (tar.gz) or zip
#   DEST     the directory for the archive: DEST/dn-VERSION-NAME.tar.gz or .zip
#   VERSION  the tag of a release (workflow release); without it: the short commit, a nightly build (workflow nightly)
# The archive has the program, its resources, the layout tables, the default dn.ini, the licence texts and README.TXT
# (tools/dn-notices.sh) and BUILD.TXT (the commit, the date). The builds are published as releases, never committed.
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
out=$1; name=$2; kind=$3; dest=$4; version=${5:-}
sha=$(git -C "$here" rev-parse HEAD)
label=${version:-$(git -C "$here" rev-parse --short HEAD)}
mkdir -p "$dest"; dest=$(cd "$dest" && pwd)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
stage=$tmp/dn-$label-$name
mkdir -p "$stage"
for f in dn dn.exe cwsdpmi.exe; do if [ -f "$out/$f" ]; then cp "$out/$f" "$stage/"; fi; done
[ -f "$stage/dn" ] || [ -f "$stage/dn.exe" ] || { echo "dn-pack: no dn or dn.exe in $out" >&2; exit 1; }
cp "$out"/*.lng "$out"/*.dlg "$out"/*.hlp "$stage/"
cp -r "$here/dn/data/xlt" "$stage/xlt"
cp "$here/dn/data/dn.ini" "$stage/"
case "$name" in dos*) [ -f "$stage/cwsdpmi.exe" ] || { echo "dn-pack: no cwsdpmi.exe in $out" >&2; exit 1; };; esac
"$here/tools/dn-notices.sh" "$stage" "$name"
{
    if [ -n "$version" ]; then echo "DN $version"; else echo "DN nightly build"; fi
    echo "commit:  $sha"
    echo "date:    $(git -C "$here" log -1 --format=%cI)"
    echo "target:  $name"
    echo "source:  https://github.com/unxed/dn"
    [ -n "$version" ] || echo "This is the build of a commit of the branch main: it may be unfinished."
} > "$stage/BUILD.TXT"
case "$kind" in
    tar) tar -C "$tmp" -czf "$dest/dn-$label-$name.tar.gz" "dn-$label-$name" ;;
    zip) (cd "$tmp" && zip -qr "$dest/dn-$label-$name.zip" "dn-$label-$name") ;;
    *) echo "KIND: tar or zip" >&2; exit 2 ;;
esac
ls -l "$dest"
