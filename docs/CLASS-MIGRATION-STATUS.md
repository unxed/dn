# Class migration: status and administrative record

Last updated: 2026-10-05

Product frame for this work: **DN 3.0** — stable port, minimal interventions;
deferred features and owner exceptions: [`DN-3.0.md`](DN-3.0.md).

## Status snapshot (2026-10-05, afternoon)

| Item | State |
|---|---|
| Gate | **OPEN** |
| Core accept | **32/32 PASS** |
| Full matrix | **Delegated to GitHub Actions** (`.github/workflows/dn-accept.yml`, 12 shards) |
| Known noise fixed | About/build rows masked; cursor-only ignored; unique temp paths |
| Known object crash | ♦ menu Trashcan on/off (`cmHideShowTools`, was `menu_0_10`): object Invalid pointer operation; class OK — excluded from accept grid |
| Classic palette | Class on `CColor` |

## Working agreement

- DN and TV3 work is on `main`; no migration feature branches are in use.
- Use the system `gh` authenticated as `unxed`. Push every commit to GitHub
  immediately; verify the remote ref after publishing.
- For GitHub issues, send Markdown with real line breaks (for example through
  `gh issue edit --body-file -` and a quoted here-document), not escaped `\\n`
  text. Read the issue back with `gh issue view --json body` and verify the
  stored newlines and Markdown structure after every create/edit.
- Keep changes small and atomic. Before a regex or potentially destructive
  bulk edit, create and publish a checkpoint. If the transformation is wrong,
  restore that checkpoint rather than repairing individual fallout.
- After each successful fix, add/check the analogous-pattern item in
  `CLASS-MIGRATION-REGRESSION-CHECKLIST.md` and perform the repository-wide
  search before treating the fix as complete.
- After ten fixes, review whether the workflow can be made more efficient.
- Record each newly observed object/class discrepancy in the acceptance gate
  immediately. Do not call a smoke run full acceptance.

## Controlling source versions

| Role | DN | Turbo Vision | Use |
|---|---|---|---|
| Last object-based baseline | `b4916b874989d7b35660d02cf935dc5f0db7a656` | `521d06479198789deeaa6fda287236ca83ba4051` | Required behavioral comparator |
| Current class source used for the latest user build | `1380622` / later `main` (user `dn.err` build id); TV3 pin below | `ca5cd6bcab8e04a9a95018a3a3183b2b18f73cf3` | Rebuild from the current class-based `main` before final acceptance |
| Older distributed binary | distribution commit `11daf16c6f0ac69f8bbaeb34407c764408bad3e4`, built from `df0cca2` | pre-class distribution | Context only; do not substitute for the last object-based baseline |

The user-reported self-build Fatal Errors are from
`/home/unxed/dev/dn/out/linux64/dn` build id `1380622` compiled
`2026-10-05 11:21:22 UTC` (`dn.err` addresses `00534B61`, `0058BDD2`).
Those faults appear only on class self-builds; pre-class `dist` does not show
them on the same actions. The historical checkout `/home/unxed/dev/dn` is
evidence/build input only, not the publication target.

## GitHub issue #6 (startup redraw)

