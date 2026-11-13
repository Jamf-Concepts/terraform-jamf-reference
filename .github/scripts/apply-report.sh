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

# A commit pushed straight to main has no pull request to comment on.
pull_request="$(gh api "repos/$GITHUB_REPOSITORY/commits/$GITHUB_SHA/pulls" --jq '.[0].number // empty')"
if [[ -n "$pull_request" ]]; then
  "$(dirname "$0")/pr-comment.sh" "$pull_request" "apply-$environment" apply.md
fi
