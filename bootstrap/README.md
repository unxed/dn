# bootstrap/: how the `dn/src` tree was obtained

**This is a record of where the first commit with working DN code came from, and a way to repeat it.** After that commit
`dn/src` changes with ordinary commits and PRs; `bootstrap/` is not needed in day-to-day work and is not edited (except when
something extra landed in the first commit: see below). You can build DN without running `bootstrap/` at all: `tools/build.sh`.

Why this exists: DN code comes only from public sources and without Borland code. The path is checkable:
anyone can download the same archive, run `bootstrap/run.sh`, and get a tree byte-identical to the committed
`dn/src` at the first-commit moment (the commit in `bootstrap/BASELINE`).

## Short path

    bootstrap/run.sh [DIR]            # default build/bootstrap: result DIR/src and DIR/data
    diff -r build/bootstrap/src dn/src    # empty (on the baseline commit from bootstrap/BASELINE)

Needs: `sh`, `git` (history containing the pinned baseline commit), `python3`, `unrar` (`.rar` archive), `curl`, `patch`.
Offline: `DN_LOCAL_TREE=<unpacked archive>`.

## Where the sources come from

| What | Value |
|---|---|
| Source | DN OSP 2.14 (Dos Navigator Open Source, RIT Research Labs and contributors) |
| Address | `bootstrap/upstream.env` (archive `dn2s214.rar` from `dnosp.com`, via Wayback Machine) |
| Check | sha256 from `upstream.env`; `fetch.sh` downloads and verifies (stops on mismatch) |
| Fallback | DN 1.51 (`dn151src.zip` from `download.ritlabs.com`), same entry in `upstream.env`; not used in the first commit |

The archive is not stored in the repository. Only what is listed below is taken from it.

## Steps (`run.sh`, in order)

1. **Download and unpack** (`fetch.sh`, sha256). Sources are in the archive directory that has the most `.pas` files.
2. **Carve DN classes out of files that are excluded as wholes** (`carve.list`, `tools/dn-carve.py`): `DIALOGS.PAS` and
   others hold Borland TV classes next to DN’s own (`TComboBox`, `TStringList`, `T_BWSelector`...). DN’s own classes
   are carved into new units (`DNDlgs`, `DNStrL`, `DNColor`); the rest is excluded. DN palettes are carved the same way (`DNPalet`: program colour tables — DN data).
3. **System units** (`tree.env`: `BOOT_LIB_DIR=LIB.D32`): DN OSP keeps system-specific units in `LIB.D32`
   (DOS, 32-bit), `LIB.OLF`, `LIB.WLF`. `LIB.D32` is taken; the other directories are dropped. `VPSYSD32.PAS` is the
   Virtual Pascal runtime, not DN code: our `vpsyslow.pas` replaces it.
4. **Exclusions** (`exclude.list`, 55 entries, each with a reason): (a) files whose code comes from Borland (Turbo Vision
   units: replaced by `tv/`); (b) the Virtual Pascal environment; (c) 19 DN OSP contributor files (DN/2 plugin interface,
   OS/2 PM adapters) that no build of ours needs (unreachable by `uses`: `tools/dn-reach.py`) and whose headers
   have no license. List (a) is built by `tools/gen-exclude.py` from the audit report (`audit/`): a file is excluded if
   `raw% > 10` or the longest Borland match chain is at least 48 tokens.
5. **Patches** (`patches/series`): currently empty — everything is done by the edits below.
6. **Rewritten spots** (`rewrite/*.rw`, `tools/dn-rewrite.py`): places inside remaining files where the audit found
   chains matching Borland (for example `TParamText` in `DNDlgs`). Replaced with our text; only our text stays in git.
   Each `.rw` names the file, region bounds, and sha1 of the replaced text (if the archive differs — stop).
7. **Mechanical edits** (`edits/`: `*.sh`, then `*.sed`, then `*.py`; within each — name order; each states a
   reason): conditional compilation via `tree.env` (`tools/ifdef-strip.py`: OS/2 and Win32 branches removed; `LINUX` kept for
   the compiler), move to the new TV (names, signatures, palettes), VP vs FPC differences (`Word` is 32-bit in VP, argument
   evaluation order, 32-bit assembler → Pascal), paths (`SysOsPath`), `FormatStr` parameter slots (`PtrInt`).
