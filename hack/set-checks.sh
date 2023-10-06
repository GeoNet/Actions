#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# NOTE Input must be from stdin and formatted like
# ORG/REPO:
#   - check1
#   - check2
INPUT="$(< /dev/stdin yq e)"
GHA_APPID="15368" # github actions integrates with github through github app integrations

APPLY="${1:-do-not-apply}"

for REPO in $(echo "$INPUT" | yq e '. | keys | .[]'); do
    export REPO="$REPO" # for yq env
    CHECKS="$(echo "$INPUT" | yq e '.[env(REPO)]' -o json | jq -rcM)"
    echo "$REPO : $CHECKS"

    ORG="$(gh api repos/$REPO --jq '.owner.login')"
    DEFAULT_BRANCH="$(gh api "repos/$REPO" --jq .default_branch)"
    if ! gh api "repos/$REPO/branches/$DEFAULT_BRANCH/protection" ; then
        UPDATED_CONFIG="$(jq -rcnM --arg CHECKS "$CHECKS" --arg ORG "$ORG" --arg GHA_APPID "$GHA_APPID" \
            '{
                "required_status_checks": {
                  "strict": true,
                  "checks": [($CHECKS | fromjson | .[] | {"context":.,"app_id":($GHA_APPID | tonumber)})]
                },
                "restrictions": {"users":[], "teams":[], "apps":[]},
                "enforce_admins": null,
                "required_pull_request_reviews": null
             }')"
    else
        EXISTING_CONFIG="$(gh api "repos/$REPO/branches/$DEFAULT_BRANCH/protection" | jq -rcM)"
        # NOTE removes lots of fields from the original, since the api rejects them as non-null values.
        #      instead of constructing a new json object, it's based off of the current SOW
        #      to retain other fields that we don't care about in this update that might
        #      be in the original values.
        UPDATED_CONFIG="$(echo "$EXISTING_CONFIG" \
            | jq -rcM --arg CHECKS "$CHECKS" --arg ORG "$ORG" --arg GHA_APPID "$GHA_APPID" \
            '.required_status_checks = {"strict":true, "checks": [($CHECKS | fromjson | .[] | {"context":.,"app_id":($GHA_APPID | tonumber)})]} |
        .restrictions = {"users":[], "teams":[], "apps":[]} |
        .enforce_admins=null | .required_signatures=null | .required_linear_history=null | .allow_deletions=null | .block_creations=null |
        .required_conversation_resolution=null | .lock_branch=null | .allow_fork_syncing=null | .url=null | .required_pull_request_reviews=null | .allow_force_pushes=null
        ')"
    fi

    echo "Config difference:"
    sdiff <(echo "$EXISTING_CONFIG" | jq) <(echo "$UPDATED_CONFIG" | jq) || true

    if [ ! "$APPLY" = "apply-and-agree-to-risk" ]; then
        echo "NOTE: dry run enabled"
        echo "WARNING: applying may change unintended settings regarding branch protection for the target branch"
        echo "to apply, use: $0 apply-and-agree-to-risk"
        continue
    fi

    # NOTE gh api doesn't support this functionality
    echo "Updating branch protection for $REPO on branch $DEFAULT_BRANCH"
    curl -L \
        -X PUT \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $(gh auth token)" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "https://api.github.com/repos/$REPO/branches/$DEFAULT_BRANCH/protection" \
        -d "$UPDATED_CONFIG"
done
