# Class migration: status and administrative record

Last updated: 2026-10-06

Product frame for this work: **DN 3.0** — stable port, minimal interventions;
deferred features and owner exceptions: [`DN-3.0.md`](DN-3.0.md).

## Status snapshot (2026-10-06)

| Item | State |
|---|---|
| Gate | **CLOSED** on last behavior-verified SHA `06259f5` (2026-10-06) |
| Core accept | **32/32 PASS** (historical) |
| Full matrix | **177/177 PASS** on exact SHA `06259f5` (12 shards; GitHub run `37383488177`; object DN `b4916b8` + TV `521d064` vs class DN + TV3 `a06dd31`) |
| Accept harness | Menu FAST settle (`ad9c4f7`); fil/dir count + Help open waits; long-scan Esc dismiss (`menu_2_7..9`, `menu_4_12`) |
| Known noise fixed | About/build rows masked; cursor-only ignored; unique temp paths |
| Known object crash | ♦ Trashcan (`cmHideShowTools` / `menu_0_10`): object `TTrashCan.GetPalette`=`@CTrashCan` vs dynarray `TPalette` → RTE 204; class `MakePalette` OK — skip kept ([#14](https://github.com/unxed/dn/issues/14)) |
| Accept skips (harness) | `menu_0_16` (♦ Game/Tetris animation), `menu_3_8` (Edit OS Environment — live env), `menu_5_2` (Manager Directory tree scan). Re-enabled: `menu_4_5` Branch, `menu_6_16` Colors |
| Classic palette | Class on `CColor` (`b57025b`) |
| Startup / About | [#6](https://github.com/unxed/dn/issues/6) fixed (`7572d73`); regressions `tools/dn-linux-startup.py` / `dn-linux-about.py` |
| F5 file-copy ownership | Fixed with `TLineQueue` (`3bc0d0f`); `f5_f6_f8` parity scenario and all Linux ops pass on `06259f5` |
| Archives xz / F5 | Local ALL OK (`5f02362`); GitHub Linux archive matrix green on `06259f5` |
| ZIP charset | Listing path `27de843` |
| `ChLngId` | `PShortString` (`88c19f8`) |

## Working agreement

- DN and TV3 work is on `main`; no migration feature branches are in use.
- Use local checks for fast feedback and GitHub Actions for exact-SHA acceptance.
  Every commit is pushed to GitHub immediately as required by the owner; use
  system `gh` authenticated as `unxed` and verify the remote ref after push.
- For GitHub issues, send Markdown with real line breaks (for example through
  `gh issue edit --body-file -` and a quoted here-document), not escaped `\\n`
  text. Read the issue back with `gh issue view --json body` and verify the
  stored newlines and Markdown structure after every create/edit.
- Keep changes small and atomic. Before a regex or potentially destructive
  bulk edit, create a local checkpoint commit. If the transformation is wrong,
  restore that checkpoint rather than repairing individual fallout. Push
  every checkpoint immediately.
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
| Current class source used for latest full parity | DN `06259f57c4ac1c72456b2162ca9df34ec4a5105f` | TV3 `a06dd31` | 177/177 acceptance + exact-SHA Linux/Windows CI green |
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
| Pascal string collection representations | Language menu / `ChLngId` read `TStringCollection` ShortString items via `PString` while `System.PString` (^AnsiString) was visible after `uses SysUtils`. Audited all `PString(….At(…))` sites: only `dnutil` `ChLngId` was a confirmed mismatch (same class as `cmExecFile`); peers store ShortStrings and already resolve to `Defines.PString` or `pstring_bind`. | Fixed (`88c19f8`): `PShortString` in `ChLngId`; peers left unchanged after type review |
| Case-insensitive `object` tree audit | Initial inventory search `rg -uuu --text -i -l object . -g '!.git/**'` listed 348 paths, including docs, bootstrap, tests and compiled output. | Newly registered subtask; full contextual audit not started |
| `F4` internal editor AV (class only) | Fixed: `Build_REditSaver`/`Store_REditSaver` now match `TLoadProc`/`TStoreProc` (stream by value). | Fixed on class self-build; object/class parity still required |
| `Ctrl+O` user screen AV (class only) | Fixed: nil-check `UserScr` before `.Cols`; `VtShowScreen` guards nil (`tv3` `396fb86`). | Fixed on class self-build; content parity after a command still open |
| Autosave desktop second-start crash (class only) | Fixed: `TFilePanelRoot.Store` must `S.Put(Drive)` (migration had `Drive.Store(S)`, omitting the stream type id and desyncing Load). Peer fixups pointing at `Self` were a symptom. Local PTY: second start alive with preserved `…/sub>`. | Fixed on class self-build; keep ops autosave gate |
| Nested submenu geometry (inside parent, not to the right) | User: dropdown submenus feel positioned inside the parent menu. Code places the child below the item at the same X (`menus.pas`). Same on object sources and on `dist` PTY — **not a class regression**. | Documented; UX/acceptance note, not migration-only |
| Yes/default button red–magenta | User: Yes is red, counter-intuitive; want classic DN colors. Object baseline `b4916b8` used `CColor` (cyan default). Class briefly defaulted to `CColorOsp` in `0c4e839`; restored to classic `CColor` in `b57025b` (`mainapp.pas` → `palettes.CColor`). PTY ALT-X Yes body bg=6 (cyan) on rebuild; pre-switch `out/linux64` Yes bg=9 (OSP red). | **Yes** — classic `CColor` default for acceptance (`b57025b`) |
| ZIP single-byte name/comment charset | Owner: decode 1:1 (incl. bugs) via [zipcharset](https://github.com/unxed/zipcharset) + [localecp](https://github.com/unxed/localecp); locale→CP as reusable subproject | **Minimal listing path landed (`27de843`):** `dn/lib/localecp` + `dn/lib/zipcharset` wired in `fmtzip.GetFile`; tests `t_zipcharset` + `tools/test-zipcharset.py`. Gaps: Win ACP/OEMCP, multi-byte CPs, comment UI — `docs/ZIP-CHARSET.md` |
| Drive hierarchy + archive `GetFile` VMT hides | Enter `aaa.zip`/`aaa.7z` listed `inside.txt`; no Fatal/Broken. `af5337f` fmt+Arc/Arvid; `ce2e9dd` Find/Temp overrides. Alt-F7 Find File dialog still opens. | Fixed on class self-build; keep PTY enter gate |
| Archive ctor `Destroy; Fail` double-free | `b9a6153`: `TArcDrive.Create` / `TArvidDrive.Load` use `Fail` only (FPC runs destructor once). | Fixed; audit other `Destroy; Fail` ctors |
| UTF-8 panel names `?????` until Ctrl-R | `ab9ebd8`: post-startup `WriteScreenCells` skipped on `-dDNUTF8` (16-bit copy maps multi-byte cells to `?`). `DN_OPS_UTF8=1` dn-linux-ops green. | Fixed on class UTF-8 build |
| Enter non-exec (`cmExecFile`) AV | Fixed: `System.PString` (^AnsiString) hid `Defines.PString` after `uses SysUtils`; bind + `PShortString` in `DoExecFile`. | Fixed on class self-build |
| Nested / compound archive matrix | User: nested (`.tar.gz` etc.) broken; intermittent AV; editor hung once opening a file from archive. Need fixtures + click-through + autotests | **Partial:** `.tgz`/`.tar.gz` Enter+list OK (`fmttgz`); fixtures + `dn-linux-archives.py` Enter/leave green. `.tar.xz`/`.txz` + F5 extract smoke ALL OK locally (`5f02362`). Open: remaining F3/F4/F5 peers, full compound matrix — `docs/ARCHIVE-MATRIX.md` / PLAN 4c. Linux archive workflow is preferred exact-SHA evidence |
| F5 copy queue ownership | `CopyQueue` contained `TLine` classes but freed entries as `TFileCopyRec`, causing an AV immediately after copy | `dn/src/filecopy.pas` | **Fixed** (`3bc0d0f`) | `TLineQueue.FreeItem` frees each class; strict collection/ownership search clean; new `f5_f6_f8` parity scenario PASS; linux ops all green on SHA `06259f5` | Keep F5→F6→F8 check in ops and acceptance suites |
| Accept harness settle flakes | Menu scenarios could flake on FAST settle timing under load | Hardened (`ad9c4f7`); current full 177/177 acceptance is terminal green on exact SHA `06259f5` |
| F1 Help accept flake | Parallel FAST: object still idle active panels (`═[■]`) vs class Help open (panels `─┐`) — ~1172 cells, looks like frame/palette | Harness waits for Help title after F1 (`f1help`/`f1_esc`); class `THelpWindow`/`CHelpWindow` unchanged |

An earlier 100-start attempt sampled before waiting for UI readiness; it is
invalid and not counted. The configured blank-panel mismatch (10/10 before
`7572d73`) is fixed. Full-cell object/class parity most recently passed
177/177 on `06259f5`.

## Remaining work, in order

1. Verify the class gate with no exclusions (`CLASS_GATE_STRICT=1`) and exact
   baseline bootstrap reproduction after the historical Pascal inputs are
   retrieved from the pinned baseline commit; current local tests pass, new
   GitHub workflow is pending on this documentation/source change.
2. Keep full object/class parity closed at 177/177 on `06259f5`; rerun after
   any UI, drawing, events, resources, or stream changes. Any mismatch blocks
   later stages; shared bugs must still be fixed.
3. Stage 3 platform separation is next, based on the corrected current-layout
   plan in `docs/REFACTORING-CRITERIA.md` and `docs/POST-CLASS-WORK.md`.
4. Stage 4 adds the minimally decent Linux/DOS/Windows tests, after stage 3.
5. Track remaining product tests separately: `docs/ZIP-CHARSET.md`,
   `docs/ARCHIVE-MATRIX.md`, and optional `PKTVIEW` runtime coverage.

## Recorded issue and administrative commits

GitHub issue [#6](https://github.com/unxed/dn/issues/6) tracked the
panel-redraw symptoms; functional fix is on `main`.

Evidence commits already on DN `main` (local HEAD is authoritative; push
optional per `docs/CI-SERIAL.md`):

- `7572d73` — `ReadScreenCells` after startup draw (issue #6); About/startup
  regressions `tools/dn-linux-startup.py` / `dn-linux-about.py`.
- `ab9ebd8` — skip post-draw `WriteScreenCells` under `-dDNUTF8`.
- `ad9c4f7` — harden accept harness (menu FAST settle); `dn-accept` green
  on that SHA historically.
- `5f02362` — `.tar.xz`/`.txz` + F5 extract smoke; archives ALL OK locally.
- `27de843` — ZIP listing name charset via localecp/zipcharset.
- `88c19f8` — `ChLngId` `PShortString` ShortString collection reads.
- `b57025b` — classic `CColor` + initial object/class accept harness.
- `133f3d4` — repair/test PTY primary-screen restoration.
- `d00a7f3` — record exact object/class acceptance baseline and reported panel
  symptoms.
- `4368e7f`, `1a06986`, `254bc78`, `273648a`, `4e2ceb5`, `cccc6a5`,
  `6fe26fb` — record the discrepancies, reproductions, build-variant scope,
  `dist` provenance, and current test policy. `254bc78` is the rebased
  publication of the local scope-recording change.
- Administrative commits that record gates/discrepancies; the repository HEAD
  is authoritative for the latest SHA.
