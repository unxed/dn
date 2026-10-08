#!/bin/sh
# Writes the licence texts and README.TXT that every published build of DN carries: tools/dn-notices.sh DEST TARGET
#   TARGET  linux, linux64, aarch64, win32, win64, dos or dos-utf8 (the names of tools/build.sh or of tools/dn-pack.sh)
# The files (all of them must exist: a missing one is an error):
#   LICENSE.TXT                  the MIT license of the dn project (LICENSE)
#   LICENSE-DN.TXT               the licence of the DN code (RIT Research Labs), the notice from the head of its files
#   LICENSE-DN-FILES.md          which license covers which file of dn/ (dn/LICENSE.md), PROVENANCE.md (the list it refers to)
#   LICENSE-TV.TXT, COPYRIGHT-TV-MAGIBLOT.TXT, THIRD-PARTY-NOTICES-TV.md   tv/ (tv3)
#   LICENSE-TVE.TXT              tve/
#   cwsdpmi.doc                  DOS only: the documentation and the terms of the DPMI host (CWSDPMI_DOC=FILE, else fetched from delorie.com)
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
dest=${1:?usage: tools/dn-notices.sh DEST TARGET}; target=${2:?usage: tools/dn-notices.sh DEST TARGET}
mkdir -p "$dest"
copy() {
    [ -f "$here/$1" ] || { echo "dn-notices: $1 is missing (check out the submodules: git submodule update --init; or the pinned commit of the submodule does not have it yet)" >&2; exit 1; }
    cp "$here/$1" "$dest/$2"
}
copy LICENSE LICENSE.TXT
copy dn/LICENSE.md LICENSE-DN-FILES.md
copy dn/PROVENANCE.md PROVENANCE.md
copy tv/LICENSE LICENSE-TV.TXT
copy tv/COPYRIGHT.magiblot COPYRIGHT-TV-MAGIBLOT.TXT
copy tv/THIRD-PARTY-NOTICES.md THIRD-PARTY-NOTICES-TV.md
copy tve/LICENSE LICENSE-TVE.TXT
# the notice of the DN files, taken from the head of dn/src/dn.pas (the same in every file of DN code)
head=$(tr -d '\r' < "$here/dn/src/dn.pas" | sed -n '3,/^\/\/\/\/*}$/p' | sed -e '$d' -e 's,^//,,' -e 's,^  ,,')
case "$head" in *"RIT Research Labs"*"cannot be changed"*) ;; *) echo "dn-notices: no licence head in dn/src/dn.pas" >&2; exit 1;; esac
{
    echo "The licence of the DOS Navigator code in this program (the head of each of its source files in dn/src of"
    echo "https://github.com/unxed/dn; dn/PROVENANCE.md, here PROVENANCE.md, lists those files). It goes with the binary:"
    echo
    printf '%s\n' "$head"
} > "$dest/LICENSE-DN.TXT"
case "$target" in
dos*)
    if [ -n "${CWSDPMI_DOC:-}" ]; then
        cp "$CWSDPMI_DOC" "$dest/cwsdpmi.doc"
    else
        t=$(mktemp -d)
        curl -fsSL --retry 4 -o "$t/csdpmi.zip" https://www.delorie.com/pub/djgpp/current/v2misc/csdpmi7b.zip
        unzip -p "$t/csdpmi.zip" bin/cwsdpmi.doc > "$dest/cwsdpmi.doc"
        rm -rf "$t"
    fi
    [ -s "$dest/cwsdpmi.doc" ] || { echo "dn-notices: no cwsdpmi.doc" >&2; exit 1; } ;;
esac

licences="LICENSE-DN.TXT (the DN code, RIT Research Labs; LICENSE-DN-FILES.md and PROVENANCE.md say which file is under it),
LICENSE.TXT (the other files of dn, MIT), LICENSE-TV.TXT, COPYRIGHT-TV-MAGIBLOT.TXT and THIRD-PARTY-NOTICES-TV.md (Turbo Vision,
tv3), LICENSE-TVE.TXT (the editor, tve)"
keys="Keys: F10 menu, Tab switches the panel, Enter enters a directory, F1 help, F3 view, F4 edit, F5 copy, F7 make a directory,
Alt-X quit. Settings and history are written to the directory where DN is started (dn.ini, dn.his)."
{
case "$target" in
linux*|aarch64)
    cat <<EOS
