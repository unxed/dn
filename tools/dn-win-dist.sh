#!/bin/sh
# Makes dist/win64/ or dist/win32/ (a local directory, ignored by git: the builds are published by the workflow release, never
# committed): the Windows build of DN (cross-compiled on Linux) with the licence texts and README.TXT (tools/dn-notices.sh).
# usage: DN_WIN=PREFIX tools/dn-win-dist.sh win64      DN_WIN32=PREFIX tools/dn-win-dist.sh win32
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
T=${1:-win64}
dist=$here/dist/$T
tmp=${TMPDIR:-/tmp}; work=$tmp/dn-win-dist-$T
rm -rf "$work"; mkdir -p "$work" "$dist"
# no symbols: small
DN_EXTRA="-Xs" "$here/tools/build.sh" "$T" "$work" >/dev/null
cp "$work/dn.exe" "$dist/dn.exe"
cp "$work"/*.lng "$work"/*.dlg "$work"/*.hlp "$dist/"
rm -rf "$dist/xlt"; cp -r "$work/xlt" "$dist/xlt"
"$here/tools/dn-notices.sh" "$dist" "$T"
( cd "$dist" && sha256sum dn.exe *.lng *.dlg *.hlp > SHA256SUMS.TXT )
echo "dist/$T is made: $(ls "$dist" | wc -l) files"
