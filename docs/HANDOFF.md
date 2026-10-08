# Handoff: the state of the work (2026-10-08)

Read `CLAUDE.md` first: the licensing rules are the base of all work and override everything here.

## Repositories

| repo | state |
|---|---|
| tv3 | history from one root commit `652bd98`; head `199026b` (main = the work branch); the far2l extensions on both sides; CI job `generated`; the audit is manual (`tools/audit/run.sh`) |
| tve | head `2871737` (main = the work branch); the audit is manual (`tools/audit/run.sh`) |
| dn | tv3 `199026b` and tve `2871737` pinned; the options for the UX rules that contradict the DN keys (`docs/UX-CONFORMANCE.md`, all off by default); releases by `release.yml`, snapshots by `nightly.yml` |
| sp | fpide pins the same tv3 and tve; the configuration in the platform directories (`tests/accept/test_config.py`) |

## The plan of the owner and where each item is

| # | item | state |
|---|---|---|
| 1 | tve: the editor component, MIT (the rules of `CLAUDE.md`) | in dn and fpide; the history passes the audit; open: the remaining editor features of `tve/README.md` |
| 2 | what dn and fpide both use moves to tv3 | `tv3/SHARED-CODE.md`, `tv3/docs/DEDUP-AUDIT.md`; new MIT units `TvFormat`, `TvCrc`, `TvCStr`, `TvPath`, `TvAppDir` replace the duplicates; open: the clock (#19), the ASCII table (#18) |
| 3 | UTF-8 in DOS builds (dosbox-x PR 6632) through tv3 | done; the tvision PR (magiblot/tvision#241, branch `dos-utf8-names` of the fork) waits for the owner |
| 4 | fpide: the ASCII splash removed | done |
| 5 | the vtui UX guidelines in tv3, dn, fpide, tve | tables in `docs/UX-CONFORMANCE.md` (dn) and tv3; the rows marked gap are open |
| 6 | fpide: other languages, Go first | Go done (template, gofmt, Delve); Python, Rust, C were never asked for |
| 7 | sp as "Better Pascal" (safe / ext / fpide, one unit that gives everything) | `sp/PLAN.md`; the rename of the repository to bp is the last step |
| 8 | no DOS/Windows path remnants on other systems ("C:" on Linux) | tv3 `TvPath`; tve and fpide use it; dn open (DnPath over TvPath); ratchet of `tools/check-paths.py` |
| 9 | English in all code, texts and docs | done (`tools/text-policy.py` in CI) |
| 10 | dn leftovers (PLAN.md, MIGRATION-STATUS) | open |
| 11 | word wrap (reference: f4), xlat (reference: far2l, behaviour only) | done |
| 12 | the four DN editor files `editcore`, `editfile`, `editinfo`, `editor` hold code of the old editor of DN | they are DN code under the RIT licence with its notice; they stay as they are (owner, 2026-10-08) |

## Legal state (what the audit and the rewrite established)

- tv3: the audit (`tools/audit/run.sh`) of the tree and of the history prints `AUDIT PASS`; the history starts at one root commit.
- tve: the audit (`tools/audit/run.sh`) of every version of every file of the history prints `AUDIT PASS`.
- dn: the history has no statements of origin and no copy of the old tv3; the RIT code keeps its notices.
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

## How to

- Audit: `tools/audit/run.sh` in tv3 or tve (fetches the corpora once into `~/.cache/tv-audit`; prints `AUDIT PASS` or
  `AUDIT FAIL`).
- Pin tv3/tve in dn or sp: rule 4 above.
- Configuration directories: tv3 `TvAppDir` (XDG on Linux and BSD, `~/Library/Application Support` on macOS,
  `%APPDATA%` and `%LOCALAPPDATA%` on Windows, the program directory on DOS).
- dn on a new tv3: `tools/build.sh linux64`, then `tools/dn-linux-*.py out/linux64` (the CI list is in
  `.github/workflows/dn-linux.yml`).
