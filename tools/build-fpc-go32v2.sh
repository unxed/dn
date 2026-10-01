#!/bin/sh
# Builds an FPC 3.2.2 cross compiler (x86_64 Linux -> i386-go32v2) from the
# official FPC sources (tag release_3_2_2), using the DJGPP binutils of
# andrewwutw/build-djgpp. The Debian/Ubuntu fpc-source package is not enough:
# it lacks the top-level Makefile and compiler/msg.
#
# usage: tools/build-fpc-go32v2.sh PREFIX
# needs: fpc (any 3.2.x, as the bootstrap compiler), make, git, curl, bzip2
# result: PREFIX/bin/fpc-go32v2  (wrapper: compiles for i386-go32v2)
set -eu
PREFIX=$(mkdir -p "$1" && cd "$1" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
TP=i586-pc-msdosdjgpp-

# --- DJGPP binutils ------------------------------------------------------------
curl -fsSL --retry 4 -o "$work/djgpp.tar.bz2" \
  https://github.com/andrewwutw/build-djgpp/releases/latest/download/djgpp-linux64-gcc1220.tar.bz2
tar -xf "$work/djgpp.tar.bz2" -C "$PREFIX"
DJ="$PREFIX/djgpp"
export PATH="$DJ/bin:$PATH"
command -v ${TP}as ${TP}ld

# --- cross compiler + RTL ------------------------------------------------------
git clone -q --depth 1 --branch release_3_2_2 https://gitlab.com/freepascal.org/fpc/source.git "$work/src"
cd "$work/src"
common="PP=/usr/bin/fpc OS_TARGET=go32v2 CPU_TARGET=i386 BINUTILSPREFIX=$TP"
make $common crossall
make $common crossinstall INSTALL_PREFIX="$PREFIX/fpc"

ppc="$PREFIX/fpc/lib/fpc/3.2.2/ppcross386"
units="$PREFIX/fpc/lib/fpc/3.2.2/units/go32v2"
[ -x "$ppc" ] && [ -f "$units/rtl/system.ppu" ] || { echo "cross compiler not installed" >&2; exit 1; }

mkdir -p "$PREFIX/bin"
cat > "$PREFIX/bin/fpc-go32v2" <<EOS
#!/bin/sh
export PATH="$DJ/bin:\$PATH"
exec "$ppc" -Tgo32v2 -XP$TP -Fu"$units/*" -Fu"$units/rtl" "\$@"
EOS
chmod +x "$PREFIX/bin/fpc-go32v2"
echo "installed: $PREFIX/bin/fpc-go32v2"
