# Class-migration acceptance gate

The class migration is complete only when the last working object-based DN and
the current class-based DN pass the same action matrix. A mismatch means that
porting artifacts remain.

Current gate status: **OPEN**. The classic baseline was identified as
`unxed/dn` `backup/before-history-rewrite-2026-10-03` and builds successfully
with the classic `unxed/tv` `main` revision `c9bb5c4`. Initial identical PTY
checks for startup/exit and top-level menu rendering have been run against
that baseline and the current build; the complete matrix is still pending.
The full `dn-linux-tour.py` run was stopped because its first baseline scenario
did not return; this is recorded as an acceptance-runner failure, not as a
passing result. Direct targeted PTY checks for baseline startup/exit and menu
rendering did return successfully.
The first bitwise startup/menu comparison also found a **FAIL**: 2722 cell
states differ, including foreground/background attributes (for example,
baseline background index 6 versus class-build background index 2). The
text/geometry is similar, but this is still a gate failure until the palette
provenance is resolved.

## Required comparison

For both builds, use the same clean temporary tree, terminal size, locale,
resource files, and key sequence. Compare the terminal state, not a
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

The text view printed by `Screen.lines()` is only diagnostic and cannot pass
this gate. The acceptance harness must compare the complete `Screen.cells`
matrix and cursor state at the same checkpoints.

Status values are `pass`, `fail`, or `not applicable`; an untested row is not
acceptable. Any rendering difference, wrong menu position, missing dispatch,
changed side effect, crash, or teardown error keeps the gate open.

