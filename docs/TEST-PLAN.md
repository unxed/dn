# Test plan: what "minimally decent" means

Stage 4 of [`POST-CLASS-WORK.md`](POST-CLASS-WORK.md). It starts after stage 3 (platform separation) is complete, except for the
narrow tests that prove an extraction batch. This file fixes the floor before the tests are written, in the same way as
[`REFACTORING-CRITERIA.md`](REFACTORING-CRITERIA.md) fixes the refactoring.

## Rules

1. **A floor, not a ceiling.** Stage 4 is done when every row of the tables below has a test that runs in CI, or is parked in
   "Parked" with a reason. More tests are welcome and need no approval.
2. **A test names its platform.** A test of shared behaviour runs on every target that can run it; a platform test says which one
   (`linux`, `win`, `dos`) and is skipped, never faked, elsewhere. A skipped target is reported as unavailable, not as passed.
3. **No test without a failure it can show.** For a row that already bit the project (startup redraw, desktop restore, stream
   format, virtual/`override`, archives, editor and user screen) the test must fail on the old bug. Where the bug is fixed, check by
   reverting the fix once, locally, and write the result in the commit message.
4. **A fixed bug gets a test in the same commit** (the existing practice: `t_osdep` for the `COMSPEC` bug, `dn-linux-sortmark.py`
   for the sort letter).
5. **Shared bugs** (the object and the class build show the same wrong behaviour) are fixed, not preserved; the scenario of the
   gate then shows the fixed behaviour on both builds (`CLASS-MIGRATION-ACCEPTANCE-GATE.md`).
6. Tests are English, UTF-8, and obey [`TEXT-POLICY.md`](TEXT-POLICY.md) (Cyrillic only as test data, listed there).

## The floor, by area

`have` = what exists now; `gap` = what stage 4 adds. Names of scripts are in [`tools/README.md`](../tools/README.md).

### Shared (all targets)

| Area | Floor | Have | Gap |
|---|---|---|---|
| Text and encodings | UTF-8 and code page conversion, case, widths, the border of names; the glyph names (frames) | `t_dnutf8`, `t_zipcharset`, `t_osnames`, `t_cpcase` (the case of the page 1125), `test_sort1125.py`, `tv/tests/t_utf8`, `t_text`, `t_glyphs`, `t_cpall` (all pages: round trip, frames) | the DOS landing of the frame glyphs on the screen of the pages 850 and 852 (a screenshot check) |
| Resources | every dialog, menu and string of the three languages loads and a dialog draws | `rcp` in the build, `t_shim`, `t_resload` (every stored view of each language loads through the stream loader, the key sets of the languages are equal) | the control count of a loaded dialog against the source of `rcp` |
| Settings | `dn.ini`, the saved setup, the desktop, the histories: write, read, migrate | `t_cfgstate`, `t_defsort`, `t_profile`, `t_cfgdir` (the directory, the move of the old files), `dn-linux-config.py` (XDG, `~/.config/dn`, the move, `DN2`) | the windows of the desktop (editor, viewer) saved and restored: `dn-linux-desktop.py` and the DOS scenario `autosave` do the panels only (Alt-X in an editor closes the editor, not DN: the exit with a window open needs another way out) |
| Crash and hang reports | the log of a run, the report of a crash, the privacy of the typed characters, the next log after a killed run | `t_flightrec` (the log, the ring, the report, the masking), `dn-linux-crash.py` (an access violation forced in the real program) | the report of a crash on DOS and Windows (addresses only on DOS; the CI builds both, nobody has forced a crash there) |
| Files and paths | find, names, attributes, the DOS path semantics through the facades | `t_osdep`, `t_flname`, `t_dnscreen` | long names, names with spaces and UTF-8, a missing directory, a read-only file |
| Processes | start a program, restart, the user screen | `t_osrun`, `t_dnrun`, `dn-linux-names.py` (`DN_RUN_PAUSE` 0, 1, 2) | exit codes of the programs as DN shows them |
| Archives | enter, leave, list, F3, F4, F5, F8, add (zip, 7z, tar, tgz, tar.gz, tar.bz2, tar.xz) | `dn-linux-archives.py`, `docs/ARCHIVE-MATRIX.md` | zip in zip; add and delete as separate checks of the files in the archive |
| The object/class gate | every scenario of every function, cell by cell | `dn-accept` (178 scenarios) | the scenarios added by stages 1 to 3 (glyphs, platform facades) |

### Linux

| Area | Floor | Have | Gap |
|---|---|---|---|
| Start and screen | start, menu bar, exit, language switch, startup panels | `dn-linux-tour.py`, `-startup.py`, `-about.py`, accept `start`, `restart_language` | none (`dn-linux-resize.py` is the SIGWINCH test) |
| File operations | make directory, copy, move, delete, edit and save, on real files | `dn-linux-ops.py`, `dn-linux-names.py` (names with spaces, a missing directory, a zip in a zip) | none (`dn-linux-fsattrs.py`: links and read-only files) |
| Input | win32 input mode, far2l, quick search | `dn-linux-win32.py`, `-far2l.py`, `-qsearch.py` | Kitty keyboard flags in DN (not only in `tv`) |
| Text | the code page by the locale (code page build), UTF-8 names | `dn-linux-locale.py`, `DN_OPS_UTF8` | a non-UTF-8 locale for the UTF-8 build |
| Embedded terminal | a command line command, Ctrl-O, the user screen | `dn-linux-ops.py` (command), `tv/tests/pty/test_vtrun.py` | an interactive program and the return to DN |
| Targets | x86_64, i386, aarch64 | `dn-linux.yml` (qemu for aarch64) | none: the same set on all three |

