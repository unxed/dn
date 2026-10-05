# Class migration: status and administrative record

Last updated: 2026-10-05

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
| Current class source used for the latest user build | `1f0a63db1b644c5b599fd75c2baf5d63e30166c2` | `ca5cd6bcab8e04a9a95018a3a3183b2b18f73cf3` | Rebuild from the current class-based `main` before final acceptance |
| Older distributed binary | distribution commit `11daf16c6f0ac69f8bbaeb34407c764408bad3e4`, built from `df0cca2` | pre-class distribution | Context only; do not substitute for the last object-based baseline |

The user-provided self-build `out/linux64/dn` identified build `1f0a63d` and
had SHA-256 `97f102cb466842bf6a0453ad5d83412a47ba06f2f427bf9578a62adc11a3cb7a`.
The `dist` binary had SHA-256
`e88ec6c324801bc394e9665095f705c452f5c34b7ec2ffa1363c80f58542a41d`.
The historical user checkout `/home/unxed/dev/dn` is not this task's writable
checkout; treat it as evidence/build input only, not as the publication target.

## Open GitHub issue

[unxed/dn#6 — Исправить перерисовку панелей при запуске](https://github.com/unxed/dn/issues/6)

Issue #6 tracks the two mutually exclusive startup states below. It requires
the latest object-based and latest class-based builds to use the same settings,
working path, terminal and action sequence; the pre-class `dist` binary is
explicitly excluded as the migration comparator.

## Reproduction and verification ledger

| Check | Evidence so far | State |
|---|---|---|
| Virgin first launch: About image remains after close | User reports stable symptom. One exact-pair probe on object `b4916b8` and class `33674fe`: object 0/1 residue trials, class 1/1. Reconfirm on latest class source `1f0a63d`. | Open; add repeatable full-cell test |
| Configured launch (`dn.ini`): blank panels until menu | User screenshots show blank purple area, then panels after opening File. Latest class binary `1f0a63d` produced 0 panel headers before F10+Right and 4 after in one readiness-synchronized 100x30 PTY probe with its own saved `dn.ini`. Intermittent behavior still requires a 100-run series. | Reproduced; compare last object baseline and latest class only |
| Class-vs-`dist` diagnostic | `dist` appears to draw panels before menu, but per-build saved `dn.ini` files differed; this is not controlled causal or acceptance evidence. User confirmed `dist` predates classes. | Excluded from the controlling comparator |
| PTY alternate-screen restoration | Fixed in `133f3d4`; two focused tests cover cell/attribute/cursor restore and repeated transitions. Whole tool suite passed 34 tests. | Verified harness fix; not a DN behavior fix |
| Pascal string collection representations | A class language-menu fault was traced to interpreting a `TStringCollection` ShortString item as AnsiString. A repository search found analogous `PString(Collection.At(...))` in `dnutil.pas`, `paneldlgs.pas`, `printman.pas`, `histories.pas`, `eraser.pas`, `diskinfo.pas`, and `filefind.pas`. | Open; inspect each type and add/test only confirmed fixes |
| Case-insensitive `object` tree audit | Initial inventory search `rg -uuu --text -i -l object . -g '!.git/**'` listed 348 paths, including docs, bootstrap, tests and compiled output. | Newly registered subtask; full contextual audit not started |

The 100-start attempt that sampled before waiting for UI readiness is invalid
and is not counted. A valid comparison must wait for a visible readiness
marker, use equivalent non-virgin configuration, capture every screen cell
(glyph, foreground, background, style), cursor and process result, then replay
the exact same action. Run at least 100 fresh starts for each of the two
controlling source versions for the intermittent configured-launch case.

## Remaining work, in order

1. On the last object-based baseline and latest class build, reproduce the
   virgin About-close residue with full cell snapshots before, during and
   after the dialog; locate/fix it and search all analogous dialog-close and
   restore paths.
2. With the same non-virgin `dn.ini`, work path, PTY dimensions and build
   environment, run 100 configured startups per controlling build. Capture
   full cells before input and after F10+Right; resolve every mismatch.
3. Finish the case-insensitive `object` audit over the complete DN tree,
   inspect every match, remove every Pascal-source match (`.pas`, `.pp`,
   `.inc` and other Pascal compilation units), and verify no Pascal
   object-dialect construction remains anywhere.
4. Continue the full object/class action matrix in
   `CLASS-MIGRATION-ACCEPTANCE-GATE.md`. The overall gate stays open until
   every action, visual cell/attribute, cursor, process result and side effect
   matches.

## Recorded issue and administrative commits

GitHub issue [#6](https://github.com/unxed/dn/issues/6) is the tracker for the
panel-redraw symptoms and their acceptance evidence.

Relevant pushed commits on DN `main`:

- `133f3d4` — repair/test PTY primary-screen restoration.
- `d00a7f3` — record exact object/class acceptance baseline and reported panel
  symptoms.
- `4368e7f`, `1a06986`, `254bc78`, `273648a`, `4e2ceb5`, `cccc6a5`,
  `6fe26fb` — record the discrepancies, reproductions, build-variant scope,
  `dist` provenance, and current test policy. `254bc78` is the rebased
  publication of the local scope-recording change.
- This status-ledger addition and the new `object`-audit gate are the next
  administrative commit; the repository HEAD is authoritative for its SHA.
