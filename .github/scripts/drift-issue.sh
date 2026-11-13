#!/usr/bin/env bash
#
# Keeps one open issue per environment while the tenant differs from main, and
# closes it once a later check finds no difference.
#
# Usage: drift-issue.sh <environment> <plan-had-changes> <markdown-file> <ref>
#
# <ref> names what the tenant should match: main for dev, the latest release
# tag for prod.

set -euo pipefail

environment="$1"
changes="$2"
markdown_file="$3"
ref="$4"

title="Terraform drift: $environment"
issue="$(gh issue list --state open --search "in:title \"$title\"" --json number --jq '.[0].number // empty')"

if [[ "$changes" != "true" ]]; then
  if [[ -n "$issue" ]]; then
    gh issue close "$issue" --comment "The latest check found no drift."
  fi
  exit 0
fi

run_url="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"
body="The **$environment** tenant no longer matches \`$ref\`. Either someone changed Jamf outside Terraform, or an apply did not finish.

Applying \`$ref\` again makes the changes below. To keep a change someone made in Jamf, copy it into the configuration first.

$(cat "$markdown_file")

[Pipeline run]($run_url)"

if [[ -n "$issue" ]]; then
  gh issue edit "$issue" --body "$body" > /dev/null
else
  gh issue create --title "$title" --body "$body" > /dev/null
fi

# Fail the run so the drift shows as a red check as well as an issue.
echo "::error::Drift detected in $environment"
exit 1
