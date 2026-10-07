# Migration status

Updated: 2026-10-07. This file is the handoff point: read it first, then [`PLAN.md`](PLAN.md) (the plan and the owner's checklist) and
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
- **Platform separation** (stage 3): done and enforced; see [`docs/PLATFORM-SEPARATION.md`](docs/PLATFORM-SEPARATION.md). `tools/check-platform.py` (CI: `layout`)
  fails when a platform unit or a target conditional appears outside the backends; `tools/build-matrix.sh` reports PASS, FAIL or UNAVAILABLE for every shipped configuration.
- **Tests** (stage 4): the floor of [`docs/TEST-PLAN.md`](docs/TEST-PLAN.md) is met: every row has a test that runs in CI, or is parked there with a reason. CI at the head: `dn`, `layout`,
  `toolchain`, `dn-linux` (tour, file operations, archives, find, resize, links and permissions, desktop), `dn-windows` (win32 and win64, with and without UTF-8 inside), `dn-accept`
  (object vs class, 181 scenarios, and the UTF-8 build vs the code page build), `nightly`. DOS: `tools/dn-tour.sh`, `tools/dn-dos-input.py` (stock and patched DOSBox-X) by hand.
- **Found by this work and fixed** (shared bugs, the object build had them too): the read-only attribute lost at a copy on Unix, names cut by bytes with UTF-8 inside, the SmartPad line,
  the line drawing of the editor, the archivers on Unix (paths and list files), Find File with a text (class only), the data of a copy written after zeros on Windows. See `dn/TODO-later.md`.

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
The `tv/` pointer of `main` is on `main` of `unxed/tv3` too (the branch `claude/glyphs` was merged by a fast-forward on 2026-10-07: `27f0a8a`); the branch can be deleted.
The object baseline of the gate is pinned in `tools/dn-linux-accept.py` (`OBJECT_DN_SHA`, `OBJECT_TV_SHA`).

## Open items

The list is in `PLAN.md` and in `dn/TODO-later.md`. The ones that decide what to do next:

1. The parked rows of `docs/TEST-PLAN.md` (DN-level clipboard checks, the windows of the desktop, screenshot checks of the DOS pages 850, 852, 1125 and of the DOS help).
2. Intermittent access violations that were seen once (after a clipboard prompt, after a command in the embedded terminal) and could not be reproduced:
   `docs/CLASS-MIGRATION-ACCEPTANCE-GATE.md`.
3. The unstable `menu_5_13` scenario (an asynchronous scan of the host root); a stabilizer is in, the CI has been green with it.
4. The short name of a file record is 12 bytes: with UTF-8 inside the line under the panel shows a short form of a long name (see `dn/TODO-later.md`).
5. The patched DOSBox-X (UTF-8 names, clipboard, the guard against the loop of `DOS_CheckExtDevice`) is local: the PRs to `joncampbell123/dosbox-x` are in `docs/patches/`.
