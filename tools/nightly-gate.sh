#!/usr/bin/env bash
# Whether the commit $SHA is published as the release "nightly" (.github/workflows/nightly.yml).
# Writes publish=true|false and sha=$SHA to $GITHUB_OUTPUT (stdout when it is not set).
# Input: SHA; REQUIRED (the files of the test workflows, e.g. "dn-linux.yml dn.yml"); FORCE=true skips the checks;
# GITHUB_REPOSITORY (owner/name); gh with a token that may read the actions and the contents.
# Published when: the commit is on main, it is newer than the commit of the published release, and every required workflow
# that the push of the commit started has completed with success (a required workflow that the push did not start, because
# of its paths, does not count; at least one must have run).
set -euo pipefail
: "${SHA:?}" "${GITHUB_REPOSITORY:?}"
repo=$GITHUB_REPOSITORY
output=${GITHUB_OUTPUT:-/dev/stdout}
echo "sha=$SHA" >> "$output"

skip() {
  echo "not published: $*"
  echo "publish=false" >> "$output"
  exit 0
}

if [ "${FORCE:-false}" = true ]; then
  echo "published without the checks (force)"
  echo "publish=true" >> "$output"
  exit 0
fi

# gh prints the body of an error (404) on stdout: a failed call gives an empty value
st=$(gh api "repos/$repo/compare/main...$SHA" --jq .status 2>/dev/null) || st="not found"
case $st in
  identical|behind) ;;
  *) skip "$SHA is not a commit of main ($st)" ;;
esac

pub=$(gh api "repos/$repo/commits/nightly" --jq .sha 2>/dev/null) || pub=""
if [ -n "$pub" ]; then
  st=$(gh api "repos/$repo/compare/$pub...$SHA" --jq .status 2>/dev/null) || st="unknown"   # e.g. the published commit is gone
  case $st in
    ahead|diverged|unknown) ;;
    *) skip "the published commit $pub is not older than $SHA ($st)" ;;
  esac
fi

runs=$(gh api --paginate "repos/$repo/actions/runs?head_sha=$SHA&event=push&per_page=100" \
  --jq '.workflow_runs[] | [.path, .created_at, .status, (.conclusion // "-"), .html_url] | @tsv')
seen=0
for wf in ${REQUIRED:?}; do
  # the latest run of the workflow for the push of the commit
  run=$(printf '%s\n' "$runs" | awk -F '\t' -v p=".github/workflows/$wf" '$1 == p' | sort -t "$(printf '\t')" -k2,2 | tail -n 1)
  if [ -z "$run" ]; then
    echo "$wf: not started by this commit"
    continue
  fi
  seen=1
  IFS=$'\t' read -r _ _ status conclusion url <<< "$run"
  echo "$wf: $status $conclusion $url"
  [ "$status" = completed ] || skip "$wf is $status (its completion starts the gate again)"
  case $conclusion in
    success|skipped|neutral) ;;
    *) skip "$wf: $conclusion" ;;
  esac
done
[ "$seen" = 1 ] || skip "no test workflow ran for $SHA"
echo "publish=true" >> "$output"
