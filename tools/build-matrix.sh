#!/bin/sh
# The build matrix of DN: every shipped configuration is compiled (tools/build.sh) and the result of each is reported as one of
#   PASS         it was built
#   FAIL         the compiler or a step of the build failed (the log is out/matrix/NAME.log)
#   UNAVAILABLE  the toolchain of the target is not here: it was NOT built (never counted as a pass; see the reason)
# usage: tools/build-matrix.sh [NAME...]          NAME: linux64 linux64-cp linux32 aarch64 win64 win64-cp win32 win32-cp dos dos-utf8 (default: all)
# The cross compilers are found as in the CI: DN_LINUX, DN_AARCH64, DN_WIN, DN_WIN32, DN_PREFIX (tools/build-fpc-*.sh PREFIX); with no variable
# the directory ~/fpc-i386-linux, ~/fpc-aarch64-linux, ~/fpc-win64, ~/fpc-win32, ~/go32v2 is tried.
# Exit status: 1 when a configuration FAILs; 0 otherwise. DN_MATRIX_REQUIRE=1: an UNAVAILABLE one fails too (what the CI sets for its own targets).
# The result is a table on the standard output and out/matrix/summary.txt.
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
res=${DN_MATRIX_OUT:-$here/out/matrix}
mkdir -p "$res"
: > "$res/summary.txt"
fails=0
unavail=0

have_prefix() { [ -d "$1" ] && [ -n "$(ls "$1/lib/fpc/3.2.2" 2>/dev/null)" ]; }

# NAME TARGET UTF8 -- the variable that the target needs is checked first
run() {
    name=$1; target=$2; utf8=$3; shift 3
    reason=
    case $target in
        linux64) command -v "${FPC:-fpc}" >/dev/null 2>&1 || reason="no fpc on PATH" ;;
        linux)   p=${DN_LINUX:-$HOME/fpc-i386-linux};    have_prefix "$p" && DN_LINUX=$p && export DN_LINUX || reason="no cross compiler for i386-linux (tools/build-fpc-i386-linux.sh PREFIX; DN_LINUX)" ;;
        aarch64) p=${DN_AARCH64:-$HOME/fpc-aarch64-linux}; have_prefix "$p" && DN_AARCH64=$p && export DN_AARCH64 || reason="no cross compiler for aarch64-linux (tools/build-fpc-aarch64-linux.sh PREFIX; DN_AARCH64)" ;;
        win64)   p=${DN_WIN:-$HOME/fpc-win64};           have_prefix "$p" && DN_WIN=$p && export DN_WIN || reason="no cross compiler for win64 (tools/build-fpc-windows.sh PREFIX win64; DN_WIN)" ;;
        win32)   p=${DN_WIN32:-$HOME/fpc-win32};         have_prefix "$p" && DN_WIN32=$p && export DN_WIN32 || reason="no cross compiler for win32 (tools/build-fpc-windows.sh PREFIX win32; DN_WIN32)" ;;
        dos)     p=${DN_PREFIX:-$HOME/go32v2}
                 if [ ! -d "$p/fpc" ] && [ ! -d "$p/lib/fpc" ]; then reason="no go32v2 toolchain (tools/build-fpc-go32v2.sh PREFIX; DN_PREFIX)"
                 elif ! command -v "${DOSBOX_X:-dosbox-x}" >/dev/null 2>&1; then reason="no dosbox-x (rcp runs in it; DOSBOX_X)"
                 else DN_PREFIX=$p; export DN_PREFIX; fi ;;
    esac
    if [ -n "$reason" ]; then
        printf '%-12s UNAVAILABLE  %s\n' "$name" "$reason" | tee -a "$res/summary.txt"
        unavail=$((unavail + 1))
        [ "${DN_MATRIX_REQUIRE:-0}" = 1 ] && fails=$((fails + 1))
        return
    fi
    if DN_UTF8=$utf8 "$here/tools/build.sh" "$target" "$res/$name" >"$res/$name.log" 2>&1; then
        printf '%-12s PASS\n' "$name" | tee -a "$res/summary.txt"
    else
        printf '%-12s FAIL         (log: %s)\n' "$name" "$res/$name.log" | tee -a "$res/summary.txt"
        tail -n 5 "$res/$name.log" | sed 's/^/             /'
        fails=$((fails + 1))
    fi
}

want() { [ $# -eq 0 ] && return 0; for w in $WANTED; do [ "$w" = "$1" ] && return 0; done; return 1; }
WANTED="$*"
all() { [ -z "$WANTED" ] || want "$1"; }

all linux64    && run linux64    linux64 1
all linux64-cp && run linux64-cp linux64 0
all linux32    && run linux32    linux   1
all aarch64    && run aarch64    aarch64 1
all win64      && run win64      win64   1
all win64-cp   && run win64-cp   win64   0
all win32      && run win32      win32   1
all win32-cp   && run win32-cp   win32   0
all dos        && run dos        dos     0
all dos-utf8   && run dos-utf8   dos     1

echo "matrix: $fails failed, $unavail unavailable (an unavailable target was not built)"
[ "$fails" -eq 0 ]
