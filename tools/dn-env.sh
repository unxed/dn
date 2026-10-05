# Sourced by tools/build.sh, tools/dn-try.sh and the other tools of the builds of DN: what the compiler is, with what options, where the
# units are. Needs $here (the root of the repository) and DN_TARGET (dos | linux | linux64).
#   dos     DN_PREFIX=PREFIX of tools/build-fpc-go32v2.sh (or DN_CROSS=<dir with lib/fpc/3.2.2/ppcross386> and DN_LINK=<dir with djgpp/bin>)
#   linux   DN_LINUX=PREFIX of tools/build-fpc-i386-linux.sh (the cross compiler for i386-linux)
#   linux64 the fpc of the host (FPC=path to use another)
#   aarch64 DN_AARCH64=PREFIX of tools/build-fpc-aarch64-linux.sh (the cross compiler for aarch64-linux)
#   win64   DN_WIN=PREFIX of tools/build-fpc-windows.sh PREFIX win64 (the cross compiler for x86_64-win64); win32: DN_WIN32=PREFIX of the same script with win32
# DN_EXTRA: more options (e.g. -gl: line numbers).   Result: DN_PPC (the compiler and its target options), DN_PATH (the directories for PATH:
# binutils), DN_UPATHS (the unit and include directories), DN_OPTS, DN_OBJ (where the objects go), DN_GEN (the generated shim units).
. "$here/dn/build.env"
case "${DN_TARGET:-}" in
    dos)
        if [ -n "${DN_PREFIX:-}" ]; then : "${DN_CROSS:=$DN_PREFIX/fpc}"; : "${DN_LINK:=$DN_PREFIX}"; fi
        [ -n "${DN_CROSS:-}" ] && [ -n "${DN_LINK:-}" ] || { echo "dos: set DN_PREFIX (tools/build-fpc-go32v2.sh PREFIX) or DN_CROSS and DN_LINK" >&2; exit 1; }
        x=$DN_CROSS/lib/fpc/3.2.2; u=$x/units/go32v2
        DN_PPC="$x/ppcross386 -Tgo32v2 -XPi586-pc-msdosdjgpp-"; DN_PATH="$DN_LINK/djgpp/bin"
        DN_FUNITS="-Fu$u/* -Fu$u/rtl"; DN_OPT=$DN_OPT_dos; DN_UNITS_EXTRA="" ;;
    linux)
        : "${DN_LINUX:?linux: set DN_LINUX (tools/build-fpc-i386-linux.sh PREFIX)}"
        u=$DN_LINUX/lib/fpc/3.2.2/units/i386-linux
        if [ -d "$u" ]; then DN_FUNITS="-Fu$u/* -Fu$u/rtl"; else DN_FUNITS="-Fu$DN_LINUX/units/i386-linux"; fi
        ppc=$DN_LINUX/lib/fpc/3.2.2/ppcross386
        DN_PPC="$ppc -Tlinux -Pi386 -XPi386-linux-"; DN_PATH="$DN_LINUX/bin"
        DN_OPT=$DN_OPT_linux; DN_UNITS_EXTRA=$DN_UNITS_linux ;;
    linux64)
        DN_PPC="${FPC:-fpc}"; DN_PATH=""; DN_FUNITS=""; DN_OPT=$DN_OPT_linux64; DN_UNITS_EXTRA=$DN_UNITS_linux64 ;;
    aarch64)
        : "${DN_AARCH64:?aarch64: set DN_AARCH64 (tools/build-fpc-aarch64-linux.sh PREFIX)}"
        u=$DN_AARCH64/lib/fpc/3.2.2/units/aarch64-linux
        DN_FUNITS="-Fu$u/* -Fu$u/rtl"; DN_PPC="$DN_AARCH64/lib/fpc/3.2.2/ppcrossa64 -Tlinux -Paarch64 -XPaarch64-linux-gnu-"; DN_PATH=""
        DN_OPT=$DN_OPT_aarch64; DN_UNITS_EXTRA=$DN_UNITS_aarch64 ;;
    win64)
        : "${DN_WIN:?win64: set DN_WIN (tools/build-fpc-windows.sh PREFIX win64)}"
        u=$DN_WIN/lib/fpc/3.2.2/units/x86_64-win64
        DN_FUNITS="-Fu$u/* -Fu$u/rtl"; DN_PPC="$DN_WIN/lib/fpc/3.2.2/ppcrossx64 -Twin64 -Px86_64 -XPx86_64-w64-mingw32-"; DN_PATH=""
        DN_OPT=$DN_OPT_win64; DN_UNITS_EXTRA=$DN_UNITS_win64 ;;
    win32)
        : "${DN_WIN32:?win32: set DN_WIN32 (tools/build-fpc-windows.sh PREFIX win32)}"
        u=$DN_WIN32/lib/fpc/3.2.2/units/i386-win32
        DN_FUNITS="-Fu$u/* -Fu$u/rtl"; DN_PPC="$DN_WIN32/lib/fpc/3.2.2/ppcross386 -Twin32 -Pi386 -XPi686-w64-mingw32-"; DN_PATH=""
        DN_OPT=$DN_OPT_win32; DN_UNITS_EXTRA=$DN_UNITS_win32 ;;
    *) echo "DN_TARGET must be dos, linux, linux64, aarch64, win64 or win32" >&2; exit 1 ;;
