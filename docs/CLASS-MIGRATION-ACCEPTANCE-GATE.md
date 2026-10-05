# Class-migration acceptance gate

The class migration is complete only when the last working object-based DN and
the current class-based DN pass the same action matrix. A mismatch means that
porting artifacts remain.

## Required comparison

For both builds, use the same clean temporary tree, terminal size, locale,
resource files, and key sequence. Record the rendered screen, exit status,
side effects in the input tree, and `dn.err` or exception output.

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

Status values are `pass`, `fail`, or `not applicable`; an untested row is not
acceptable. Any rendering difference, wrong menu position, missing dispatch,
changed side effect, crash, or teardown error keeps the gate open.

