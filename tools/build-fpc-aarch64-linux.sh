#!/bin/sh
# Builds an FPC 3.2.2 cross compiler (x86_64 Linux -> aarch64-linux) from the official FPC sources (tag release_3_2_2), with the cross binutils of the
# distribution (binutils-aarch64-linux-gnu: aarch64-linux-gnu-as/ld/ar/strip). The programs are static (the RTL of FPC does not use libc here) and run on
# an aarch64 Linux kernel, or on this machine with qemu-user (qemu-aarch64-static).
#
# usage: tools/build-fpc-aarch64-linux.sh PREFIX
# needs: fpc (any 3.2.x, as the bootstrap compiler), make, git, binutils-aarch64-linux-gnu
# result: PREFIX/bin/fpc-aarch64-linux (wrapper: compiles for aarch64-linux), PREFIX/lib/fpc/3.2.2/ppcrossa64 and PREFIX/lib/fpc/3.2.2/units/aarch64-linux/*
#         (DN_AARCH64=PREFIX for tools/build.sh aarch64)
set -eu
PREFIX=$(mkdir -p "$1" && cd "$1" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
command -v aarch64-linux-gnu-as >/dev/null || { echo "install binutils-aarch64-linux-gnu" >&2; exit 1; }

git clone -q --depth 1 --branch release_3_2_2 https://gitlab.com/freepascal.org/fpc/source.git "$work/src"
cd "$work/src"
common="PP=/usr/bin/fpc OS_TARGET=linux CPU_TARGET=aarch64 BINUTILSPREFIX=aarch64-linux-gnu-"
make $common crossall
make $common crossinstall INSTALL_PREFIX="$PREFIX"

ppc="$PREFIX/lib/fpc/3.2.2/ppcrossa64"
units="$PREFIX/lib/fpc/3.2.2/units/aarch64-linux"
[ -x "$ppc" ] && [ -f "$units/rtl/system.ppu" ] || { echo "cross compiler not installed" >&2; exit 1; }
mkdir -p "$PREFIX/bin"
cat > "$PREFIX/bin/fpc-aarch64-linux" <<EOS
#!/bin/sh
exec "$ppc" -Tlinux -Paarch64 -XPaarch64-linux-gnu- -Fu"$units/*" -Fu"$units/rtl" "\$@"
EOS
chmod +x "$PREFIX/bin/fpc-aarch64-linux"
echo "installed: $PREFIX/bin/fpc-aarch64-linux"
