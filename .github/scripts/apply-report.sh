#!/usr/bin/env bash
#
# Records the result of an apply in the run summary and on the pull request
# that introduced the commit, so the pull request shows where its change went.
#
# Usage: apply-report.sh <environment> <plan-had-changes> <apply-outcome>

set -euo pipefail

environment="$1"
changes="$2"
outcome="$3"

if [[ "$changes" != "true" ]]; then
  result="➖ Nothing to apply to **$environment**. The tenant already matched this commit."
elif [[ "$outcome" == "success" ]]; then
  result="✅ Applied to **$environment**."
else
  result="❌ The apply to **$environment** failed. Changes that succeeded before the failure stay in place.

\`\`\`
$(sed 's/\x1b\[[0-9;]*m//g' apply-errors.txt 2>/dev/null || true)
\`\`\`"
fi

{
  echo "### Terraform apply: $environment"
  echo "$result"
} > apply.md

cat apply.md >> "$GITHUB_STEP_SUMMARY"

# Comment on each pull request this apply delivered. A merge to main delivers
# the pull request behind its commit. A release delivers every pull request
# merged since the previous release.
commits="$COMMIT_SHA"
if [[ -n "${RELEASE_NAME:-}" ]]; then
  echo "Release \`$RELEASE_NAME\`." >> apply.md
  previous="$(gh release view --repo "$GITHUB_REPOSITORY" --json tagName --jq .tagName 2> /dev/null || true)"
  if [[ -n "$previous" ]]; then
    commits="$(gh api "repos/$GITHUB_REPOSITORY/compare/$previous...$COMMIT_SHA" --jq '.commits[].sha')"
  fi
fi

for commit in $commits; do
  gh api "repos/$GITHUB_REPOSITORY/commits/$commit/pulls" --jq '.[].number'
done | sort -un | while read -r pull_request; do
  "$(dirname "$0")/pr-comment.sh" "$pull_request" "apply-$environment" apply.md
done
