# Class-migration acceptance gate

Hard stop inside the **DN 3.0** milestone (stable port to the new stack).
Product framing: [`DN-3.0.md`](DN-3.0.md).

The class migration is complete only when the last working object-based DN and
the current class-based DN pass the same action matrix. A mismatch means that
porting artifacts remain.

Current gate status: **OPEN**. Compare the latest object-based DN against the
latest class-based DN, recording each exact revision and TV submodule. The
older distribution artifact (`dist/`) is **not** a substitute comparator.

## Hard gate (owner, 2026-10-05) — bitwise, all functions

Until this gate **PASS**es, **do not** start English translation, readability
refactoring, platform-code separation, or the broad test expansion. Those
post-success stages live in `docs/POST-CLASS-WORK.md`.

**Comparator:** last object-based revision vs last class-based revision (exact
SHAs + TV/TV3 pins), same fixtures, same terminal size/locale, same scripted
actions. Rebuild both for the run; do not reuse stale binaries as the
authority.

**Coverage:** every scenario of every user-visible function — menus and nested
menus, panels, file ops, archives, tools, dialogs, startup/teardown, keyboard /
command-line / mouse paths where supported — success and cancel/error paths.

**Compare at each checkpoint (all must match):**

| Channel | What |
|---|---|
| Glyph | Unicode cell contents (including blanks) |
| Color | Foreground **and** background per cell |
| Attributes | Style bits the harness exposes (bold/underline/etc. if present) |
| Cursor | Position and visibility |
| Process | Alive/exit status, `dn.err` / fatals |
| Side effects | Files, cwd, `dn.ini` / `dn.dsk`, temp artifacts |

`Screen.lines()` / text-only dumps are **diagnostic only** and cannot pass the
gate. Use the full `Screen.cells` (or equivalent) matrix.

**Rule:** any mismatch → gate stays **OPEN** → fix the class build (or prove
object was wrong and fix with owner agreement) → re-run the failing scenarios.
No “close enough”, no skipping to post-class work.

**Shared bugs (owner, 2026-10-05):** the comparator is *last object-based* vs
*last class-based*. If **both** builds show the **same** wrong UI, side effect,
or crash for a scenario, that is **not** preserved legacy — **fix it** on the
class line (and backport to the object baseline when that tree is still
maintained for the gate). Do **not** leave defective behavior just because the
object revision had it before the migration. Record the fix in the regression
checklist; re-run the scenario on both builds when the object tree is still
used for acceptance.

## Current controlling result (2026-10-05)

The latest object baseline identified so far is DN
`b4916b874989d7b35660d02cf935dc5f0db7a656` with TV
`521d06479198789deeaa6fda287236ca83ba4051`. The latest class build is DN
`7eaca15be92b86e69fb43a830029ed4e9e92a8e2` with TV3
`ca5cd6bcab8e04a9a95018a3a3183b2b18f73cf3`. Recheck that no later object-based
revision exists before final acceptance; rebuild both exact revisions with
identical build metadata and fixtures. Earlier trials against
`33674fed7829124fbd3230440faf3075c45eb9f6` or the much older
`10763d65d091fc8525599a45c155be228c1bb8b6` do not replace this comparison.