8. **Our new files**: replacements for excluded units (`dnapp`, `drivers`, `memory`, `messages`, `dnstddlg`, `asciitab`,
   `listmakr`...), system layer (`vpsyslow`, `vputils`, `use16`), adapters to `tv/`. The exact inputs are read with `git archive`
   from `bootstrap/new` in the commit named by `bootstrap/BASELINE`; they are not duplicated in the current working tree.
   This preserves byte-identical baseline reconstruction without keeping old object-dialect Pascal sources in the class-migrated
   checkout. The repository history must contain the pinned commit (CI fetches full history). These are our files (MIT).
9. **Lowercase names** (FPC on a case-sensitive filesystem looks for `unit.pas`), **unit aliases** from `vpc.cfg`
   (`-ALFN=LFNVP`).
10. **What goes into the repository**: `*.pas`, `*.inc`, `rcpvpd.ini`, and the `RESOURCE` directory (dialog, string,
    and help texts in three languages) → `dn/src`; DN data (`EXE.D32`: code-page tables, palettes, defaults) →
    `dn/data`. Archive binaries (`DN.COM`, icons), VP build scripts, and old unit copies are not taken.

(Since 2026-10-03 the `dn/` directories are laid out by role: `dn/src-linux/` became `dn/compat/linux/`, `dn/shims/` — `dn/compat/shims/`, VP-layer units and archive formats moved to `dn/compat/` and `dn/archives/`; bootstrap
still reproduces the first-commit `dn/src` as it was, not the current layout.) Added after bootstrap without editing its scripts: `dn/src-linux/country_.pas` (Linux unit replacement: CP866 uppercase table,
defaults), `dn/shims/` (description of what DN takes from `tv/`: shim units generated by
`tools/gen-shim.py`).

## Audit gate (legal check)

Borland code is never committed. Before the first commit (and in CI on every PR, workflow `audit`) `audit/xclone.py` runs on `dn/src`:
verbatim 24-token chains are compared to the Borland reference (BP 7.0, downloaded by URL, sha256-checked,
not stored in the repo: `audit/fetch_reference.sh`). **Threshold: `raw% <= 10` and `maxrun < 48` for every file.**
On the baseline commit: 176 files, `raw` 0.4 %, no exceedances. What was searched and found: reports in `audit/reports/`.

## Licenses

Archive files keep RIT Labs headers (must not be removed or changed: `dn/LICENSE.md`). What is what — `dn/PROVENANCE.md`
(created by `bootstrap/tools/dn-manifest.py`). Our files are MIT (`LICENSE`). DN OSP contributor files with no license
in the header that were part of the same public release (manifest classes “Contributors” and “Upstream without a notice”)
are taken as part of the release; that is something to ask the project owner about (`PLAN.md`).

## If something extra landed in the first commit

Edit `bootstrap/` (exclusion, `.rw`, or edit), rebuild the tree with `bootstrap/run.sh`, carry the change into `dn/src`
with an ordinary commit, and append to `bootstrap/BASELINE` the commit where `dn/src` again matches `run.sh` output. Reproducibility check in CI: workflow `dn`,
job `bootstrap` (`bootstrap/run.sh`, compare to `dn/src`).

## Directory layout

| Path | What |
|---|---|
| `run.sh`, `fetch.sh` | run, download |
| `upstream.env`, `tree.env` | archive URL and sha256; conditional-compilation policy |
| `exclude.list`, `carve.list` | what we skip; what we carve from excluded files |
| `patches/`, `rewrite/`, `edits/` | patches, rewritten spots, mechanical edits |
| `BASELINE` | commit with the historical bootstrap inputs and the exact `dn/src` / `dn/data` output |
| `tools/` | tools: carve, rewrite, `ifdef-strip`, reachability, provenance (`dn-provenance`, `dn-manifest`), Virtual Pascal API notes (`vp-api`, `api-*`) |
