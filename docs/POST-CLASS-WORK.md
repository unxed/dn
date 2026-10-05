# After class migration succeeds

Still inside **DN 3.0** (stabilize the port). Not a green light for arbitrary
new product features — see [`DN-3.0.md`](DN-3.0.md).

Owner order (2026-10-06). English translation and stage-2 refactoring are
complete; all A–D criteria in `docs/REFACTORING-CRITERIA.md` are checked or
explicitly parked. Object/class parity passed **177/177** on DN `06259f5` +
TV3 `a06dd31` (GitHub runs `37383488177`, `37383488040`, `37383488261`). The
all-tree class gate and baseline-reproducible bootstrap now pass on DN
`8f3057f` (`dn` run `37386669632`, `layout` run `37386669509`). Stage 3 is
unblocked; its initial code-boundary inventory and acceptance criteria are in
[`PLATFORM-SEPARATION.md`](PLATFORM-SEPARATION.md). Re-open / re-run parity
after a risky batch; do not skip or reorder stages below.

When object and class **both** show the same bug, fix it anyway — see
**Shared bugs** in `docs/CLASS-MIGRATION-ACCEPTANCE-GATE.md` (do not treat
pre-migration wrong behaviour as acceptable parity).

## 1. English — complete

Translate to English:

- Russian comments in sources
- Documentation (`PLAN.md`, migration docs, README material that is still
  Russian, in-tree guides)
- User-visible strings and hard-coded UI text (resources / LNG / DLG /
  hard-coded `GetString` fallbacks / dialog captions as applicable)

Keep meaning; do not “improve” product copy while translating unless the
owner asks. Prefer mechanical, reviewable batches with before/after checks
so resources stay loadable.

## 2. Refactoring for readability and maintainability — complete

- **Before** any large refactor: write and publish explicit **done criteria**
  (what “readable/maintainable enough” means for this tree: naming, file
  layout, dead code, module boundaries, complexity caps, test expectations).
- Criteria (on `main`): [`REFACTORING-CRITERIA.md`](REFACTORING-CRITERIA.md).
- Refactor only against those criteria; no open-ended tidy pass.
- Behaviour must stay locked to the already-passed object/class gate (or a
  refreshed same-gate run after each risky batch).

## 3. Platform-dependent code — next

- Separate OS-specific code from portable DN logic.
- Formalize layout (units / directories / `{$IFDEF}` policy) so Linux, DOS,
  and Windows backends are obvious and swappable.
- Prefer one portable core with thin platform layers over scattered ifdefs.
- Start from the inventory and completion criteria in
  [`PLATFORM-SEPARATION.md`](PLATFORM-SEPARATION.md); land one backend family
  at a time and preserve the object/class parity gate.

## 4. Tests to a minimally decent level — pending stage 3

Expand coverage to a floor the owner can trust, including:

- Shared / portable behaviour
- Linux-specific paths (PTY, paths, archivers, UTF-8 terminal)
- DOS-specific paths (as far as CI/harness allows)
- Windows-specific paths (ConPTY / win smoke already seeded)

“Minimally decent” means regressions that already bit the class migration
(startup redraw, desktop restore, stream ABI, virtual/`override`, archives,
editor/user-screen) stay covered, plus platform smoke for each shipped
target.

## Order lock

```
class migration bitwise gate PASS
        ↓
(1) English
        ↓
(2) refactoring (criteria first)
        ↓
(3) platform separation
        ↓
(4) broader tests
```

Parallelism inside a stage is fine; skipping the gate or reordering stages
is not.
