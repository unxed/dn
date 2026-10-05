# Class-migration acceptance gate

The class migration is complete only when the last working object-based DN and
the current class-based DN pass the same action matrix. A mismatch means that
porting artifacts remain.

Current gate status: **OPEN**. Earlier comparisons against the archived
pre-rewrite DN/TV pair used a different product revision and are not the
object-to-class acceptance baseline. Use only the exact object and class
revisions recorded below; do not treat earlier palette, About-text, or startup
cell counts as accepted evidence.

## Current controlling result (2026-10-05)

The object baseline for acceptance is DN `b4916b874989d7b35660d02cf935dc5f0db7a656`
with its recorded TV submodule `521d06479198789deeaa6fda287236ca83ba4051`.
The current class build is DN `33674fed7829124fbd3230440faf3075c45eb9f6`
with TV3 `ca5cd6bcab8e04a9a95018a3a3183b2b18f73cf3`. Both binaries must be
rebuilt from these exact source revisions with identical build metadata and
fixtures. The earlier comparison against DN `10763d65d091fc8525599a45c155be228c1bb8b6`
and TV `c9bb5c4d0d87e73382ebdd48c117f4c29e1ae9e5` used the wrong object
baseline and is not acceptance evidence; its reported differences are
superseded, not waived.

The corrected 24-scenario PTY tour completed on both builds, but it did not
exercise every action or provide a reproducible exact-cell comparison for
every checkpoint. A separate full menu-cell probe exposed actionable
differences: at menu item `(0,4)` the class build raised an access violation
where the object build completed normally; at `(0,10)` the object build ended
with a pointer-operation fatal error while the class build remained on screen.
Changing language also raised an access violation in the class build. The
language-menu crash was traced to interpreting a `TStringCollection`
ShortString item as an AnsiString. A diagnostic-only ShortString correction
avoided that crash in one probe, but is not an accepted source fix. A
repository-wide search found other `PString(Collection.At(...))` patterns in
`dnutil.pas`, `paneldlgs.pas`, `printman.pas`, `histories.pas`, `eraser.pas`,
`diskinfo.pas`, and `filefind.pas`; they require type-by-type review before
any fix is accepted.

The user clarified that there are two mutually exclusive startup states. On a
first/virgin run, About appears while panels are already drawn; closing it
leaves the About image over the panels. This is reproduced against the exact
object/class pair above, one fresh run per build: object `0/1` residue trials,
class `1/1`. On a later run (with `dn.ini`), About does not appear; the user
reports that some self-built starts show a blank purple panel area until a
menu triggers drawing, while `dist` does not.

The latter was reproduced once with the user's current binary variants and
same PTY size/input: self-build `out/linux64/dn`, build `1f0a63d`, SHA-256
`97f102cb466842bf6a0453ad5d83412a47ba06f2f427bf9578a62adc11a3cb7a`, had no
panel headers before menu input and six afterward; `dist/linux64/dn`, whose
embedded build identifies `df0cca2`, SHA-256
`e88ec6c324801bc394e9665095f705c452f5c34b7ec2ffa1363c80f58542a41d`, had six
headers before menu input. This is a one-trial classification based on panel
headers, not full-cell acceptance evidence. A prior 100-start attempt sampled
before UI readiness and is invalid; a valid 100-start series remains pending.
Source searches found redraw/draw entry points in `mainapp.pas`,
`panelroot.pas`, `paneldlgs.pas`, and `menus.pas`, but have not isolated either
root cause. Keep the virgin-run About residue and configured-run self-build
startup blank as separate test cases; both are hard failures.

Startup/panel regressions to reproduce and fix:

* Closing the About dialog on first launch consistently leaves its image
  visible over the panels.
* The configured-run blank-panel state is mutually exclusive with first-run
  About: use the same non-virgin `dn.ini` condition for self-build and `dist`.
  Run at least 100 fresh starts of each exact comparator binary (record source
  revision, build flags, and `dist` artifact identity), capture complete
  cells before input, then replay the same menu input and capture again.
  Require zero missing-panel trials for the accepted class build and exact
  parity with its object/distribution comparator.
* For the About residue, capture the screen immediately before opening About,
  while About is open, and immediately after closing it; all prior panel cells
  must be restored on every trial. Initial evidence: exact-pair fresh-start
  probe, object `0/1` residue trials, class `1/1`; expand to a repeatable
  regression series and complete full-cell comparisons.

The acceptance harness itself previously mishandled `CSI ? 1049 h/l`: it
did not save and restore the primary-screen cells, attributes, and cursor.
`tools/pty_screen.py` and its regression tests now cover the alternate-screen
transition. This is a harness correction only; it does not resolve or waive
any DN rendering discrepancy.

These are hard failures, not approved normalizations. No action-matrix row is
promoted to pass by a smoke tour or a diagnostic-only source copy. Keep the
gate **OPEN** until the exact object and class builds have replayed every
user-visible action and all checkpoints match.

## Required comparison

For both builds, use the same clean temporary tree, absolute run path, terminal size, locale,
resource files, build metadata, and key sequence. Compare the terminal state, not a
text-only rendering: every cell must match exactly as
`(Unicode cell contents, foreground color, background color, style/attribute)`,
including blank cells and the cursor position/visibility. A differing
foreground or background is a failure even when the visible text matches.
Record the exact cell snapshots, exit status, side effects in the input tree,
and `dn.err` or exception output.

| Area | Actions | Object baseline | Class build | Comparison |
|---|---|---|---|---|
| Startup/teardown | Start, initial panels, redraw/resize, `Alt-X`, clean teardown | pending | pending | pending |
| Main menus | File, Disk, Utilities, Panel, Manager, Options, Window | pending | pending | pending |
| Nested menus | Every submenu, enabled/disabled state, geometry, cancellation | pending | pending | pending |
| Panels | Switch, drive, directory, manager-new, select, sort, filter, view mode | pending | pending | pending |
| File operations | View, edit, copy, move, rename, delete, attributes, cancel/error paths | pending | pending | pending |
| Archives | Enter archive, list, extract/copy, leave archive, error paths | pending | pending | pending |
| Built-in tools | About, calculator, calendar, ASCII table, Tetris | pending | pending | pending |
| Dialogs/setup | Panel setup, system/options setup, language, history, help | pending | pending | pending |
| Input paths | Function keys, command line, mouse paths where supported | pending | pending | pending |

The matrix must include every user-visible action, not just one representative
per feature: every item in every top-level and nested menu, each default and
cancel path, and every supported keyboard, mouse, and command-line route.
Repeat clean startup 100 times and require zero missing-panel trials.

The text view printed by `Screen.lines()` is only diagnostic and cannot pass
this gate. The acceptance harness must compare the complete `Screen.cells`
matrix and cursor state at the same checkpoints.

Status values are `pass`, `fail`, or `not applicable`; an untested row is not
acceptable. Any rendering difference, wrong menu position, missing dispatch,
changed side effect, crash, or teardown error keeps the gate open.
