#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

HAS_ERROR=false

ACTIONS=$(
  for WORKFLOW in $(find .github/workflows -type f -name '*.yml' | sort | uniq); do
    ACTIONS=$(< $WORKFLOW \
      yq e '.jobs.*.steps[].uses as $jobsteps | .jobs.*.uses as $jobuses | $jobsteps | [., $jobuses]' -o json \
        | jq -rcMs --arg file "$WORKFLOW" '{"actions": . | flatten} | .file = $file')
    [ -z "${ACTIONS}" ] && continue
    echo -e "${ACTIONS}"
  done | jq -sc '.'
)

CACHE_SUCCESS=()

REPOSITORY="$(gh api repos/{owner}/{repo} --jq .full_name)"
for LINE in $(echo "$ACTIONS" | jq --arg REPOSITORY "$REPOSITORY" -rcM '.[] | .file as $file | .actions[] | . as $action_in_workflow | split("@") | .[0] as $action | .[1] as $sha | $action | split("/") | .[0] as $org | .[1] as $repo | {"file": $file, "action": $action, "sha": $sha, "org": $org, "repo": $repo, "action_in_workflow": $action_in_workflow} | select(.action | contains($REPOSITORY) == false) | select (.action | startswith(".") | not) | select(.action | startswith("docker://") == false)'); do
  file="$(echo "$LINE" | jq -rcM .file)"
  org="$(echo "$LINE" | jq -rcM .org)"
  repo="$(echo "$LINE" | jq -rcM .repo)"
  sha="$(echo "$LINE" | jq -rcM .sha)"
  action_in_workflow="$(echo "$LINE" | jq -rcM .action_in_workflow)"

  if echo "${CACHE_SUCCESS[@]}" | grep -qE "(^|[ ])$action_in_workflow([ ]|$)"; then
      continue
  fi

  if [ ! "$(gh api "repos/$org/$repo/commits/$sha" --jq .sha)" = "$sha" ]; then
      HAS_ERROR=true
      echo "error: unable to find $action_in_workflow (in file $file)" >/dev/stderr
  fi

  CACHE_SUCCESS+=("$action_in_workflow")
done

if [ "$HAS_ERROR" = true ]; then
    echo "errors found." >/dev/stderr
    exit 1
fi

echo "all unique and valid workflows:"
echo "${CACHE_SUCCESS[@]}" | tr ' ' '\n' | sed 's/^/- /g'
