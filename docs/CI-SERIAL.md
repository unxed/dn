# CI serial protocol (multi-agent)

GitHub Actions concurrency is limited / congested. Parallel subagents must
**not** each push or `workflow_dispatch`.

## Prefer local verification

- **Local is primary.** Run `tools/dn-linux-*.py` and
  `tools/dn-linux-accept.py` on this machine to prove fixes and gate progress.
- **Push is optional.** Do not push solely to get CI green. Commit locally;
  report SHAs to the parent. The parent decides if/when to publish.
- CI (`dn-accept` / `dn-linux`) is optional corroboration after local proof,
  not the acceptance authority while runners are congested.

## Rules for subagents

1. **Do not `git push`.** Commit locally only.
2. **Do not** `gh workflow run` / `gh run rerun` / cancel CI runs.
3. **Do not** set any push-unlock environment variable — unlock is parent-only.
4. Prefer **local** verification (`tools/dn-linux-*.py`, targeted accept scenarios).
5. When ready for optional CI, stop and report: commit SHA(s), files touched,
   which workflow is needed (`dn-accept` / `dn-linux` / none).
6. The **parent agent** owns the push queue: one push → wait for the relevant
   workflow(s) → next push. Workflows use `concurrency: cancel-in-progress`.

## Parent queue

- Push at most one batch at a time; watch `gh run list` before the next push.
- Prefer bundling several finished subagent commits into one push when safe.
- Skip or defer push when local verification already covers the change and
  CI is congested.
