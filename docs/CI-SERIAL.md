# CI serial protocol (multi-agent)

GitHub Actions concurrency is limited. Parallel subagents must **not** each
push/`workflow_dispatch` freely.

## Rules for subagents

1. **Do not `git push`.** Commit locally only (or leave a ready patch).
2. **Do not** `gh workflow run` / `gh run rerun` / cancel others' runs.
3. Prefer **local** verification (`tools/dn-linux-*.py`, targeted accept scenarios).
4. When ready for CI, stop and report to the parent: commit SHA(s), files touched,
   which workflow is needed (`dn-accept` / `dn-linux` / none).
5. The **parent agent** owns the push queue: one push → wait for the relevant
   workflow(s) → next push. Workflows use `concurrency: cancel-in-progress` so
   only the latest run per ref consumes runners.

## Parent queue

- Pull/rebase as needed; push at most one batch at a time.
- After push, watch `gh run list` until the triggered workflow completes before
  the next push that would retrigger the same workflow.
- Prefer bundling several finished subagent commits into one push when safe.
