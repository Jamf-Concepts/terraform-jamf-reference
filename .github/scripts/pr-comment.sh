#!/usr/bin/env bash
#
# Posts a Markdown file as a comment on a pull request. A later call with the
# same key replaces that comment, so each pull request carries one comment per
# key.
#
# Usage: pr-comment.sh <pull-request-number> <key> <markdown-file>
#
# On another platform, replace the three `gh api` calls with that platform's
# comment API.

set -euo pipefail

pull_request="$1"
key="$2"
markdown_file="$3"

marker="<!-- terraform:$key -->"
run_url="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"

body="$(cat "$markdown_file")

Commit \`${COMMIT_SHA:0:7}\` · [pipeline run]($run_url)
$marker"

comment_id="$(gh api "repos/$GITHUB_REPOSITORY/issues/$pull_request/comments" --paginate \
  --jq ".[] | select(.body | contains(\"$marker\")) | .id" | tail -n 1)"

if [[ -n "$comment_id" ]]; then
  gh api --method PATCH "repos/$GITHUB_REPOSITORY/issues/comments/$comment_id" -f body="$body" --silent
else
  gh api --method POST "repos/$GITHUB_REPOSITORY/issues/$pull_request/comments" -f body="$body" --silent
fi
