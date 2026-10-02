DN (Dos Navigator Open Source 2.14) built by this repository for DOS (32-bit protected mode, DJGPP go32v2), on our
Pascal translation of Turbo Vision (magiblot/tvision) and our replacement of the Virtual Pascal layer.
Status: EXPERIMENTAL. It starts, shows two file panels, the menu (F10), the status line and the command line;
a lot does not work yet (see the repository: PLAN.md, dn/TODO-later.md). Do not trust it with real data.

Files
  DN.EXE            the program (a stripped build, no source line numbers)
  CWSDPMI.EXE       the DPMI host (it must be in the same directory or on PATH); CWSDPMI.DOC is its documentation and terms
  ENGLISH.DLG/.LNG, RUSSIAN.DLG/.LNG, UKRAIN.DLG/.LNG   the dialogs, menus and strings, made by the resource compiler
                    rcp.exe from the files of the DN sources (the language is chosen as in DN: DN.INI, or DNLNG=English)
  SHA256SUMS.TXT    checksums of the files
  screenshots/      what it looks like in DOSBox-X
  LICENSE-DN.TXT, LICENSE-TV.TXT, COPYRIGHT-TV-MAGIBLOT.TXT   the licences (the binary contains code under all of them)

Run
  DOSBox-X (or DOSBox, FreeDOS, real DOS with a 386+):
      mount c <this directory>
      c:
      dn
  Start it in a directory you do not mind: DN writes its configuration (DN.INI, DN.HIS...) next to the program.
  Keys: F10 menu, Tab switches the panel, Enter enters a directory, Alt-X quits (not yet reliable: if the screen
  stops reacting, close the emulator).

Based on Dos Navigator by RIT Research Labs.
Rebuilding: tools/dn-dist.sh in the repository (needs the DOS cross compiler: tools/build-fpc-go32v2.sh).