### Windows

| Area | Floor | Have | Gap |
|---|---|---|---|
| Start and screen | start on a real console, menu bar, no country-setup error | `dn-win-smoke.py` (ConPTY) | none (`dn-windows` runs the smoke on win32 and win64, with and without UTF-8 inside) |
| Names | UTF-8 names through the wide API: create, list, enter, copy | CI check of `Privet`, `αβγ`, F7 | delete of such a name (`dn-win-smoke.py` copies it: it found the copy bug) |
| Processes | the shell and the archivers through `COMSPEC /c` | none | none (`dn-win-smoke.py` runs a command of the command line; `t_osrun` has no Windows branch: the tests of `dn/tests` run on Linux only) |
| Clipboard | text round trip through the system clipboard | `tv` (Windows backend) | a DN-level check on Linux (`dn-linux-clip.py`); on DOS and Windows still none |

### DOS

| Area | Floor | Have | Gap |
|---|---|---|---|
| Start and screen | start, panels, menu, in the code page build (437, 866) | `dn-tour.sh`, `dn-dos-input.py` (DOSBox-X) | the screen of the pages 850 and 852 |
| Names | UTF-8 names to the DOS when `DOS-UTF8/NAMES` is there, code page names when it is not | scenarios `utf8-names-cp` (patched DOSBox-X), `names-cp-plain` (stock DOSBox-X: no provider, code page names) | none |
| Input | the keyboard and the mouse | `dn-dos-input.py` | the keys of the harness for F3 and F4 on real files (F5, F6, F7, F8: scenario `files` of `dn-dos-input.py`) |
| State | desktop and setup saved and restored | `tools/dn-tour.sh` scenarios, `t_cfgstate` | the saved setup (`Save setup`) |
| User screen | a program's output kept and shown again | `userscr` smoke (in `toolchain`) | none |
| Clipboard | UTF-8 clipboard when `DOS-UTF8/CLIPBRD` is there, OEM when not | `tv` `t_dosbk` | a DN-level check on Linux (`dn-linux-clip.py`); on DOS and Windows still none |
| Resources and help | the DOS build lands them on the code page of the language (`to-codepage.py`) | `tools/tests/test_to_codepage.py` | a screenshot check of the help in Russian and Ukrainian (cp866, cp1125) |

## Where the tests run

| Test kind | Where | Workflow |
|---|---|---|
| Unit tests (`dn/tests`, `tv/tests`) | native, and DOS for `tv/tests` | `dn`, `tv` |
| Pty tests | Linux x86_64, i386, aarch64 | `dn-linux` |
| Acceptance gate | Linux x86_64 | `dn-accept` |
| Windows console | Windows runner | `dn-windows` |
| DOS | DOSBox-X (patched for the UTF-8 provider) | `toolchain` |

`tools/accept-local.sh` runs the gate on one machine.

## Parked

| Item | Why parked | Revisit |
|---|---|---|
| Screenshot checks of the screens of the pages 850 and 852, of the help in Russian and Ukrainian (cp866, cp1125) | DOSBox-X has no such pages; the tables are checked by unit tests (`t_cpall`, `t_cpcase`, `test_sort1125.py`) | when a DOS with these pages can run |
| The control count of a loaded dialog against the source of `rcp` | `t_resload` proves that every view loads and that the three languages have the same keys; the source has no machine readable count | when `rcp` writes a manifest |
| The viewer window of the desktop saved and restored | the editor is covered (`dn-linux-desktop.py` runs 4 and 5: out by the menu File -> Exit, the editor comes back, object and class builds alike); the viewer is not | with the next desktop change |
| Add and delete of archive members as separate checks | covered by the accept scenarios and `dn-linux-archives.py` in part | stage 4 follow-up |
| Kitty keyboard flags in DN, a non-UTF-8 locale for the UTF-8 build, an interactive program in the embedded terminal | the first two are tested in `tv` (`tv/tests/pty`); the third needs a program that reads the terminal in the test | stage 4 follow-up |
| DN-level clipboard checks (DOS and Windows) | `tv` tests the backends (`t_dosbk`, the Windows clipboard); a DN scenario needs the system clipboard of the runner | stage 4 follow-up |
| The keys of the DOS harness for F3 and F4 on real files, the DOS `Save setup` | F5, F6, F7, F8 are checked on the files by the scenario `files` of `dn-dos-input.py` (run by hand: DOSBox-X and Xvfb) | stage 4 follow-up |
| The scenarios of the gate for the glyphs and the platform facades | the whole gate runs on both builds at every push (the glyphs are the screen of every scenario) | none |
| Real DOS machines and FreeDOS | no runner; DOSBox-X is the only DOS we can run | when go2dos has a 386 mode (`PLAN.md`, milestone 7) |
| macOS, BSD | no target in the build matrix | when a target is added |
