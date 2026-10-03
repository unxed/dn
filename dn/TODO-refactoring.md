# Refactoring candidates (see PLAN.md, "Рефакторинг шаг за шагом")

One step after each big development step: the most burning item of this list, as a separate commit, no change of behavior (the tests are green
before and after). Add what you find; do not stop for it outside of the step. Mark what is done.

## Done
- [x] 2026-10-03: the results of the build are not in the source directories (tests of tv/ and dn/ are built into their own directory): `tools/tv-test.sh`.

- [x] 2026-10-03 (after the embedded terminal): the map "file -> what it holds" for a newcomer: `dn/FILES.md` (the renames are still to be decided).

## Candidates (rough order of how much they hurt)
- The names of DN files in `dn/src` are the DOS names of the archive (`microed`, `microed2`, `u_myapp`, `topview_`, `country_`, `advance`, `advance1`, `advance2`...): what a file
  holds is not visible from its name. A map "old name -> what it holds" in `dn/README.md` first, renames later (they break the diffs with the archive and
  `bootstrap/`: needs a decision how `bootstrap/` follows).
- `{$IFDEF DNUTF8}` is spread over ~15 files of DN. Put the two behaviors behind one facade (`dnutf8.pas`: columns, proxy, key text) so that the
  places in the code say what they mean, not which mode they are in. When the legacy mode is dropped (DOS only keeps the code page) the `IFDEF`s go.
- Two buffer models in DN: words (`AWord` buffers of the DBF viewer, `calendar`, `ed2`, `idlers`) and cells (`TScreenCell`); `WriteLineW`/`WriteLineC` are easy to mix up (a
  bug of 2026-10-03). One model (cells), `LegacyText` only at the border.
- `tv/src/tvtermos.pas` holds the Unix termios layer, the Windows console layer and the VT interpreter of the console mode: split by what they do; the interpreter
  of the console mode can use `TvVt` (PLAN.md item 8) instead of its own.
- `tools/`: the scripts have different styles of arguments (env variables, positions); one table of "script -> what it checks -> how CI calls it" in `README.md`.
- The names of the entities in the sources of DN that came from the archive (`SysXXX`, `DnXXX`, abbreviations of Russian words) — rename only the ones that a newcomer meets in
  the first hour: the entry points (`DN.pas`, `u_myapp`, `flpanel`, `filescol`, `drives`).