DN for Linux (EXPERIMENTAL): DOS Navigator OSP 2.14 on Turbo Vision (tv3), built from https://github.com/unxed/dn.
It needs a terminal of at least 80x25 (xterm, the Linux console, kitty, alacritty...). DN is UTF-8 inside: file names, the
viewer, the editor, the clipboard (OSC 52) and Alt+Cyrillic work in any alphabet (wide CJK letters and combining marks are
not counted right yet). The commands of the command line run in an embedded terminal (the screen of the user: Ctrl-O or Esc
on an empty command line; DN_EMBED_TERM=0 gives the terminal to the shell, DN_RUN_PAUSE=0|1|2 sets what happens when the
command ends).

  ./dn               start it in this directory: the files *.lng *.dlg *.hlp and xlt/ must be next to it.

$keys
DN names the files as DOS does: the disk C: is the root of the file system ("C:\\home\\you"). The first start shows a notice
of the beta (Esc closes it).
EOS
    ;;
win*)
    cat <<EOS
DN for Windows (EXPERIMENTAL): DOS Navigator OSP 2.14 on Turbo Vision (tv3), built from https://github.com/unxed/dn
(cross-compiled on Linux).

  dn.exe             run it in a console window (conhost, Windows Terminal, Wine); the console needs at least 80x25.
  *.lng *.dlg *.hlp  the resources and the help, xlt\\  the layout tables: they must be next to dn.exe.

$keys
The program draws with the console API (WriteConsoleOutputW), so it works in Wine and in Windows before 10 too; set the
environment variable DN_WIN_OUTPUT=vt to use the virtual terminal sequences (Windows 10 1809 or newer, Windows Terminal).
In Wine the bright background colors of DN are drawn without the intensity bit; DN_WIN_BRIGHT_BG=1 turns that off, =0
turns it on in Windows. DN is UTF-8 inside: file names of any alphabet, the viewer, the editor and the clipboard work; wide
CJK letters and combining marks are not counted right yet.
EOS
    ;;
dos*)
    cat <<EOS
DN for DOS (EXPERIMENTAL): DOS Navigator OSP 2.14 on Turbo Vision (tv3), 32-bit protected mode (go32v2), built from
https://github.com/unxed/dn. It needs a 386 or newer: DOSBox-X, DOSBox, FreeDOS or real DOS.

  dn.exe             the program
  cwsdpmi.exe        the DPMI host (in the same directory or on PATH); cwsdpmi.doc is its documentation and terms
  *.lng *.dlg *.hlp  the resources and the help, xlt\\  the layout tables: they must be next to dn.exe

  DOSBox-X:  mount c <this directory>, c:, dn

$keys
CWSDPMI (C) Charles W Sandmann is included unmodified (the terms: cwsdpmi.doc). You have the right to receive its source
code and binary updates: https://www.delorie.com/pub/djgpp/current/v2misc/ (csdpmi7s.zip is the source).
EOS
    if [ "$target" = dos-utf8 ]; then
        cat <<'EOS'
This is the build with UTF-8 inside. It asks the DOS for the UTF-8 names of files (AMIS DOS-UTF8/NAMES) and the UTF-8 text
of the clipboard (DOS-UTF8/CLIPBRD): go2dos, DOSBox-X with the patches (docs/patches of the repository). On a DOS without
them the names are what the DOS gives and the clipboard goes through the code page: use the plain DOS build there.
TV_DOS_UTF8_NAMES=0 does not ask for the names, TV_DOS_UTF8_CLIP=0 not for the clipboard.
EOS
    fi
    ;;
*) echo "dn-notices: unknown target $target" >&2; exit 2 ;;
esac
cat <<EOS

Based on Dos Navigator by RIT Research Labs.
The licences (the program contains code under all of them): $licences.
EOS
} > "$dest/README.TXT"