The corrected 24-scenario PTY tour completed on earlier builds, but it did not
exercise every action or provide a reproducible exact-cell comparison for
every checkpoint. A separate full menu-cell probe exposed actionable
differences: at menu item `(0,4)` the class build raised an access violation
where the object build completed normally; at `(0,10)` (♦ system menu,
Trashcan on/off / `cmHideShowTools`) the object build ended with an Invalid
pointer operation while the class build showed Trash correctly. Root cause:
object `TTrashCan.GetPalette` returns `@CTrashCan` against TV’s dynarray
`TPalette` (`MapColor` → RTE 204); class uses `MakePalette(CTrashCan)`.
Tracked in [#14](https://github.com/unxed/dn/issues/14). The accept harness
excludes `menu_0_10` — cannot PASS on the unmodified object baseline binary.
Changing language also raised an access violation in the class build. The
language-menu crash was traced to interpreting a `TStringCollection`
ShortString item as an AnsiString (`System.PString` after `uses SysUtils`).
`ChLngId` in `dnutil.pas` now reads items via `PShortString` (same typed fix
as `DoExecFile`). Repository-wide `PString(Collection.At(...))` peers in
`paneldlgs.pas`, `printman.pas`, `histories.pas`, `eraser.pas`, `diskinfo.pas`,
and `filefind.pas` were reviewed type-by-type: they store ShortStrings and
already resolve to `Defines.PString` / `pstring_bind`, so they were left
unchanged.

Startup redraw ([issue #6](https://github.com/unxed/dn/issues/6)) is **fixed
functionally**. Both virgin About residue and configured blank panels shared
one cause: after `MyApplication.Draw`, `WriteScreenCells` flushed a stale
16-bit cell copy (`Drivers.ScreenBuffer`) over the panels. Fix in
`dn/src/boot.pas`: `ReadScreenCells` immediately after the startup draw
(`7572d73`); under `-dDNUTF8` skip the follow-up `WriteScreenCells`
(`ab9ebd8`) so UTF-8 names are not replaced with `?`.

Pre-fix evidence (for the record): with shared `dn.ini` SHA-256
`1a9b0b2b63ba27eb9324c3a09587ac337426756e174ba77f60ef05a8ab52ad9f`, terminal
`100x30`, object `b4916b8` showed panels before input in 10/10 pairs while
class `7eaca15` showed a blank purple area; F10+Right revealed panels on both.
Post-fix: class and object gate binaries show panels before input and after
F10+Right (5/5 each); virgin Esc and Enter leave panels with no About residue
(`tools/dn-linux-about.py`). Configured regression: `tools/dn-linux-startup.py`.
Full-cell object/class parity (glyph/color/attrs) remains open under this gate
and is separate from the blank-panel symptom.

The acceptance harness itself previously mishandled `CSI ? 1049 h/l`: it
did not save and restore the primary-screen cells, attributes, and cursor.
`tools/pty_screen.py` and its regression tests now cover the alternate-screen
transition. This is a harness correction only; it does not resolve or waive
any DN rendering discrepancy.

These are hard failures, not approved normalizations. No action-matrix row is
promoted to pass by a smoke tour or a diagnostic-only source copy. Keep the
gate **OPEN** until the exact object and class builds have replayed every
user-visible action and all checkpoints match.

## Newly recorded class-only crashes (2026-10-05)

Observed on class self-builds only; pre-class `dist` does not show them.
User evidence: self-build `1380622` (`2026-10-05 11:21:22 UTC`),
`/home/unxed/dev/dn/out/linux64/dn.err` addresses `00534B61` and `0058BDD2`.
Local confirmation on class `out/linux64` and CI `dn-linux-ops.py`.

| Action | Class self-build | `dist` (pre-class) | Evidence |
|---|---|---|---|
| `F4` open internal editor | **fixed** on class (`a14015a`) — was Fatal Error / Access violation | pass | was `dn.err` `00534B61`; cause `var S` stream callbacks in `editwin.pas` |
| `Ctrl+O` user/command screen | **fixed** on class (`a14015a` / tv3 `396fb86`) — was Fatal Error / Access violation | pass | was `dn.err` `0058BDD2`; cause nil `UserScr` before first command |
| Autosave desktop second start (`dn.dsk` + Preserve directory) | **fixed** — was SIGSEGV / banner-only; `TFilePanelRoot.Store` again uses `S.Put(Drive)` | pass — restores `…/sub>` | Local PTY: first quit writes `dn.dsk`; second start alive with preserved `sub>` prompt |

`F4` / `Ctrl+O` / autosave-desktop / issue #6 startup redraw are fixed on class;
the gate remains **OPEN** for the full object/class matrix (including cell parity).

## UI observations (2026-10-05)

| Observation | Class vs object / `dist` | Notes |
|---|---|---|
| Nested top-menu submenu opens overlapping the parent box (not to the right) | **Same on `dist` and class** (shared `menus.pas` placement: below item, same X) | **Not a class regression.** Recorded as UX/acceptance geometry; change only with deliberate tests |
| Default **Yes** button looks red/magenta | Was class `CColorOsp` vs object `CColor` | **Switched class to classic `CColor`** (owner 2026-10-05) for acceptance parity |

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
| Startup/teardown | Start, initial panels, redraw/resize, `Alt-X`, clean teardown | core PASS | core PASS | **pass** (32-scenario core 2026-10-05) |
| Main menus | File, Disk, Utilities, Panel, Manager, Options, Window | core open | core open | core PASS; full `menu_M_N` grid running |
| Nested menus | Every submenu, enabled/disabled state, geometry, cancellation | pending | pending | partial (`menu_file_view_sub` PASS) |
| Panels | Switch, drive, directory, manager-new, select, sort, filter, view mode | core PASS | core PASS | **pass** (tab/alt-F1/alt-F10/ctrl-L/R/ins/plus) |
| File operations | View, edit, copy, move, rename, delete, attributes, cancel/error paths | core PASS | core PASS | **pass** (F3–F8 + F5 cancel) |
| Archives | Enter/leave, list, nested (`.tar.gz`…), F3/F4/F5, error paths; ZIP charset (`docs/ZIP-CHARSET.md`); matrix (`docs/ARCHIVE-MATRIX.md`) | core zip Enter | core zip Enter | core PASS; full archive matrix still open |

Harness: `tools/dn-linux-accept.py OBJECT_OUT CLASS_OUT` — shared work tree, full
`Screen.cells` + cursor compare (menu-bar clock + digit/time noise masked), core
scenarios + every top-menu cell (`menu_M_N`). Object baseline: DN `b4916b8` + TV
`521d064`. **Core result 2026-10-05:** `SUMMARY pass=32 fail=0`. Gate still
**OPEN** until the full menu grid and remaining areas finish.
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
