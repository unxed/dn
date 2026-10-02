#!/bin/sh
# Builds an FPC 3.2.2 cross compiler (x86_64 Linux -> i386-linux) from the official FPC sources (tag release_3_2_2). The
# binutils are those of the host: wrappers named i386-linux-as/ld/ar/strip call `as --32`, `ld -m elf_i386` and so on.
# The programs for i386-linux are static (the RTL of FPC does not use libc here) and run on a 64-bit Linux kernel.
#
# usage: tools/build-fpc-i386-linux.sh PREFIX
# needs: fpc (any 3.2.x, as the bootstrap compiler), make, git, binutils (as, ld, ar), a kernel that runs 32-bit programs
# result: PREFIX/bin/fpc-i386-linux (wrapper: compiles for i386-linux), PREFIX/bin/i386-linux-* (binutils),
#         PREFIX/lib/fpc/3.2.2/ppcross386 and PREFIX/lib/fpc/3.2.2/units/i386-linux/*  (DN_LINUX=PREFIX for tools/dn-*.sh)
set -eu
PREFIX=$(mkdir -p "$1" && cd "$1" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$PREFIX/bin"
for t in as ld ar strip; do
    case $t in as) c='as --32';; ld) c='ld -m elf_i386';; *) c=$t;; esac
    printf '#!/bin/sh\nexec %s "$@"\n' "$c" > "$PREFIX/bin/i386-linux-$t"
    chmod +x "$PREFIX/bin/i386-linux-$t"
done
export PATH="$PREFIX/bin:$PATH"

git clone -q --depth 1 --branch release_3_2_2 https://gitlab.com/freepascal.org/fpc/source.git "$work/src"
cd "$work/src"
common="PP=/usr/bin/fpc OS_TARGET=linux CPU_TARGET=i386 BINUTILSPREFIX=i386-linux-"
make $common crossall
make $common crossinstall INSTALL_PREFIX="$PREFIX"

ppc="$PREFIX/lib/fpc/3.2.2/ppcross386"
units="$PREFIX/lib/fpc/3.2.2/units/i386-linux"
[ -x "$ppc" ] && [ -f "$units/rtl/system.ppu" ] || { echo "cross compiler not installed" >&2; exit 1; }
cat > "$PREFIX/bin/fpc-i386-linux" <<EOS
#!/bin/sh
export PATH="$PREFIX/bin:\$PATH"
exec "$ppc" -Tlinux -Pi386 -XPi386-linux- -Fu"$units/*" -Fu"$units/rtl" "\$@"
EOS
chmod +x "$PREFIX/bin/fpc-i386-linux"
echo "installed: $PREFIX/bin/fpc-i386-linux"
