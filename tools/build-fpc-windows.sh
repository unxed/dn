#!/bin/sh
# Builds an FPC 3.2.2 cross compiler (Linux -> Windows) from the official FPC sources (tag release_3_2_2).
#
# usage: tools/build-fpc-windows.sh PREFIX [win64|win32]       (default win64)
# needs: fpc (any 3.2.x, the bootstrap compiler), make, git, and the MinGW binutils:
#        apt install binutils-mingw-w64-x86-64 (win64) or binutils-mingw-w64-i686 (win32)
# result: PREFIX/bin/fpc-win64 (or fpc-win32): a wrapper that compiles for Windows; the compiler and the units are in PREFIX/lib/fpc/3.2.2
#         (DN_WIN=PREFIX for tools/build.sh win64 | win32)
set -eu
PREFIX=$(mkdir -p "$1" && cd "$1" && pwd)
T=${2:-win64}
case $T in
    win64) OSN=win64; CPU=x86_64; PPC=ppcrossx64; BP=x86_64-w64-mingw32-; PARG="-Twin64 -Px86_64";;
    win32) OSN=win32; CPU=i386;   PPC=ppcross386; BP=i686-w64-mingw32-;   PARG="-Twin32 -Pi386";;
    *) echo "target: win64 or win32" >&2; exit 2;;
esac
command -v ${BP}ld >/dev/null || { echo "${BP}ld is not found: install the MinGW binutils" >&2; exit 1; }
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
git clone -q --depth 1 --branch release_3_2_2 https://gitlab.com/freepascal.org/fpc/source.git "$work/src"
cd "$work/src"
common="PP=$(command -v fpc) OS_TARGET=$OSN CPU_TARGET=$CPU BINUTILSPREFIX=$BP"
make $common crossall
make $common crossinstall INSTALL_PREFIX="$PREFIX"
ppc="$PREFIX/lib/fpc/3.2.2/$PPC"
units="$PREFIX/lib/fpc/3.2.2/units/$CPU-$OSN"
[ -x "$ppc" ] && [ -f "$units/rtl/system.ppu" ] || { echo "cross compiler not installed" >&2; exit 1; }
mkdir -p "$PREFIX/bin"
cat > "$PREFIX/bin/fpc-$OSN" <<EOS
#!/bin/sh
exec "$ppc" $PARG -XP$BP -Fu"$units/*" -Fu"$units/rtl" "\$@"
EOS
chmod +x "$PREFIX/bin/fpc-$OSN"
echo "installed: $PREFIX/bin/fpc-$OSN"
