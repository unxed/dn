# Class migration

Part of the **DN 3.0** milestone: a stable port to the new stack with minimal
interventions. Product framing (what 3.0 includes, what is deferred, Far UX /
keyboard / clipboard exceptions): [`docs/DN-3.0.md`](docs/DN-3.0.md).

Both repositories are worked on directly in `main`. Every commit is pushed to
GitHub immediately after it is created.

## Required gates

- **Object vs class bitwise acceptance (hard stop):** last object-based DN vs
  last class-based DN, every scenario of every function, full cells (glyph,
  fg/bg, attributes), cursor, process result, side effects. Mismatch → fix,
  do not advance. Details: `docs/CLASS-MIGRATION-ACCEPTANCE-GATE.md`.
  **After** that gate PASSes only: English / refactor / platform split /
  broader tests — `docs/POST-CLASS-WORK.md`.
- The class-migrated TV3 tree has a case-insensitive whole-tree scan for
  `obj[e]ct`, including ignored files and binary build caches; Git metadata is
  excluded. Keep compiler output outside the scanned tree.
- The DN gate is `tools/class-gate.sh` (`tools/class-gate.py`, run by
  `tools/dn-test.sh`, tests in `tools/tests/test_class_gate.py`). It is
  blocking on the keyword `object` in the code of every tracked Pascal file
  (`.pas`, `.pp`, `.inc`, `.dpr`, `.lpr`): an old `T = object(...)` or
  `packed object` type. Comments, string literals, other words
  (`TFindObject`, `ExceptObject`), documentation and non-Pascal files are
  not matched: they are not a programming-style question. `CLASS_GATE_EXCLUDE`
  (default `bootstrap/`, the record of how the first tree came to be, which
  CI job `bootstrap` reproduces; an empty value scans everything) sets the
  paths that are not scanned. The old construction idioms `New(T, Init(...))`
  and `Dispose(P, Done)` are printed as a count; `CLASS_GATE_STRICT=1` makes
  them blocking (the final acceptance should run it). This replaces the earlier
  whole-tree substring scan for `object`, which also failed on prose,
  comments and names, and so hid the real result.
- Classes use their semantic `T...` names, direct member access, `Create`, `Destroy`
  and `Free` or `FreeAndNil`. An alias carrying an old pointer/type name is not a
  completed migration. Actual pointers to records and scalar data remain pointers.
- Overridden methods must dispatch through the inherited class API. Resource
  loading must construct the required subclass; changing an instance's VMT is
  not an acceptable final implementation.
- Preserve ownership, stream compatibility, behaviour and supported platforms.
  Passing a focused check does not prove the entire application is ready.

## Editing and verification

1. Save and publish the current state before a regular expression or another
   potentially destructive bulk rewrite. Record the exact checkpoint SHA.
2. If a rewrite gives incorrect results, roll back the whole affected batch to
   that checkpoint. Reapply sound transformations from the original source.
   Never repair the individual consequences of the failed rewrite.
3. For every successfully converted pattern, check whether one script can cover
   all semantically equivalent uses across the active sources. Keep record
   pointers, strings and comments distinct from class references.
4. Make small atomic changes, from simple class APIs to more complex ownership
   and loading paths. Run meaningful checks for each change and push its commit.
5. After each ten fixes, review how to improve efficiency: batch recurring
   transformations, improve the conversion tool, and remove redundant checks.
6. GitHub Actions results are authoritative only for their exact commit and a
   terminal successful run. Required full builds and runtime checks must pass
   before the migration is accepted as complete.

## Remaining implementation work

- Remove class-reference aliases in tv3 and DN and update their consumers.
- Complete construction, destruction, direct member access and overrides in DN.
- Replace resource retyping with subclass construction by the resource loader.
- Bring the complete DN tree through its spelling gate, including build output.
- Remove the old construction idioms that `tools/class-gate.sh` counts
  (`New(T, Init(...))` in `dn/src/pktview.pas`), then run it with
  `CLASS_GATE_STRICT=1` and with `CLASS_GATE_EXCLUDE=` for acceptance.
- Verify native and DOS tv3 checks, then the supported DN builds, full
  object/class parity and runtime tests.
- Publish only to `main`; the previous branch/PR integration step has already
  been completed and is not part of the remaining work.

The `class-migration` workflow checks the current focused regression tests.
It supplements the full workflows and does not waive either final tree gate.

## Startup redraw (issue #6)

- Cause: `WriteScreenCells` outputs a separate 16-bit copy refreshed only by
  `ReadScreenCells`; after the startup `MyApplication.Draw` the copy was stale
  (empty start), so configured starts showed a blank field and virgin starts
  kept the About image. Fix: `ReadScreenCells` right after the startup draw
  (`boot.pas`), then `WriteScreenCells` for the legacy 16-bit build only.
  With `-dDNUTF8`, `ReadScreenCells` maps multi-byte cells to `'?'` in the
  copy, so the post-draw `WriteScreenCells` must not run (UTF-8 panel names
  would otherwise show as `?????` until Ctrl-R).
- Regression: `tools/dn-linux-startup.py` (shared `dist/linux64/dn.ini`,
  panels before any key, then F10+Right); `tools/dn-linux-about.py` (no
  `dn.ini`, Esc and Enter clear About without residue). The `dn-linux-ops.py`
  autosave-desktop `dsk_cwd` check also fails without the fix.
- Open: full cell comparison object/class (colours, several symbols) is not
  closed; the 100-run acceptance is not done. Autosave-desktop second-start
  SIGSEGV is fixed (`S.Put(Drive)` in `TFilePanelRoot.Store`).
- Analogues reviewed, not the same bug: `dn.pas:130` (fatal-error screen) and
  `videoman.pas:447` (`DoneVideo` restoring the user screen) write intentional
  buffers, not a post-`Draw` stale copy.

## Class-only runtime crashes (recorded 2026-10-05)

Self-build only; absent on pre-class `dist`. Details live in
`docs/CLASS-MIGRATION-REGRESSION-CHECKLIST.md`.

- `F4`: **fixed** — `Build_REditSaver`/`Store_REditSaver` match `TLoadProc` (no `var S`).
- `Ctrl+O`: **fixed** — nil-check `UserScr`; `VtShowScreen` guards nil (`tv3` `396fb86`).
- Autosave desktop restore: **fixed** — `TFilePanelRoot.Store` uses `S.Put(Drive)` again (was `Drive.Store(S)`).
- Plain zip/7z Enter: **fixed** (fmt + drive `override`). Nested `.tgz`/`.tar.gz`
  Enter+list: **fixed** (`fmttgz` gunzip+tar on Unix). Remaining matrix (F3/F4/F5,
  peers, CI): `docs/ARCHIVE-MATRIX.md`.
- Failed archive ctor: **fixed** — `Destroy; Fail` → `Fail` only (`arcview`/`arvid`, `b9a6153`).
- UTF-8 panel names at startup: **fixed** — no post-draw `WriteScreenCells` on `DNUTF8` (`ab9ebd8`).
- Enter on non-exec file (`cmExecFile`): **fixed** — `System.PString` (^AnsiString) vs `Defines.PString` (^ShortString) after `uses SysUtils` (`pstring_bind.inc` / `PShortString`).

## UI notes (not all are class regressions)

- Nested dropdown submenus sit on top of / inside the parent menu (same X,
  below the item). Same formulas in object/`dist` — **not class-only**.
- Default Yes button is red–magenta under `CColorOsp`; classic DN is `CColor`
  (cyan default). Object baseline used `CColor`; user wants classic colors.
