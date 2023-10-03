#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

REPOS="${@}"

DEBUG=false
__debug_echo() {
    if [ ! "$DEBUG" = true ]; then
        return
    fi
    echo "${@}"
}

get_repos_with_actions() {
    repos=($(gh api orgs/GeoNet/repos --jq '.[] | select(.fork==false) | select(.archived==false) | .name' --paginate \
    | sort \
    | tr ' ' '\n' \
    | xargs -I{} \
      sh -c 'gh api "repos/GeoNet/{}/contents/.github/workflows" --jq ". | length | . > 0" 2>&1>/dev/null && echo GeoNet/{}' \
      | grep -E '^GeoNet/.*' | cat))
    echo "${repos[@]}"
}

get_pull_request_numbers() {
    REPO="$1"
    PULL_REQUEST_NUMBERS=()
    while read NUMBER; do
        PULL_REQUEST_NUMBERS+=("$NUMBER")
    done < <(gh api -X GET "repos/$REPO/pulls" -f state=all --jq .[0].number)
    echo "${PULL_REQUEST_NUMBERS[@]}"
}

get_head_ref_commit() {
    REPO="$1"
    NUMBER="$2"
    commit="$(gh api "repos/$REPO/pulls/$NUMBER/commits" --jq '.[0].sha')"
    echo "$commit"
}

get_status_checks() {
    REPO="$1"
    checks=()
    for PR in $(get_pull_request_numbers "$REPO"); do
        __debug_echo "$REPO/pull/$PR"
        COMMIT="$(get_head_ref_commit "$REPO" "$PR")"
        __debug_echo "  - PR commit: $COMMIT"
        while read CONTEXT; do
            checks+=("$CONTEXT")
        done < <(gh api "repos/$REPO/commits/$COMMIT/status" --jq '.statuses[].context' | grep -vi travis)
    done
    CHECKS+=("${checks[@]}")
}

get_workflow_checks() {
    REPO="$1"
    checks=()
    for PR in $(get_pull_request_numbers "$REPO"); do
        __debug_echo "$REPO/pull/$PR"
        COMMIT="$(get_head_ref_commit "$REPO" "$PR")"
        __debug_echo "  - PR commit: $COMMIT"
        while read SUITE; do
            __debug_echo "    - Check suite: $SUITE"
            while read RUN; do
                __debug_echo "      - Check run: $RUN"
                checks+=("$RUN")
            done < <(gh api "repos/$REPO/check-suites/$SUITE/check-runs" --jq .check_runs[].name | sed 's/(.*) //' | grep -vi travis)
        done < <(gh api "repos/$REPO/commits/$COMMIT/check-suites" --jq .check_suites[].id)
    done
    CHECKS+=("${checks[@]}")
}

get_checks() {
    REPO="$1"
    printf "$REPO:"
    CHECKS=()
    get_status_checks "$REPO"
    get_workflow_checks "$REPO"
    if [[ -z ${CHECKS[*]} ]]; then
        echo ' []'
    else
        echo
    fi
    (
        for CHECK in "${CHECKS[@]}"; do
            echo "  - $CHECK"
        done
    ) | sort | uniq
}

if [ -n "$REPOS" ]; then
    for REPO in $REPOS; do
        get_checks "GeoNet/$REPO"
    done
    exit $?
fi

for REPO in $(get_repos_with_actions); do
    get_checks "$REPO"
done
