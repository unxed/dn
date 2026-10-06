# Migration status

Updated: 2026-10-06. This file is the handoff point: read it first, then [`PLAN.md`](PLAN.md) (the plan and the owner's checklist) and
[`docs/POST-CLASS-WORK.md`](docs/POST-CLASS-WORK.md) (the order of the stages).

## Where the port stands

- **Classes:** the migration from Pascal `object` to `class` is complete for `dn/` and `tv/` (the class gate `tools/class-gate.sh` is strict in CI). The
  object-vs-class acceptance gate (`dn-accept`, 178 scenarios, cell by cell) is closed; the details and the evidence are in
  [`docs/CLASS-MIGRATION-ACCEPTANCE-GATE.md`](docs/CLASS-MIGRATION-ACCEPTANCE-GATE.md). Shared bugs (the object and the class build wrong in the same way) are fixed, not kept.
- **UTF-8:** all sources, resources and documents are UTF-8 ([`docs/TEXT-POLICY.md`](docs/TEXT-POLICY.md), checked by `tools/tests/test_text_policy.py`,
  `tools/audit-encoding.py` and `tv/tools/text-policy.py`). The conversion of the sources from CP866 lost nothing (audited against the revision before it).
  Cells of the screen hold UTF-8; the DOS backend lands a cell on the code page of the machine. The glyphs (frames, shades, blocks, arrows) are named
  Unicode code points of `tv/src/tvglyphs.pas`, never byte constants.
- **English:** comments, documents, hard-coded strings and the English resources are English (Cyrillic only where the policy lists it).
- **Refactoring** (stage 2): done against [`docs/REFACTORING-CRITERIA.md`](docs/REFACTORING-CRITERIA.md).
- **Platform separation** (stage 3): in progress and enforced; see [`docs/PLATFORM-SEPARATION.md`](docs/PLATFORM-SEPARATION.md). `tools/check-platform.py` (CI: `layout`)
  fails when a platform unit or a target conditional appears outside the backends.
- **Tests** (stage 4): the floor is defined in [`docs/TEST-PLAN.md`](docs/TEST-PLAN.md); the gaps listed there are the work.

## Build and check

    tools/build.sh linux64                  # DN, the resources and the help: out/linux64
    tools/dn-test.sh                        # the unit tests of dn/tests
    tools/tv-test.sh                        # the unit tests of tv/tests
    python3 -B -m unittest discover -s tools/tests -p 'test_*.py'
    tools/accept-local.sh all               # the object vs class gate on this machine (builds both, runs every scenario)
    DN_PREFIX=/path/to/go32v2 tools/build.sh dos      # the DOS build (cross compiler: tools/build-fpc-go32v2.sh PREFIX)

The other scripts and what each one checks: [`tools/README.md`](tools/README.md).

## Branches and the submodule

Work goes to `main`. `tv/` is the submodule `unxed/tv3`; a change to it is made and tested there (a branch of that repository), then the pointer is moved here.
The object baseline of the gate is pinned in `tools/dn-linux-accept.py` (`OBJECT_DN_SHA`, `OBJECT_TV_SHA`).

## Open items

The list is in `PLAN.md` ("Owner requirements checklist" and "Next items in order") and in `dn/TODO-later.md`. The ones that decide what to do next:

1. DOS: the UTF-8 names with the patched DOSBox-X (`DN_DOS_PATCHED=1 tools/dn-dos-input.py`) and the case and sort tables for the code page 1125 (Ukrainian).
2. The rest of stage 3 (see the last steps in `docs/PLATFORM-SEPARATION.md`) and then stage 4 tests.
3. Intermittent access violations that were seen once (after a clipboard prompt, after a command in the embedded terminal) and could not be reproduced:
   `docs/CLASS-MIGRATION-ACCEPTANCE-GATE.md`.
4. The unstable `menu_5_13` scenario (an asynchronous scan of the host root); a stabilizer is in, not proven.
