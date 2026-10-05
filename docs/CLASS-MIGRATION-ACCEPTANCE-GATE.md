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

The user additionally reported two panel-rendering discrepancies, which are
recorded as user-observed and still require reproduction against the exact
build pair: closing About on first launch consistently leaves the dialog
image over the panels; and on some clean starts panels are initially absent
until opening a menu triggers redraw. The latter is intermittent. The source
search found redraw/draw entry points in `mainapp.pas`, `panelroot.pas`,
`paneldlgs.pas`, and `menus.pas`; it has not isolated the responsible path.
These reports are hard failures, not accepted normalizations.

Startup/panel regressions to reproduce and fix:

* Closing the About dialog on first launch consistently leaves its image
  visible over the panels.
* On some clean starts the panels are not drawn until opening a menu causes a
  redraw. Treat this as intermittent: run at least 100 fresh starts, capture
  the screen before opening any menu, and require zero missing-panel trials.
* For the About residue, capture the screen immediately before opening About,
  while About is open, and immediately after closing it; all prior panel cells
  must be restored on every trial.

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
