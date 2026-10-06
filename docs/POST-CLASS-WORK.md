# After class migration succeeds

Still inside **DN 3.0** (stabilize the port). Not a green light for arbitrary
new product features — see [`DN-3.0.md`](DN-3.0.md).

Owner order (2026-10-06). English translation and stage-2 refactoring are
complete; all A–D criteria in `docs/REFACTORING-CRITERIA.md` are checked or
explicitly parked. The class/object parity gate was repeated after the
platform work: **177/177 pass, 0 fail** on DN
`e551fee53eddf009720f6d79037a1bc06bd9f570` (`dn-accept` run `37395436777`;
Linux `37395436982`; Windows `37395436934`; DOS `37395436869`; `dn`
`37395436984`; layout `37395436849`). Stage 3 has begun; disk queries and
process launch/restart use `osdep` facades. A dedicated restart runtime test is
still open. The remaining inventory, criteria, and next `DNRun` extraction are in
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
