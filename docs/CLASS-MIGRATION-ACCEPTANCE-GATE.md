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
The first bitwise startup/menu comparison found a **FAIL**: 2722 cell states
differ, including foreground/background attributes (for example, baseline
background index 6 versus class-build background index 2). Investigation
traced this to a palette revision: the classic binary uses the older
red/magenta OSP table, while the class source explicitly installs the newer
dark-gray/cyan/yellow DN table in `dn/src/mainapp.pas`. `TvColors` and
`TvAnsi` behavior is unchanged. This is not permission to ignore the
difference: the final comparison must use an object baseline built with the
same intended palette revision, or preserve the old palette in the class
build if classic visual compatibility is the requirement.

## Latest reproducible smoke result (2026-10-05)

Compared object DN `10763d65d091fc8525599a45c155be228c1bb8b6` (classic TV
`c9bb5c4d0d87e73382ebdd48c117f4c29e1ae9e5`) with class DN
`0c4e839100fe482ff31a842e0028045b9fd3eda0` (TV3 `5e5bf1120770c5da44aa1f75fe5677d621037775`),
using the same absolute run directory, 100x30 PTY, English resources, `LANG=C`,
and identical panel fixture. The check used `PtyTerm.screen.cells`, not its
text-only view.

The first startup checkpoint is **FAIL**: 140 cell states differ, all text
cells (including the ticking clock); the visible About text identifies object
DN as `2.14 beta/DPMI32` and class DN as `2.20 alpha/Linux x86_64`, with
different build revision/date text as well. After the same Enter key, the
object build closes the startup dialog while the class build still displays
its Warning/About text. That checkpoint is also **FAIL**: 637 differing
cells, including 346 attribute-only differences. Enter, Space, or Escape
individually did not clear the class warning from the captured screen; after
Escape, F7 followed by creating a directory did work and the subsequent
redraw cleared the warning. This points to a redraw/output mismatch rather
than proving that the dialog continues to consume input. The class screen also
emits `?` where the object screen emits several box/marker glyphs.

These are observed compatibility failures, not exclusions or approved
normalizations. The identical-run smoke is not yet a reusable full acceptance
harness, and no matrix row is promoted to pass by this probe. Keep the gate
**OPEN**; diagnose the input/dialog and glyph differences, then compare every
matrix action with cursor, all cell attributes, process result, and side
effects captured.

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
