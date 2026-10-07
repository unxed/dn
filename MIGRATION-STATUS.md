# Migration status

Updated: 2026-10-07. This file is the handoff point: read it first, then [`PLAN.md`](PLAN.md) (the plan and the owner's checklist) and
[`docs/POST-CLASS-WORK.md`](docs/POST-CLASS-WORK.md) (the order of the stages).

## Where the port stands

- **Classes:** the migration from Pascal `object` to `class` is complete for `dn/` and `tv/` (the class gate `tools/class-gate.sh` is strict in CI). The
  object-vs-class acceptance gate (`dn-accept`, 178 scenarios, cell by cell) is closed; the details and the evidence are in
  [`docs/CLASS-MIGRATION-ACCEPTANCE-GATE.md`](docs/CLASS-MIGRATION-ACCEPTANCE-GATE.md). Shared bugs (the object and the class build wrong in the same way) are fixed, not kept.
- **UTF-8:** all sources, resources and documents are UTF-8 ([`docs/TEXT-POLICY.md`](docs/TEXT-POLICY.md), checked by `tools/tests/test_text_policy.py`,
  `tools/audit-encoding.py` and `tv/tools/text-policy.py`). The conversion of the sources from CP866 lost nothing (audited against the revision before it).
  Cells of the screen hold UTF-8; the DOS backend lands a cell on the code page of the machine. The glyphs (frames, shades, blocks, arrows) are named
  Unicode code points of `tv/src/tvglyphs.pas`, never byte constants.
- **English:** comments, documents, hard-coded strings and the English resources are English (Cyrillic only where the policy lists it).
- **Refactoring** (stage 2): done against [`docs/REFACTORING-CRITERIA.md`](docs/REFACTORING-CRITERIA.md).
- **Platform separation** (stage 3): done and enforced; see [`docs/PLATFORM-SEPARATION.md`](docs/PLATFORM-SEPARATION.md). `tools/check-platform.py` (CI: `layout`)
  fails when a platform unit or a target conditional appears outside the backends; `tools/build-matrix.sh` reports PASS, FAIL or UNAVAILABLE for every shipped configuration.
- **Tests** (stage 4): the floor of [`docs/TEST-PLAN.md`](docs/TEST-PLAN.md) is met: every row has a test that runs in CI, or is parked there with a reason. CI at the head: `dn`, `layout`,
  `toolchain`, `dn-linux` (tour, file operations, archives, find, resize, links and permissions, desktop with an editor window, the configuration directory, the flight recorder, names with spaces / a missing directory / `DN_RUN_PAUSE` / a zip in a zip), `dn-windows` (win32 and win64, with and without UTF-8 inside), `dn-accept`
  (object vs class, 181 scenarios, and the UTF-8 build vs the code page build), `nightly`. DOS: `tools/dn-tour.sh`, `tools/dn-dos-input.py` (stock and patched DOSBox-X) by hand.
- **Files of the user and diagnostics** (2026-10-07): the settings, the desktop and the histories live in `$XDG_CONFIG_HOME/dn` (`~/.config/dn`), `%APPDATA%\DN`, or next to the
  program on DOS (`DN2` names one directory; the files of an older DN are copied once; `dn/src/cfgdir.pas`). The flight recorder (`dn/src/flightrec.pas`,
  [`docs/CRASH-REPORTS.md`](docs/CRASH-REPORTS.md)) writes `dn.log` (keys by name, commands, directories, external programs, file operations; typed characters are not recorded) and,
  at a crash, `crash/crashNNN.txt` with the call stack (lines of the sources), the state of the panels and views, the last events and the screen: hand these over to have a
  fault that nobody can reproduce looked at.
- **DOS UTF-8 names** are tv3's now (`TvDos` switches `DOS-UTF8/NAMES` on, `TvDosNames` converts a name); the DOS tests of dn pass on a vanilla DOSBox-X `master`.
- **Found by this work and fixed** (shared bugs, the object build had them too): the read-only attribute lost at a copy on Unix, names cut by bytes with UTF-8 inside, the SmartPad line,
  the line drawing of the editor, the archivers on Unix (paths and list files), Find File with a text (class only), the data of a copy written after zeros on Windows, a Cyrillic letter typed in the panels under a locale whose code page lacks it (en_US.UTF-8) opened Find File and swallowed the input (the status line took a key without a code for a key of an item without one), and the command line dropped such a letter. See `dn/TODO-later.md`.

## Build and check

    tools/build.sh linux64                  # DN, the resources and the help: out/linux64
    tools/dn-test.sh                        # the unit tests of dn/tests
    tools/tv-test.sh                        # the unit tests of tv/tests
    python3 -B -m unittest discover -s tools/tests -p 'test_*.py'
    tools/accept-local.sh all               # the object vs class gate on this machine (builds both, runs every scenario)
    DN_PREFIX=/path/to/go32v2 tools/build.sh dos      # the DOS build (cross compiler: tools/build-fpc-go32v2.sh PREFIX)

The other scripts and what each one checks: [`tools/README.md`](tools/README.md).

## Branches and the submodule

Work goes to `main`. `tv/` is the submodule `unxed/tv3`; a change to it is made and tested there (a branch of that repository), then the pointer is moved here.
The `tv/` pointer of `main` is on `main` of `unxed/tv3` (`claude/dos-names` was merged into it on 2026-10-07 together with the clipboard and far2l work that was already there: `1bb5290`). The merged branches `claude/glyphs` and `claude/dos-names` of tv3 are still on GitHub: the token of this work cannot delete a branch (HTTP 403), the owner deletes them in the web interface.
The object baseline of the gate is pinned in `tools/dn-linux-accept.py` (`OBJECT_DN_SHA`, `OBJECT_TV_SHA`).

## Open items

The list is in `PLAN.md` and in `dn/TODO-later.md`. The ones that decide what to do next:

1. The parked rows of `docs/TEST-PLAN.md` (DN-level clipboard checks, the viewer window of the desktop, screenshot checks of the DOS pages 850, 852, 1125 and of the DOS help, the keys of the DOS harness, an interactive program in the embedded terminal).
2. Intermittent access violations that were seen once (after a clipboard prompt, after a command in the embedded terminal) and could not be reproduced:
   `docs/CLASS-MIGRATION-ACCEPTANCE-GATE.md`. The flight recorder is there to catch them: the next one comes with `dn.log` and a crash report.
3. The unstable `menu_5_13` scenario (an asynchronous scan of the host root); a stabilizer is in, the CI has been green with it.
4. The short name of a file record is 12 bytes (the DOS 8.3 form). The macros of the menus and the descriptions by short names no longer cut a long name on Unix (`FileShortName`); the field itself stays for DOS and Windows (`dn/TODO-later.md`).
5. DOSBox-X: the UTF-8 DOS API (names, clipboard) and the guard against the loop of `DOS_CheckExtDevice` are in `joncampbell123/dosbox-x` `master` (PRs 6632 and 6634). `tools/dn-dos-input.py` with `DN_DOS_PATCHED=1` passes on a vanilla `master` (2026.10.01, checked 2026-10-07: 9 checks); `docs/patches/` is the history. The package `dosbox-x` of Ubuntu that the CI installs is older (no UTF-8 names): a CI job that builds `master` for this scenario is open (`dn/TODO-later.md`).