[unxed/dn#6](https://github.com/unxed/dn/issues/6) — **fixed and closed**.
Root cause: after startup `MyApplication.Draw`, `WriteScreenCells` flushed a
stale 16-bit cell copy over the panels. Fix: `ReadScreenCells` immediately
after the draw (`7572d73`); skip the follow-up `WriteScreenCells` under
`-dDNUTF8` (`ab9ebd8`). Regression: configured `tools/dn-linux-startup.py`;
virgin About `tools/dn-linux-about.py`. Full-cell
object/class parity remains an open gate item, not this symptom.

## Reproduction and verification ledger

| Check | Evidence so far | State |
|---|---|---|
| Virgin first launch: About image remains after close | Same stale-copy path as configured blank panels. After `ReadScreenCells` post-draw: Esc and Enter each leave panels with no About markers (class `out/linux64`/`out/dn` and pre-class `dist/linux64`, 2026-10-05). Regression: `tools/dn-linux-about.py`. | Fixed with #6 (`7572d73`); full-cell parity still open |
| Configured launch (`dn.ini`): blank panels until menu | Was 10/10 blank on class `7eaca15` vs panels on object `b4916b8` (shared ini SHA-256 `1a9b0b2b…`). After fix: class+object 5/5 show panels before input and after F10+Right on gate binaries. | Fixed (`7572d73`/`ab9ebd8`); `tools/dn-linux-startup.py` |
| Class-vs-`dist` diagnostic | `dist` appears to draw panels before menu, but per-build saved `dn.ini` files differed; this is not controlled causal or acceptance evidence. User confirmed `dist` predates classes. | Excluded from the controlling comparator |
| PTY alternate-screen restoration | Fixed in `133f3d4`; two focused tests cover cell/attribute/cursor restore and repeated transitions. Whole tool suite passed 34 tests. | Verified harness fix; not a DN behavior fix |
| Pascal string collection representations | Language menu / `ChLngId` read `TStringCollection` ShortString items via `PString` while `System.PString` (^AnsiString) was visible after `uses SysUtils`. Audited all `PString(….At(…))` sites: only `dnutil` `ChLngId` was a confirmed mismatch (same class as `cmExecFile`); peers store ShortStrings and already resolve to `Defines.PString` or `pstring_bind`. | Fixed: `PShortString` in `ChLngId`; peers left unchanged after type review |
| Case-insensitive `object` tree audit | Initial inventory search `rg -uuu --text -i -l object . -g '!.git/**'` listed 348 paths, including docs, bootstrap, tests and compiled output. | Newly registered subtask; full contextual audit not started |
| `F4` internal editor AV (class only) | Fixed: `Build_REditSaver`/`Store_REditSaver` now match `TLoadProc`/`TStoreProc` (stream by value). | Fixed on class self-build; object/class parity still required |
| `Ctrl+O` user screen AV (class only) | Fixed: nil-check `UserScr` before `.Cols`; `VtShowScreen` guards nil (`tv3` `396fb86`). | Fixed on class self-build; content parity after a command still open |
| Autosave desktop second-start crash (class only) | Fixed: `TFilePanelRoot.Store` must `S.Put(Drive)` (migration had `Drive.Store(S)`, omitting the stream type id and desyncing Load). Peer fixups pointing at `Self` were a symptom. Local PTY: second start alive with preserved `…/sub>`. | Fixed on class self-build; keep ops autosave gate |
| Nested submenu geometry (inside parent, not to the right) | User: dropdown submenus feel positioned inside the parent menu. Code places the child below the item at the same X (`menus.pas`). Same on object sources and on `dist` PTY — **not a class regression**. | Documented; UX/acceptance note, not migration-only |
| Yes/default button red–magenta | User: Yes is red, counter-intuitive; want classic DN colors. Object baseline `b4916b8` used `CColor` (cyan default). Class briefly defaulted to `CColorOsp` in `0c4e839`; restored to classic `CColor` in `b57025b` (`mainapp.pas` → `palettes.CColor`). PTY ALT-X Yes body bg=6 (cyan) on rebuild; pre-switch `out/linux64` Yes bg=9 (OSP red). | **Yes** — classic `CColor` default for acceptance |
| ZIP single-byte name/comment charset | Owner: decode 1:1 (incl. bugs) via [zipcharset](https://github.com/unxed/zipcharset) + [localecp](https://github.com/unxed/localecp); locale→CP as reusable subproject | **Minimal listing path landed:** `dn/lib/localecp` + `dn/lib/zipcharset` wired in `fmtzip.GetFile`; tests `t_zipcharset` + `tools/test-zipcharset.py`. Gaps: Win ACP/OEMCP, multi-byte CPs, comment UI — `docs/ZIP-CHARSET.md` |
| Drive hierarchy + archive `GetFile` VMT hides | Enter `aaa.zip`/`aaa.7z` listed `inside.txt`; no Fatal/Broken. `af5337f` fmt+Arc/Arvid; `ce2e9dd` Find/Temp overrides. Alt-F7 Find File dialog still opens. | Fixed on class self-build; keep PTY enter gate |
| Archive ctor `Destroy; Fail` double-free | `b9a6153`: `TArcDrive.Create` / `TArvidDrive.Load` use `Fail` only (FPC runs destructor once). | Fixed; audit other `Destroy; Fail` ctors |
| UTF-8 panel names `?????` until Ctrl-R | `ab9ebd8`: post-startup `WriteScreenCells` skipped on `-dDNUTF8` (16-bit copy maps multi-byte cells to `?`). `DN_OPS_UTF8=1` dn-linux-ops green. | Fixed on class UTF-8 build |
| Enter non-exec (`cmExecFile`) AV | Fixed: `System.PString` (^AnsiString) hid `Defines.PString` after `uses SysUtils`; bind + `PShortString` in `DoExecFile`. | Fixed on class self-build |
| Nested / compound archive matrix | User: nested (`.tar.gz` etc.) broken; intermittent AV; editor hung once opening a file from archive. Need fixtures + click-through + autotests | **Partial:** `.tgz`/`.tar.gz` Enter+list OK (`fmttgz`); fixtures + `dn-linux-archives.py` Enter/leave green. Open: F3/F4/F5, peers, CI — `docs/ARCHIVE-MATRIX.md` / PLAN 4c |

An earlier 100-start attempt sampled before waiting for UI readiness; it is
invalid and not counted. The configured blank-panel mismatch (10/10 before
`7572d73`) is fixed; remaining gate work is full-cell object/class parity.

## Remaining work, in order

1. Finish remaining class-only crashes / archive gaps: nested/compound
   formats (`.tar.gz`…), F3/F4/F5 from inside archives, hang/AV cases —
   `docs/ARCHIVE-MATRIX.md` / PLAN 4c. Zip/7z Enter OK after
   `af5337f`/`ce2e9dd`. Keep `dist` as negative control only; acceptance
   comparator is the last object-based baseline.
2. **Hard gate (blocking everything below):** last object-based vs last
   class-based DN — all functions, all scenarios, bitwise cell compare
   (glyph + fg/bg + attrs + cursor + process + side effects). Spec:
   `docs/CLASS-MIGRATION-ACCEPTANCE-GATE.md`. Mismatch → fix; do not proceed.
   Same wrong output on **both** object and class → still fix (shared-bugs rule
   in the gate doc); parity is not an excuse to keep defects.
3. Only after the gate PASSes — post-class stages in order
   (`docs/POST-CLASS-WORK.md`):
   1. English (comments, docs, user strings / hardcode)
   2. Refactoring for readability (publish done-criteria first)
   3. Separate and formalize platform-dependent code
   4. Expand tests to a minimally decent level (incl. Linux / DOS / Windows)
4. Until the gate PASSes, also keep chasing known open matrix rows:
   full-cell object/class parity, ZIP charset (`docs/ZIP-CHARSET.md`),
   archive matrix (`docs/ARCHIVE-MATRIX.md`), etc. Startup blank panels /
   About residue (#6) are fixed functionally.

## Recorded issue and administrative commits

GitHub issue [#6](https://github.com/unxed/dn/issues/6) tracked the
panel-redraw symptoms; functional fix is on `main`.

Relevant pushed commits on DN `main`:

- `7572d73` — `ReadScreenCells` after startup draw (issue #6).
- `ab9ebd8` — skip post-draw `WriteScreenCells` under `-dDNUTF8`.
- `133f3d4` — repair/test PTY primary-screen restoration.
- `d00a7f3` — record exact object/class acceptance baseline and reported panel
  symptoms.
- `4368e7f`, `1a06986`, `254bc78`, `273648a`, `4e2ceb5`, `cccc6a5`,
  `6fe26fb` — record the discrepancies, reproductions, build-variant scope,
  `dist` provenance, and current test policy. `254bc78` is the rebased
  publication of the local scope-recording change.
- Administrative commits that record gates/discrepancies; the repository HEAD
  is authoritative for the latest SHA after each push.
