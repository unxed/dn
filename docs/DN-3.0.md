# DN 3.0 — nearest product milestone

Fixed by the owner (2026-10-05). This is the **priority frame** for all current
work on `main`: what belongs in 3.0, what is deliberately deferred, and which
exceptions are allowed.

## Goal of 3.0

**Major version 3.0** = a stable port of DOS Navigator onto the new stack:

- DN on Free Pascal;
- our own TV (`tv/`, a translation of magiblot/tvision);
- the class object model (completed class migration with acceptance gate);
- the build/smoke platforms already in the plan (Linux, DOS, and so on);
- behaviour comparable to the last working object baseline where the gate
  requires it; shared object+class bugs are fixed (see Shared bugs in
  `CLASS-MIGRATION-ACCEPTANCE-GATE.md`).

3.0 is **finishing the modernization of the old code**, not “a new file manager”.
Until 3.0 is closed, product development is subordinate to this milestone.

The version string in the tree (`2.20 alpha` and similar) is an intermediate
build label; the number **3.0** is the target product release after the port
stabilizes.

## Principle: minimal interventions

Everything done for 3.0 must be:

1. **Necessary** for build, run, baseline parity, closing class-only
   regressions, CI/gate, or the explicit exceptions below.
2. **Minimal** in scope: fix the cause; do not rewrite subsystems “while we are
   here”.
3. **Separated** from further development: new features, refactoring “for
   beauty”, default UX changes, large architectural rewrites — **not in the
   3.0 stream**, but after the milestone closes (or in explicitly marked
   exceptions).

Practical consequence for agents and contributors:

- First: crashes, object↔class gate, archives/UTF-8/platform smoke, documenting
  regressions — see `CLASS-MIGRATION.md`, `docs/CLASS-MIGRATION-ACCEPTANCE-GATE.md`,
  `docs/ARCHIVE-MATRIX.md`.
- After a green hard gate: `docs/POST-CLASS-WORK.md` (English, readability,
  platform-code separation) — still about **finishing the port**, not a new
  product.
- Ideas to “make it better than OSP” without need for 3.0 → `dn/TODO-later.md`
  (or a separate post-3.0 backlog), not the current cycle.

This continues the spirit of the decision in `PLAN.md` (“first version — the
original with minimal changes”), but at the level of **product release 3.0**:
the goal is a stable new stack, not expanding functionality.

## Exceptions (allowed before/inside 3.0)

The owner explicitly allows work on features needed **personally**, even when
they go beyond a “minimal port”:

| Exception | Meaning |
|---|---|
| **Far UX compatibility mode** | Far behaviour/habits (on agreed points), without breaking DN baseline where the gate requires parity; preferably behind a flag/mode, not a quiet default change. |
| **Advanced keyboard input protocols** | Kitty / win32 input mode / related terminal extensions in `tv/` and wiring into DN. |
| **Advanced clipboard** | OSC 52, far2l clipboard and related paths in `tv/` / DN. |

These exceptions are part of the `tv/` and Linux UX roadmap; do not treat them
as “extra refactoring”. They do **not** open the door to arbitrary new DN
features.

Everything else that is “nice to have” — after 3.0 or in TODO-later, until the
owner extends the exception table here.

## How to read the other documents

| Document | Role relative to 3.0 |
|---|---|
| `PLAN.md` | Historical port milestone plan (TV, DOS, UTF-8, platforms). |
| `CLASS-MIGRATION.md` + acceptance gate | Hard stop inside 3.0: object↔class. |
| `docs/POST-CLASS-WORK.md` | Work right after the gate, still within stabilizing the port. |
| `dn/TODO-later.md` | Deferred beyond the minimal port / 3.0. |
| This file | **Product frame:** what 3.0 is and what is outside it. |

On conflict between “make it nice” and “close 3.0”, closing 3.0 wins (except
the exception table above).
