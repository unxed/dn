# Handoff: the state of the work (2026-10-09)

Read `CLAUDE.md` first: the licensing rules are the base of all work and override everything here.

## Repositories

| repo | state |
|---|---|
| tv3 | head `9f153cb` (main, pinned by dn and bp): the API of magiblot/tvision (classes, names, streams, platform classes; the differences in `docs/API-NAMES.md`); TNSCollection/TNSSortedCollection as the non-stream bases; a stream error raises EStreamableError; builds without warnings; the far2l extensions on both sides; CI job `generated`; the audit is manual (`tools/audit/run.sh`) and prints `AUDIT PASS` |
| tve | head `dac0a82` (main, pinned by dn and bp): builds without warnings; persistent blocks end the selection when Shift is released; the audit prints `AUDIT PASS` |
| dn | builds without warnings for Linux, DOS (both builds) and Windows; the settings of another version or damaged are skipped (heads with a version, guarded loads; `tools/dn-linux-badconfig.py`); acceptance: the UTF-8 build against the code-page build (`dn-accept.yml`, `docs/CLASS-MIGRATION-ACCEPTANCE-GATE.md`); releases by `release.yml`, snapshots by `nightly.yml` (green commits of main only) |
| bp (was sp) | main `40260cd`: fpide builds without warnings; the build fetches tv/ and tve/; Alt with a letter of another layout is the shortcut of the Latin key (editor and menus); the links point to `unxed/bp` |
| tv (old) | history rewritten: main has a README that points to tv3 |

The work branches `claude/nifty-rubin-7v0d9z` of all repositories are merged into main; the owner deletes them (the proxy
of the agents cannot delete refs), and the two extra branches of unxed/tv.

## The plan of the owner and where each item is

| # | item | state |
|---|---|---|
| 1 | tve: the editor component, MIT (the rules of `CLAUDE.md`) | done: in dn and fpide; the features of `tve/README.md` are closed; word wrap |
| 2 | what dn and fpide both use moves to tv3 | done: `TvFormat`, `TvCrc`, `TvCStr`, `TvPath`, `TvAppDir`, `TvAscii`, `TvGadgets`, `TvActions` |
| 3 | UTF-8 in DOS builds (dosbox-x PR 6632) through tv3 | done; magiblot/tvision#241 is out of the plan (the owner follows it) |
| 4 | fpide: the ASCII splash removed | done |
| 5 | the vtui UX guidelines in tv3, dn, fpide, tve | done: `docs/UX-CONFORMANCE.md`; the rules that contradict the DN keys are options, off by default |
| 6 | fpide: other languages, Go first | Go done (build, vet, test, gofmt, Delve) |
| 7 | sp as "Better Pascal" (safe / ext / fpide, one unit) | done (`PLAN.md` of bp); the repository is `unxed/bp` |
| 8 | no DOS/Windows path remnants on other systems | done: tv3 `TvPath`; dn, tve, fpide over it; `tools/check-paths.py` |
| 9 | English in all code, texts and docs | done (`tools/text-policy.py` in CI) |
| 10 | dn leftovers | done; what needs the owner is in `dn/TODO-later.md` |
| 11 | word wrap, xlat | done |
| 12 | the four DN editor files `editcore`, `editfile`, `editinfo`, `editor` | DN code under the RIT licence with its notice; they stay (owner, 2026-10-08) |
| 13 | tv3 API = magiblot/tvision (rule 13 below) | done in tv3, tve, dn, fpide |
| 14 | the hot letters of the dialogs: a free letter of the label for every item, no repeats | done in the three languages; `tools/tests/test_hotletters.py` and the dialog sweep in CI |
| 15 | every pty test and click-through side by side, locally and in CI | done in all four repositories (`tools/ci-par.sh`, sweeps with `-j 16`) |
| 16 | a ticket for magiblot/tvision on the bug of TStatusLine (fixed in tv3) | the text was given to the owner |

## Legal state (what the audit and the rewrite established)

- tv3: the audit (`tools/audit/run.sh`) of the tree and of the history prints `AUDIT PASS`; the history starts at one root commit.
- tve: the audit (`tools/audit/run.sh`) of every version of every file of the history prints `AUDIT PASS`.
- dn: the history has no statements of origin and no copy of the old tv3; the RIT code keeps its notices; its own gate
  (`audit/xclone.py`, `audit/gate.py`) against Borland Turbo Vision passes (CI `dn.yml`).
