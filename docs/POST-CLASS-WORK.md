# After class migration succeeds

Owner order (2026-10-05). **Do not start this work while the object/class
acceptance gate is open.** The gate is documented in
`docs/CLASS-MIGRATION-ACCEPTANCE-GATE.md`: last object-based DN vs last
class-based DN, every scenario of every function, full cell compare
(glyph + foreground + background + attributes/styles + cursor + process
side effects). Any mismatch → fix, do not proceed here.

## 1. English

Translate to English:

- Russian comments in sources
- Documentation (`PLAN.md`, migration docs, README material that is still
  Russian, in-tree guides)
- User-visible strings and hard-coded UI text (resources / LNG / DLG /
  hard-coded `GetString` fallbacks / dialog captions as applicable)

Keep meaning; do not “improve” product copy while translating unless the
owner asks. Prefer mechanical, reviewable batches with before/after checks
so resources stay loadable.

## 2. Refactoring for readability and maintainability

- **Before** any large refactor: write and publish explicit **done criteria**
  (what “readable/maintainable enough” means for this tree: naming, file
  layout, dead code, module boundaries, complexity caps, test expectations).
- Refactor only against those criteria; no open-ended tidy pass.
- Behaviour must stay locked to the already-passed object/class gate (or a
  refreshed same-gate run after each risky batch).

## 3. Platform-dependent code

- Separate OS-specific code from portable DN logic.
- Formalize layout (units / directories / `{$IFDEF}` policy) so Linux, DOS,
  and Windows backends are obvious and swappable.
- Prefer one portable core with thin platform layers over scattered ifdefs.

## 4. Tests to a minimally decent level

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
