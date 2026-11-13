#!/usr/bin/env bash
#
# Renders a saved Terraform plan as Markdown: a headline, a table of every
# resource the plan touches, and the full diff in a collapsed block.
#
# Usage: plan-summary.sh <plan-file> <title>
#
# The script needs terraform and jq and nothing from GitHub, so it runs
# unchanged on any CI system. Run it from the directory you ran
# `terraform plan -out=<plan-file>` in.

set -euo pipefail

plan_file="$1"
title="$2"

# Comment bodies on most platforms stop at 65,536 characters.
max_diff_characters=55000

plan_json="$(terraform show -json "$plan_file")"

# One row per resource the plan touches: the action, then the address.
changes="$(jq -r '
  .resource_changes // []
  | map(
      (.change.actions | join(",")) as $actions
      | {
          address,
          from: (.previous_address // null),
          importing: (.change.importing != null),
          action: (
            if   $actions == "create"                                    then "create"
            elif $actions == "update"                                    then "update"
            elif $actions == "delete"                                    then "destroy"
            elif $actions == "delete,create" or $actions == "create,delete" then "replace"
            elif $actions == "forget"                                    then "forget"
            else "none" end
          )
        }
    )
  | map(select(.action != "none" or .importing or .from != null))
  | .[]
  | [
      ( [ (if .importing then "import" else empty end),
          (if .from != null then "move" else empty end),
          (if .action != "none" then .action else empty end)
        ] | join(" + ") ),
      ( if .from != null then "\(.from) → \(.address)" else .address end )
    ]
  | @tsv
' <<<"$plan_json")"

count() {
  # Counts the rows whose action column contains the given word.
  awk -F'\t' -v word="$1" '$1 ~ word { n++ } END { print n + 0 }' <<<"$changes"
}

icon() {
  case "$1" in
    *destroy*) echo "🔴" ;;
    *replace*) echo "🟠" ;;
    *update*)  echo "🟡" ;;
    *create*)  echo "🟢" ;;
    *)         echo "🔵" ;;
  esac
}

echo "### $title"
echo

if [[ -z "$changes" ]]; then
  echo "No changes. The tenant matches the configuration."
  exit 0
fi

echo "**$(count create) to add, $(count update) to change, $(count replace) to replace," \
  "$(count destroy) to destroy, $(count import) to import, $(count move) to move," \
  "$(count forget) to forget.**"
echo
echo "| | Action | Resource |"
echo "|---|---|---|"
while IFS=$'\t' read -r action address; do
  echo "| $(icon "$action") | $action | \`$address\` |"
done <<<"$changes"
echo

# The human-readable plan, from the first resource header onwards. Moving each
# change symbol to the start of its line lets a `diff` code block colour it:
# green for +, red for -, and ! (shown amber) in place of ~.
diff="$(terraform show -no-color "$plan_file" \
  | sed -n '/^  # /,$p' \
  | sed -E \
      -e 's/^( +)-\/\+/-\/+\1/' \
      -e 's/^( +)\+\/-/+\/-\1/' \
      -e 's/^( +)([+-]) /\2\1 /' \
      -e 's/^( +)~ /!\1 /')"

echo "<details><summary>Show the full diff</summary>"
echo
echo '```diff'
if (( ${#diff} > max_diff_characters )); then
  echo "${diff:0:max_diff_characters}"
  echo '```'
  echo
  echo "The diff is too long to show in full. Open the pipeline run log for the rest."
else
  echo "$diff"
  echo '```'
fi
echo
echo "</details>"
