#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

ORG="${GH_ORG:-GeoNet}"
REPOS="${*}"

# given DEBUG set to true, log special outputs
__debug_echo() {
    if [ ! "${DEBUG:-false}" = true ]; then
        return
    fi
    echo "${@}"
}

# return a list under the ORG of repos with GitHub Actions workflows
get_repos() {
    repos=($(gh api "orgs/$ORG/repos" --jq '.[] | select(.fork==false) | select(.archived==false) | .owner.login + "/" + .name' --paginate | sort))
    echo "${repos[@]}"
}

has_repo_github_actions() {
    REPO="$1"
    if gh api "repos/$REPO/contents/.github/workflows" --jq ". | length | . > 0" >/dev/null 2>&1; then
        echo true
        return
    fi
    echo false
}

# given a repo and offset, return the number of the latest merged PR made by a human
get_pull_request_numbers() {
    REPO="$1"
    LIST_OFFSET="${2:-1}"
    NUMBERS="$(gh api -X GET "repos/$REPO/pulls" -f state=closed \
        --jq '.[] | select(.merged_at!=null) | select(.user.Bot!="type") | select(.user.login!="github-actions[bot]") | select(.user.login!="dependabot[bot]") | .number')"
    if [ -z "$NUMBERS" ]; then
        echo 0
        return
    fi
    echo "$NUMBERS" | head -n"${LIST_OFFSET}" | tail -n1
}

# given a repo and a PR number, return the latest commit digest
get_head_ref_commit() {
    REPO="$1"
    NUMBER="$2"
    commit="$(gh api "repos/$REPO/pulls/$NUMBER/commits" --jq 'last(. | to_entries[]) | .value.sha')"
    echo "$commit"
}

# given a repo, return status checks
# NOTE not currently used
get_status_checks() {
    REPO="$1"
    checks=()
    for PR in $(get_pull_request_numbers "$REPO"); do
        __debug_echo "$REPO/pull/$PR"
        COMMIT="$(get_head_ref_commit "$REPO" "$PR")"
        __debug_echo "  - PR commit: $COMMIT"
        while read CONTEXT; do
            checks+=("$CONTEXT")
        done < <(gh api "repos/$REPO/commits/$COMMIT/status" --jq '.statuses[].context' | grep -viE '^travis|conform/')
    done
    CHECKS+=("${checks[@]}")
}

# given a repo, return a list of workflow checks
get_workflow_checks() {
    REPO="$1"
    checks=()
    PR_NUMBER_OFFSET=1
    HAS_CHECKS=false
    until [ "${HAS_CHECKS:-false}" = true ]; do
        for PR in $(get_pull_request_numbers "$REPO" "$PR_NUMBER_OFFSET"); do
            # exit get_workflow_checks if
            # - there are no PRs for the repo
            # - up to five earlier than the latest PR still have no checks
            if [ "$PR" = "0" ] || [ "$PR_NUMBER_OFFSET" = "5" ]; then
                break 2
            fi
            __debug_echo "$REPO/pull/$PR"
            COMMIT="$(get_head_ref_commit "$REPO" "$PR")"
            __debug_echo "  - PR commit: $COMMIT"
            while read SUITE; do
                __debug_echo "    - Check suite: $SUITE"
                while read RUN; do
                    __debug_echo "      - Check run: $RUN"
                    checks+=("$RUN")
                done < <(gh api "repos/$REPO/check-suites/$SUITE/check-runs" --jq '.check_runs[].name' | grep -viE 'travis|\$\{\{ matrix..* \}\}')
            done < <(gh api "repos/$REPO/commits/$COMMIT/check-suites" --jq .check_suites[].id)
        done
        # if no checks are found, try one earlier than the latest PR
        if [ "$(echo "${checks[@]}" | tr ' ' '\n' | wc -l)" = "1" ]; then
            PR_NUMBER_OFFSET=$((PR_NUMBER_OFFSET+=1))
            continue
        fi
        HAS_CHECKS=true
        CHECKS+=("${checks[@]}")
    done
}

# given a repo, return a list of checks
get_checks() {
    REPO="$1"
    printf "$REPO:"
    CHECKS=()
    if [ ! "$(get_pull_request_numbers "$REPO")" = "0" ]; then
        get_status_checks "$REPO"
        if [ $(has_repo_github_actions "$REPO") = true ]; then
            get_workflow_checks "$REPO"
        fi
    fi
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
        get_checks "$ORG/$REPO"
    done
    exit $?
fi

for REPO in $(get_repos); do
    get_checks "$REPO"
done
