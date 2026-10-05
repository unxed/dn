# Post-class refactoring: done criteria

Owner order: after English (`docs/POST-CLASS-WORK.md` stage 2). **No large
refactor starts until these criteria are agreed and this file is on `main`.**

This stage is still **DN 3.0** (finish the port): make the tree navigable and
maintainable enough that platform split and tests can proceed. It is **not**
open-ended cleanup, Safe Pascal adoption, or “better than OSP” product work
(`docs/DN-3.0.md`, `dn/TODO-later.md`).

## Hard locks (every batch)

1. **Behaviour:** no intentional behaviour change. Proof before merge of a
   batch:
   - `DN_UTF8=1 tools/build.sh linux64 out/dn` succeeds;
   - `python3 tools/dn-linux-ops.py out/dn` PASS;
   - at least one accept shard or a targeted accept scenario set that covers
     the touched menus/paths is green locally.
2. **Gate:** if a batch can affect UI or streams, re-run enough of the
   object↔class accept matrix to be confident; a full 174/174 is required
   after any batch that touches drawing, events, desktop, or resources.
3. **Shared bugs:** object+class crashes found while refactoring are fixed
   (they are not “parity”). Intermittent unreproduced AVs stay tracked in
   `CLASS-MIGRATION-ACCEPTANCE-GATE.md` until caught.
4. **Scope:** one family / one concern per commit (same rule as
   `dn/TODO-refactoring.md`). No drive-by renames outside the batch.

## Done = all of the following

### A. Orientation (newcomer can find code)

- [x] `dn/FILES.md` lists every `dn/src/*.pas` unit with a one-line role (no
      “(?)” leftovers for entry points). *(2026-10-05: remaining-units index;
      entry points already in the main tables.)*
- [x] Remaining opaque archive names that a newcomer hits in the first hour
      have either a rename **or** an explicit “keep name / see FILES.md”
      line: `boot`, `mainapp`, `filepanel`/`panelroot`, `filescol`, `drives`,
      `cmdline`, `editcore`, `dnutil`. *(Already renamed; roles in FILES.md.)*
- [x] `tools/README.md` stays the single table for build/test scripts
      (already done; keep it true when adding scripts).

### B. Naming debt that still blocks reading

From `dn/TODO-refactoring.md` candidates, **in 3.0 this stage only**:

- [x] No new files with trailing `_`, digit-only suffixes, or duplicate
      near-names (`foo` / `foo2`) without an owner-approved exception in
      `TODO-refactoring.md`. *(Audit 2026-10-05: no `*_` / `arc_*` in
      `dn/src` or `dn/archives`. Digits only in format ids like `fmtbs2`,
      `fmtbz2`, and `dnutf8` — keep.)*
- [x] Outstanding rename families that are already half-done are finished
      **or** explicitly parked with owner names in `TODO-refactoring.md`
      (do not leave half-renamed pairs). *(Main families already done per
      TODO-refactoring “Done”; no half-renamed pairs in tree.)*
- [x] Archive format units under `dn/archives/` keep the directory as the
      namespace; no new `arc_` prefixes. *(All `fmt*.pas`.)*

Out of scope for this stage (post-3.0 / TODO-later unless owner moves them):

- Full Safe Pascal (`unxed/sp`) migration.
- Mass rename of every historical abbreviation (`SysXXX`, Russian stems).
- Dropping `osdep` / rewriting callers’ DOS error conventions.

### C. IFDEF and dual models (port debt, not beauty)

- [x] UTF-8 vs OEM call sites go through one small facade or a documented
      short list of units (`dnutf8` or equivalent); no new scattered
      `{$IFDEF DNUTF8}` outside that list. *(Facade: `dn/src/dnutf8.pas`.
      Allowed IFDEF sites as of 2026-10-05: `dnutf8`, `editcore`, `editfile`,
      `strutil`, `fileutil`, `filescol`, `basics`, `boot`, `cmdline`, `menus`,
      `setups`, `winclp`, `apploop`, `mainapp`, `calendar`, `compat/osdep`.
      New IFDEFs need a one-line note here.)*
- [x] Screen buffer API: call sites that mix `WriteLineW` / cell APIs are
      catalogued; new code uses cells only; at least the known mix-up class
      from 2026-10-03 has a regression test or accept coverage note.
      *(Catalog 2026-10-05 — `Write*W` only in: `idlers`, `calendar`,
      `dbview`, `panelwin`, `editundo`, `inputfname`, `topview`.
      `LegacyText` border: `compat/drivers.pas`. Panel draw path covered by
      accept matrix / `dn-linux-ops.py`; no new `Write*W` outside this list.)*
- [x] `tvtermos.pas` split **or** a written split plan with file boundaries
      accepted in this doc’s “Parked plans” section (implementation may be
      stage 3 if it is purely platform separation).

### D. Compat layer clarity

- [x] `dn/compat/` README or `FILES.md` section states what must stay for
      VP/DOS error semantics vs what is already thin FPC wrapping
      (table in `TODO-refactoring.md` is the source; sync summary into
      `FILES.md`). *(2026-10-05: “Keep vs thin wrap” table under How dn/
      is laid out in `dn/FILES.md`.)*
- [x] No new VP-emulation units; additions go to `tv/` or portable `dn/src`
      unless they are DOS real-mode only. *(Policy recorded in FILES.md;
      enforce in review.)*

## Parked plans

_(Fill when a criterion is deferred with owner OK.)_

| Item | Why parked | Revisit |
|---|---|---|
| Intermittent F4-after-clipboard / console AVs | No reliable PTY repro (2026-10-05 attempts: F4, Ctrl/Shift-Ins, Alt-Q, cmdline, Ctrl-O — 0/8 AV) | When reproduced or under far2l clipboard prompt |
| Safe Pascal style | Explicitly after 3.0 / separate track | Post-3.0 |
| `tvtermos` physical split | **Plan (stage 3):** split `tv/src/tvtermos.pas` into (1) `tvtermunix.pas` — termios / PTY / OSC / far2l hooks; (2) `tvtermwin.pas` — Win32 console / ConPTY; (3) keep a thin `tvtermos.pas` as the unit DN `uses` that re-exports the active target. VT interpret for console mode should call `TvVt` instead of a private copy. No behaviour change; proof = existing `tv` pty tests + DN linux/win smoke. | Stage 3 implementation |

## How to use this file

1. Pick the next unchecked box that matches a `TODO-refactoring.md` candidate.
2. Implement as one commit family; run the hard locks.
3. Check the box here in the same PR/commit as the proof note (command +
   result location).
4. Stage 2 is **done** when every checkbox in A–D is checked or parked in
   the table with owner agreement. Then start stage 3 (platform separation).
