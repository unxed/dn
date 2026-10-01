#!/bin/sh
# Builds an FPC 3.2.2 cross compiler (x86_64 Linux -> i386-go32v2) from the
# Ubuntu fpc-source package, using the DJGPP binutils of andrewwutw/build-djgpp.
#
# usage: tools/build-fpc-go32v2.sh PREFIX
# needs: fpc, fpc-source, make, gh (with GH_TOKEN), bzip2
# result: PREFIX/bin/fpc-go32v2 (wrapper: compiles for i386-go32v2)
set -eu
PREFIX=$(mkdir -p "$1" && cd "$1" && pwd)
work=$(mktemp -d)

# --- DJGPP binutils (and the gcc driver, which FPC does not need) ------------
gh release download -R andrewwutw/build-djgpp -p 'djgpp-linux64-*.tar.*' -D "$work"
tar -xf "$work"/djgpp-linux64-* -C "$PREFIX"
DJ="$PREFIX/djgpp"
export PATH="$DJ/bin:$PATH"
TP=i586-pc-msdosdjgpp-
command -v ${TP}as ${TP}ld

# --- cross compiler + RTL ----------------------------------------------------
cp -r /usr/share/fpcsrc/3.2.2 "$work/src"
cd "$work/src"
common="OS_TARGET=go32v2 CPU_TARGET=i386 BINUTILSPREFIX=$TP FPC=/usr/bin/fpc"
# 'make crossall' builds ppcross386 plus the RTL and packages for the target
make $common crossall
make $common crossinstall INSTALL_PREFIX="$PREFIX/fpc"

ppc=$(find "$PREFIX/fpc" -name ppcross386 | head -1)
units=$(dirname "$ppc")/units/i386-go32v2
[ -x "$ppc" ] && [ -d "$units" ] || { echo "cross compiler not installed" >&2; exit 1; }

mkdir -p "$PREFIX/bin"
cat > "$PREFIX/bin/fpc-go32v2" <<EOS
#!/bin/sh
export PATH="$DJ/bin:\$PATH"
exec "$ppc" -Tgo32v2 -XP$TP -Fu"$units/*" -Fu"$units/rtl" "\$@"
EOS
chmod +x "$PREFIX/bin/fpc-go32v2"
echo "installed: $PREFIX/bin/fpc-go32v2"
