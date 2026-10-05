# CI serial protocol (multi-agent)

GitHub Actions concurrency is limited. Parallel subagents must **not** each
push or `workflow_dispatch`.

## Rules for subagents

1. **Do not `git push`.** Commit locally only.
2. **Do not** `gh workflow run` / `gh run rerun` / cancel CI runs.
3. **Do not** set any push-unlock environment variable — unlock is parent-only.
4. Prefer **local** verification (`tools/dn-linux-*.py`, targeted accept scenarios).
5. When ready for CI, stop and report: commit SHA(s), files touched, which
   workflow is needed (`dn-accept` / `dn-linux` / none).
6. The **parent agent** owns the push queue: one push → wait for the relevant
   workflow(s) → next push. Workflows use `concurrency: cancel-in-progress`.

## Parent queue

- Push at most one batch at a time; watch `gh run list` before the next push.
- Prefer bundling several finished subagent commits into one push when safe.
