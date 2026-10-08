#!/bin/sh
# Makes dist/linux/ (a local directory, ignored by git: the builds are published by the workflow release, never committed):
# the Linux build of DN (i386, static) with the licence texts and README.TXT (tools/dn-notices.sh) and the screens of the
# pty tour as text. usage: DN_LINUX=PREFIX tools/dn-linux-dist.sh [linux|linux64|aarch64]  (aarch64: DN_AARCH64=PREFIX of tools/build-fpc-aarch64-linux.sh; the tour runs under qemu-aarch64-static)
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
T=${1:-linux}     # linux (i386, static), linux64 (x86_64) or aarch64 (ARM64, static)
[ "$T" = aarch64 ] && export PTY_RUN_PREFIX=${PTY_RUN_PREFIX:-qemu-aarch64-static}
dist=$here/dist/$T
tmp=${TMPDIR:-/tmp}; work=$tmp/dn-linux-dist
mkdir -p "$work" "$dist/screenshots"
# no symbols: small
DN_EXTRA="-Xs" "$here/tools/build.sh" "$T" "$work" >/dev/null
cp "$work/dn" "$dist/dn"
cp "$work"/*.lng "$work"/*.dlg "$work"/*.hlp "$dist/"
rm -rf "$dist/xlt"; cp -r "$work/xlt" "$dist/xlt"
"$here/tools/dn-notices.sh" "$dist" "$T"
python3 "$here/tools/dn-linux-tour.py" "$work" start f1help f3view f4edit f7mkdir f5copy menudisk quitask quit
for n in start f1help f3view f4edit f7mkdir f5copy menudisk; do
    grep -v '^[[:space:]]*$' "$work/tour-$n.txt" > "$dist/screenshots/$n.txt"
done
( cd "$dist" && sha256sum dn *.lng *.dlg *.hlp > SHA256SUMS.TXT )
echo "dist/$T is made: $(ls "$dist" | wc -l) files"