esac
# no Intel assembler reader on other CPUs (the tree has no assembler left): aarch64 cross, or a native fpc on an ARM machine
case "$DN_TARGET" in
    aarch64) DN_FPC_COMMON=$(echo "$DN_FPC_COMMON" | sed 's/ -Rintel//') ;;
    linux64) case "$($DN_PPC -iTP 2>/dev/null)" in x86_64|i386) ;; *) DN_FPC_COMMON=$(echo "$DN_FPC_COMMON" | sed 's/ -Rintel//') ;; esac ;;
esac
tmp=${TMPDIR:-/tmp}
# FPC does not rebuild a unit when only a -d option changed: every set of options has its own directory of the objects
case "${DN_EXTRA:-}" in *-dDNUTF8*) dn_objsfx=-utf8;; *) dn_objsfx=;; esac
DN_OBJ=${DN_OBJ:-$tmp/dn-obj-$DN_TARGET$dn_objsfx}
DN_GEN=${DN_GEN:-$tmp/dn-gen}
DN_OPTS="$DN_FPC_COMMON $DN_OPT ${DN_EXTRA:-}"
# The sources of a build are put together in one directory of links ($DN_STAGE): dn/src, dn/archives (a unit per archive format), dn/compat (the environment that DN
# expects: the Virtual Pascal / Borland / DPMI layer over tv/) and then the files of the directories of this build (dn/compat/linux: our units that replace those of the
# tree, e.g. country_.pas) over it. (FPC looks for units first in the directory
# of the program, so a unit of the build cannot win over a file of dn/src in any other way.)
DN_STAGE=${DN_STAGE:-$tmp/dn-stage-$DN_TARGET}
dn_stage() {
    rm -rf "$DN_STAGE"; mkdir -p "$DN_STAGE"
    for f in "${DN_SRC:-$here/dn/src}"/*.pas "${DN_SRC:-$here/dn/src}"/*.inc "$here"/dn/archives/*.pas "$here"/dn/compat/*.pas; do ln -s "$f" "$DN_STAGE/$(basename "$f")"; done
    # ZIP charset libs (localecp + zipcharset); include maps staged beside the unit
    for f in "$here"/dn/lib/localecp/*.{pas,inc} "$here"/dn/lib/zipcharset/*.pas; do
        [ -e "$f" ] && ln -sf "$f" "$DN_STAGE/$(basename "$f")"
    done
    for d in $DN_UNITS_EXTRA; do
        for f in "$here/dn/$d"/*; do ln -sf "$f" "$DN_STAGE/$(basename "$f")"; done
    done
}
DN_UPATHS="$DN_FUNITS -Fu$here/tv/src -Fu$DN_GEN -Fi$here/dn/compat/shims -Fu$DN_STAGE -Fi$DN_STAGE"
# the shim units (the names of the units of Borland TV that DN uses, made from tv/): generated for the builds, not committed
dn_gen_shims() {
    mkdir -p "$DN_GEN"; dn_stage
    python3 "$here/tools/gen-shim.py" "$here/dn/compat/shims/shims.map" "$DN_GEN" "$here/tv/src" >/dev/null
}
# dn_compile PROGRAM.pas [NOLINK]: compiles PROGRAM.pas of the stage (dn_gen_shims makes it)
dn_compile() {
    mkdir -p "$DN_OBJ"
    link=; [ -n "${2:-}" ] && link=-Cn
    ( cd "$DN_OBJ" && PATH="${DN_PATH:+$DN_PATH:}$PATH" $DN_PPC $DN_OPTS $DN_UPATHS -FU"$DN_OBJ" -FE"$DN_OBJ" $link -vewn "$DN_STAGE/$1" 2>&1 )
}
