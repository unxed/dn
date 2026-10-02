#!/bin/sh
# The Linux build of DN in one step: the tree (DN_TARGET=linux), rcp and dn for i386-linux, the resources.
# usage: DN_LINUX=PREFIX [DN_LOCAL_TREE=...] tools/dn-linux.sh [OUTDIR]     (default out/dnlinux)
# env: DN_NO_MATERIALIZE=1 keeps the tree of the last run
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
export DN_TARGET=linux
# DN_ARCH=x86_64: the 64-bit build with the native fpc of the host (tree build/dn-linux-x64); default: i386 with the cross compiler
DN_ARCH=${DN_ARCH:-i386}; export DN_ARCH
[ "$DN_ARCH" = x86_64 ] || : "${DN_LINUX:?set DN_LINUX (tools/build-fpc-i386-linux.sh PREFIX)}"
out=${1:-$here/out/dnlinux}; mkdir -p "$out"; out=$(cd "$out" && pwd)
tmp=${TMPDIR:-/tmp}; export TMPDIR=$tmp
[ -n "${DN_NO_MATERIALIZE:-}" ] || "$here/tools/dn-materialize.sh" dnosp214 >/dev/null
if [ "$DN_ARCH" = x86_64 ]; then b=$here/build/dn-linux-x64; o=$tmp/dn-try-o-linux-x64; else b=$here/build/dn-linux; o=$tmp/dn-try-o-linux; fi
echo "== build"
for p in rcp dn; do
    "$here/tools/dn-try.sh" $p.pas | grep -E "Error|Fatal" || true
    [ -x "$o/$p" ] && [ "$o/$p" -nt "$b/$p.pas" ] || { echo "$p was not built" >&2; exit 1; }
done
cp "$o/dn" "$out/dn"
echo "== resources (rcp)"
w=$out/rcp.work; mkdir -p "$w/EXE.D32"
cp "$o/rcp" "$w/rcp"
# the names are in capitals in DN, the file system is case sensitive: DN's own names
cp "$b/rcpvpd.ini" "$w/RCPVPD.INI"; cp "$b/dnhelp.pas" "$w/DNHELP.PAS"; cp "$b/commands.pas" "$w/COMMANDS.PAS"; cp "$b/stdefine.inc" "$w/STDEFINE.INC"
rm -rf "$w/RESOURCE"; cp -r "$b/RESOURCE" "$w/RESOURCE"
(cd "$w" && ./rcp D 2>&1 | sed 's/([0-9]*)//g' | grep -E "Writing|rror|nresolved|Undefined" || true)
cp "$w"/EXE.D32/*.LNG "$w"/EXE.D32/*.DLG "$out/" 2>/dev/null || { echo "no resources were made" >&2; exit 1; }
echo "== help (tvhc)"
mkdir -p "$tmp/tvhc-o"
fpc -Fu"$here/tv/src" -FU"$tmp/tvhc-o" -FE"$tmp/tvhc-o" -vew "$here/tv/tools/tvhc.pas" | grep -E "Error|Fatal" || true
for l in ENGLISH RUSSIAN UKRAIN; do
    "$tmp/tvhc-o/tvhc" "$b/RESOURCE/$l/dnhelp.htx" "$out/$l.HLP" /4DN_OSP | sed 's|^|  |' || echo "help $l failed" >&2
done
echo "dn ($DN_ARCH linux): $out/dn   (run it in a terminal: cd $out && ./dn)"
