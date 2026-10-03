# Refactoring candidates (see PLAN.md, "Рефакторинг шаг за шагом")

One step after each big development step: the most burning item of this list, as a separate commit, no change of behavior (the tests are green
before and after). Add what you find; do not stop for it outside of the step. Mark what is done.

## Done
- [x] 2026-10-03: the results of the build are not in the source directories (tests of tv/ and dn/ are built into their own directory): `tools/tv-test.sh`.

- [x] 2026-10-03 (after the embedded terminal): the map "file -> what it holds" for a newcomer: `dn/FILES.md` (the renames are still to be decided).

- [x] 2026-10-03 (after aarch64 and the DOSBox-X patches): one table "script -> what it does -> which workflow calls it": `tools/README.md` (linked from `README.md`).

- [x] 2026-10-03 (after the autosave of the desktop): "who writes what and when" for the settings and the desktop (`DN.CFG`, `DN.INI`, `DN.DSK`, `DN<n>.SWP`, `DN.HIS`): a section in `dn/FILES.md`; the guess "(?)" at `dn1.pas` is replaced by what it holds. No code changed.

- [x] 2026-10-04: the directories of `dn/` by role: `archives/` (the formats of archives), `compat/` (the environment of Virtual Pascal / Borland / DPMI over `tv/`, with `shims/` and `linux/`), `src/` (DN itself). No unit renamed, no code changed: the binary of `linux64` is
  byte for byte the same, `dn-test.sh`, `check-layout.sh`, the builds for DOS and i386 are green. Where: `dn/FILES.md`, "How `dn/` is laid out".

## Candidates (rough order of how much they hurt)
**The owner's list (2026-10-04), in the order to do it; each is one step with the same proof (the binary does not change, the tests are green):**
1. *Names of the files of code that say nothing:* digits, underscores at the end, almost the same names (`vpsyslow` / `vpsyslo2`, `dn` / `dn1` / `dnapp`, `advance`..`advance7`, `microed` / `microed2`, `drivers` / `drivers2`, `u_myapp`, `topview_`, `country_`). Rules: a lower-case name of words, the unit has the same name as the file, no digits and no
   trailing `_`, one name = one subject. The source files are cross compiled, so 8.3 does **not** limit them (FPC takes long names on Linux); 8.3 matters only for the files that the program reads and writes on DOS (see 3). A tool `tools/rename-unit.py OLD NEW` (renames the file, the `unit` line and the `uses`
   and `{$I}` of all files, checks the build) first; then one family per commit (the first: `dn.pas`, `dn1.pas`, `dnapp.pas`: what each holds is in `dn/FILES.md`). A proposal of the new names goes to the owner before the rename (the names are the owner's to choose).
   The files of `archives/` lose the prefix `arc_` (the directory says it) in the same way.
2. *The zoo of the case in the names of files and directories* (`RESOURCE`, `Events.inc`, `DN.pas`...): one rule, lower case for all the sources and directories; the resource names the program reads stay what the DOS build needs (see 3).
3. *The zoo of the files that the program writes and reads* (`DN.CFG`, `DN.INI`, `DN.HIS`, `TETRIS.CFG`, `dnhgl.grp`, `DNINI.IN_`, `DN.DSK`, `DN<n>.SWP`): which of them is needed, what `.cfg` and `.ini` hold and why there are two (the table is in `dn/FILES.md`, "who writes what"), one case, no `_` extensions. Compatibility with the files of the old DN may be broken
   (the owner: not a beta yet). For DOS the names stay 8.3 and lower case; one directory for all of them (`dn/`?) is a decision of the owner.
4. *Shims and everything that emulates an environment* are in `dn/compat/` now; what is left: `helpfile`, `helpkern`, `messages`, `strview`, `listmakr`, `dnstddlg`, `asciitab` (ours, replace Borland units) and `events`, `xtime`, `files` (DN, DPMI helpers) are candidates for `compat/` or for `src/` after the rename step.

- **Final step (owner decision 2026-10-03):** move DN to the Safe Pascal style (repository `unxed/sp`): see `DN-ADOPTION.md` there and the short section "Safe Pascal как стиль кода DN" in PLAN.md (the order S0-S10 chosen by RUP: (c) first, then (a) with a decision point, (b) only as a fallback). Earlier than the end if it turns out cheap (the pilot on new code, stage 3).
- The names of DN files in `dn/src` are the DOS names of the archive (`microed`, `microed2`, `u_myapp`, `topview_`, `country_`, `advance`, `advance1`, `advance2`...): what a file
  holds is not visible from its name. A map "old name -> what it holds" in `dn/README.md` first, renames later (they break the diffs with the archive and
  `bootstrap/`: needs a decision how `bootstrap/` follows).
- `{$IFDEF DNUTF8}` is spread over ~15 files of DN. Put the two behaviors behind one facade (`dnutf8.pas`: columns, proxy, key text) so that the
  places in the code say what they mean, not which mode they are in. When the legacy mode is dropped (DOS only keeps the code page) the `IFDEF`s go.
- Two buffer models in DN: words (`AWord` buffers of the DBF viewer, `calendar`, `ed2`, `idlers`) and cells (`TScreenCell`); `WriteLineW`/`WriteLineC` are easy to mix up (a
  bug of 2026-10-03). One model (cells), `LegacyText` only at the border.
- `tv/src/tvtermos.pas` holds the Unix termios layer, the Windows console layer and the VT interpreter of the console mode: split by what they do; the interpreter
  of the console mode can use `TvVt` (PLAN.md item 8) instead of its own.
- The names of the entities in the sources of DN that came from the archive (`SysXXX`, `DnXXX`, abbreviations of Russian words) — rename only the ones that a newcomer meets in
  the first hour: the entry points (`DN.pas`, `u_myapp`, `flpanel`, `filescol`, `drives`).