- Old SHAs of the rewritten histories may still be reachable on GitHub by their hash: only GitHub support can purge
  them (a request by the owner).

## Why the plan stood still (root causes) and the working rules that follow from them

1. Waiting in the foreground for slow builds and tests. Rule: a slow job runs in the background or in an agent; the
   lead works on other items and collects the results when they come.
2. Too many heavy jobs on 4 CPUs (up to 5 agents with builds at once). Rule: at most 3 heavy agents.
3. Agents in one working tree collided. Rule: one git worktree per agent, disjoint files, the lead merges.
4. Pins of submodules committed as blobs (symlinks). Rule: `git update-index --cacheinfo 160000,<sha>,<path>` and a
   plain `git commit` (never `git commit -- <path>`).
5. `pkill -f PATTERN` killed the shell that ran it (the pattern is in its own command line). Rule: kill by PID, or use
   a bracket pattern (`pgrep -f 'run-te[s]ts'`).
6. Unrequested features and labels (provenance labels in headers, Python/Rust/C in fpide). Rule: only what the owner
   asked; no labels; no edits of legal texts without a decision of the owner.
7. Claims without checks. Rule: report what was verified and how; say what was not.
8. CI after every push, cancelled by the next one. Rule: batch about ten changes, then read CI and fix in one batch.
9. The audit was slow (a minute per run). Fixed: `build/audit-cache` keeps the indexes (seconds per run).
10. The pty tests and the click-throughs (menu sweeps, hotkeys, acceptance) ran one after another, locally and in CI, with `-j 2`
    or `-j 4`, while the machine was idle (load 0.1 of 4 CPUs): they wait for the program, not for the CPU. Rule: run them side by
    side, everywhere and always: locally all of them at once (each with its own HOME, `xargs -P` or `&` + `wait`), the sweeps with
    `-j 8` or more; in CI a matrix of groups and the tests of a group side by side (`tools/ci-par.sh` in dn). Check `uptime` before
    choosing a lower number; a test that cannot run beside others is a bug of the test (a fixed path, a fixed tmux session name).
11. "Later, after the other agent" for a task the owner asked for now. Rule: a task the owner asks for starts at once, in its own
    worktree; a possible conflict with another agent is settled at the merge, not by waiting.
12. Priority (owner, 2026-10-08): making every test that can run in parallel do so, locally and in CI, comes first; work that
    would interfere with it (edits of the workflows or of the test runners) waits until it is merged.
13. The API (owner, 2026-10-09): tv3 is as magiblot/tvision (its only source): the same classes (Pascal classes), ancestors,
    methods, constants, types and functions, in Pascal spelling (`TView::handleEvent` -> `TView.HandleEvent`). A difference is
    made only where the magiblot form is impossible in Pascal (e.g. a C++ constructor is `Create`, the destructor `Destroy`;
    C++ overloads by const), and each one is listed with the reason in `docs/API-NAMES.md` of tv3. Borland Turbo Vision and
    Free Vision are not a reference. A form that only the programs on tv3 use (e.g. the slot form of `FormatStr`) lives in
    their own shims. The units and items that magiblot does not have at all (TvPath, TvAppDir, TvCrc, TvCStr, TvAscii, TvGadgets,
    TvActions, the far2l extensions, the backends) stay in tv3 as new APIs (owner, 2026-10-09).
14. A rule of the owner is applied as it is written; nobody who applies it makes an exception. A case where the rule seems
    impossible to follow goes to the owner; an agent stops and reports it.
15. No match with any corpus (owner, 2026-10-09, final): a faithful translation of magiblot that matches Borland Turbo Vision (or any
    corpus) is written again with other code, keeping the behaviour of magiblot, until the audit finds nothing. This is not asked
    again; it is the rule.

## How to

- Audit: `tools/audit/run.sh` in tv3 or tve (fetches the corpora once into `~/.cache/tv-audit`; prints `AUDIT PASS` or
  `AUDIT FAIL`).
- Pin tv3/tve in dn or sp: rule 4 above.
- Configuration directories: tv3 `TvAppDir` (XDG on Linux and BSD, `~/Library/Application Support` on macOS,
  `%APPDATA%` and `%LOCALAPPDATA%` on Windows, the program directory on DOS).
- dn on a new tv3: `tools/build.sh linux64`, then `tools/dn-linux-*.py out/linux64` (the CI list is in
  `.github/workflows/dn-linux.yml`).
