# audit: finding Borland code

The tools here answer one question: **how much of a Pascal source tree is a verbatim copy of Borland's Turbo Vision
sources?** They compare token sequences (comments, layout and letter case are ignored) against a reference corpus made
of the Borland Pascal 7.0 sources.

- `fetch_reference.sh [archive]` downloads BP 7.0 + 7.01 (the URL and the sha256 are in the script and in `PLAN.md`),
  checks the sha256 and extracts the 72 Turbo Vision related source files (including Memory from the Graph Vision 2.3
  samples) to `audit/ref/`. The list of files goes to `audit/ref/list.txt`.
  **`audit/ref/` is never committed:** it is proprietary code (it is git-ignored). Needs `unrar` (`unar` and `7z` cannot
  unpack this solid RAR3 archive), `curl`, `sha256sum`, `unzip`.
- `xclone.py [-k 24] [--min N] --ref audit/ref/list.txt DIR` finds, in every `.pas`/`.pp`/`.inc` file under `DIR`, the
  verbatim chains of `k` (default 24) tokens that also occur somewhere in the reference. One line per file (see the columns below).
- `runs.py FILE audit/ref/list.txt [MIN]` lists the matching chains of at least `MIN` tokens (default 48) of one file:
  the line range in the candidate, the routine it is in, and the place in the Borland file. Use it to find what to rewrite.
  `REN=1 runs.py ...` compares with the identifiers renamed.
- `cclone.py --base A --other B DIR` is the same for C/C++ with two references: the column `only%` is the code that
  matches `B` but is absent from `A` (this is how the origin of magiblot/tvision was checked,
  `research/2026-10-01-magiblot-provenance.md`).
- `reports/<date>/` holds the reports on the sources of DN itself (our own work list): file names and numbers only, no code.
  Reports on third-party projects are not kept here.

## Columns of `xclone.py`

    file   tokens   raw%   ren%   impl%   maxrun   ref

| column | meaning |
|---|---|
| `tokens` | number of tokens of the file (after the comments are dropped) |
| `raw%` | share of the tokens covered by `k`-token chains that occur in the reference with the identifiers as they are (lower-cased): a verbatim copy, whatever the formatting and the comments |
| `ren%` | the same with every identifier replaced by `ID`: a copy with renamed identifiers |
| `impl%` | `raw%` for the implementation section only (an `interface` part must repeat the API, so `impl%` is the number that matters for units) |
| `maxrun` | the longest matching chain, in tokens |
| `ref` | the reference file that contributes most of the matches |

The last line is the total for the directory. For clean code `raw%` is 0-1 % and `ren%` 5-10 % (the background of Pascal
syntax). Suspicious: `raw%` above 10 % or `maxrun` of 48 tokens or more. The thresholds are not calibrated yet (see `PLAN.md`).
In this repository the gate is `raw% <= 10` and `maxrun < 48` for every file of `dn/src` (`bootstrap/README.md`).
The gate is checked by `audit/gate.py` over `dn/src`, `dn/archives` and `dn/compat`. Three small files of `dn/compat/shims/manual/` (`collect.inc`, `dialogs.inc`,
`views.inc`, ~550 tokens) are over it on purpose: they hold the names and the signatures of the Borland API that DN code is written against (the declarations of the string collections that DN code overrides; the names of the standard palettes and their literal tables of numeric indexes: ~25 lines, the only
part that is data and not a name or a signature). The names and signatures of an API are not under copyright; for the tables of indexes the confirmation of the owner is open (`audit/accepted.txt`). They are listed in `audit/accepted.txt` with ceilings (a file that grows over its numbers fails the CI) and the CI prints them in every run, so that the
exception is visible, not hidden. The reasoning and the date are in that file; to take a file out of the list, rewrite it below the gate.

## How to check another Pascal code base (for example Free Vision)

Question: does the code of Free Vision (the Turbo Vision of Free Pascal) partly match Borland's? The same tools answer it for
any Pascal sources. The example below uses the Free Vision package of the Free Pascal repository.

    # 1. the Borland reference (once; needs unrar)
    audit/fetch_reference.sh                       # or: audit/fetch_reference.sh path/to/bp7.rar

    # 2. the code to check: Free Vision is packages/fv/src of the Free Pascal sources
    git clone --depth 1 --filter=blob:none --sparse https://gitlab.com/freepascal.org/fpc/source.git fpc
    git -C fpc sparse-checkout set packages/fv
    #    (a release instead of the latest: add --branch release_3_2_2 to the clone)

    # 3. the share of copied tokens, per file and in total
    python3 audit/xclone.py --min 3 --ref audit/ref/list.txt fpc/packages/fv/src

    # 4. where exactly: the matching chains of 48 tokens or more of one file
    python3 audit/runs.py fpc/packages/fv/src/views.inc audit/ref/list.txt 48

Reading the result:

- Free Vision keeps most of the implementation in `.inc` files that are included into the units (`views.inc` is the body
  of `views.pas`); `xclone.py` reads them too, and the candidate file is the `.inc`.
- `raw%` is the number to look at, `impl%` for the `.pas` files. A file with a large `raw%` and a long `maxrun` repeats whole
  routines; `runs.py` shows which ones (`in [procedure tview.dragview]`) and where they are in the Borland file.
- Some identical text is expected in any compatible library: the declarations of the interface, the constants, the
  command numbers, the palette tables. Look at the routine in `runs.py` before drawing a conclusion.
- This is a measure of **verbatim similarity**, not a legal opinion: it does not say who copied from whom, nor under which
  license the code is. It only shows, with line numbers, which parts are identical to the Borland sources.
- Keep the results out of the repository (reports on third-party projects are not committed), and never commit
  `audit/ref/`, nor the reference text in a log or an issue: print file names, numbers and line ranges only.

To repeat the report for the DN sources: `python3 audit/xclone.py --min 3 --ref audit/ref/list.txt dn/src`.

## What goes to CI

The workflows `audit` and `dn` print only file names, numbers and line numbers (`xclone.py`, `runs.py`); no source lines,
neither ours nor Borland's, go to the logs or to artifacts, and there are no artifacts. If a log is ever suspect,
`delete_workflow_run_logs` (the GitHub API) wipes it; on 2026-10-02 the logs of all the runs of `dn` and `audit` of that time were wiped this way.
