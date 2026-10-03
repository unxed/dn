# spec/: records of the analysis of the original DN OSP 2.14 (frozen)

These files were made at the start (2026-10-01/02) from the **public archive of DN OSP 2.14**, to find out what our own units had to provide when the Borland and Virtual Pascal parts were replaced
(`PLAN.md`, milestones 4 and 5). They use the **names of the archive** (`advance`, `advance2`, `dnapp`, `flpanel`, `microed`, `vpsyslo2`, `vputils`...); nothing here is updated when the sources change, on purpose:
a record of how the decisions were made, not a description of the tree.

| File | What it is |
|---|---|
| `dn-boundary-dnosp214.md` | for every unit of the archive that did not pass the audit gate: the names that the rest of DN takes from it (`tools`: `bootstrap/tools/dn-deps.py`) |
| `api-coverage-2026-10-02.txt` | how much of those names `tv/` had at that date (`bootstrap/tools/api-coverage.py`) |
| `vp-api-*.md` | the names of the units of the runtime of Virtual Pascal (`vpsyslow`, `vpsyslo2`, `vputils`, `lfnvp`, `use16`) that the kept files use (`bootstrap/tools/vp-api.py`) |

**Where things are now (2026-10-04):** the old name -> the new name is in [`dn/renames.map`](../dn/renames.map); what each unit holds is in [`dn/FILES.md`](../dn/FILES.md); the layer that stands for Virtual Pascal is `dn/compat/`.
`vputils` does not exist any more (its functions are `Math`, `SysUtils` and the like of FPC: see the note in `vp-api-vputils.md`); `vpsyslo2` is `compat/vpsysext.pas`; `lfnvp` is `src/lfn.pas`.
To repeat an analysis on the present tree: the tools above take the directory of the tree and the name of the unit.
