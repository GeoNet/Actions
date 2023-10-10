#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# NOTE must be in format from ./hack/list-checks.sh
INPUT="$(< /dev/stdin yq e)"
# NOTE only manages the fields
# .branch-protection.orgs.ORG.repos.REPO.branches.DEFAULT
#   - .protect
#   - .required_status_checks.contexts
OUTPUT="${1:-}"
ACTION="${2:-update}"

if [ -z "$OUTPUT" ]; then
    cat <<EOF
usage: $0 OUTPUTFILE.yaml [update|sow]
EOF
    exit 1
fi

if [ ! -f "$OUTPUT" ]; then
    touch "$OUTPUT"
fi

if [ ! "$ACTION" = "sow" ]; then
  cat <<EOF
NOTE: using update mode. To write the state-of-the-world use

$ $0 $1 sow

EOF
fi

for REPO in $(echo "$INPUT" | yq e '. | keys | .[]'); do
    ORG="$(gh api repos/$REPO --jq '.owner.login')"
    export ORG
    REPO="$(gh api repos/$REPO --jq '.name')"
    export REPO
    CHECKS="$(echo "$INPUT" | yq e '.[env(ORG) + "/" + env(REPO)]' -o json | jq -rcM)"
    export CHECKS
    echo "$REPO : $CHECKS"
    PROTECTED_BRANCHES=($(gh api -X GET repos/$ORG/$REPO/branches --jq '.[] | select(.protected==true) | .name'))

    for BRANCH in "${PROTECTED_BRANCHES[@]}"; do
        if [ "$ACTION" = "sow" ]; then
            EBP="$(gh api -X GET repos/$ORG/$REPO/branches/$BRANCH/protection | jq | yq e -P)"
            export EBP BRANCH
            yq e -P -i 'with(.branch-protection.orgs[strenv(ORG)].repos[strenv(REPO)].branches[strenv(BRANCH)];
                .enforce_admins = (env(EBP) | .enforce_admins.enabled)
              | .required_linear_history = (env(EBP) | .required_linear_history.enabled)
              | .allow_force_pushes = (env(EBP) | .allow_force_pushes.enabled)
              | .allow_deletions = (env(EBP) | .allow_deletions.enabled)
              | .required_linear_history = (env(EBP) | .required_linear_history.enabled)
              | .required_pull_request_reviews = (env(EBP) | .required_pull_request_reviews)
              | .required_pull_request_reviews.dismissal_restrictions.users = ([.required_pull_request_reviews.dismissal_restrictions.users[] | .login])
              | .required_pull_request_reviews.dismissal_restrictions.teams = ([.required_pull_request_reviews.dismissal_restrictions.teams[] | .slug])
              | . |= (with(select(.required_pull_request_reviews.dismissal_restrictions.users | length | . == 0) | select(.required_pull_request_reviews.dismissal_restrictions.teams | length | . == 0); del .required_pull_request_reviews.dismissal_restrictions))
              | del .required_pull_request_reviews.url
              | del .required_pull_request_reviews.dismissal_restrictions.url
              | del .required_pull_request_reviews.dismissal_restrictions.users_url
              | del .required_pull_request_reviews.dismissal_restrictions.teams_url
              | .required_pull_request_reviews.bypass_pull_request_allowances.users = ([.required_pull_request_reviews.bypass_pull_request_allowances.users[] | .login])
              | .required_pull_request_reviews.bypass_pull_request_allowances.teams = ([.required_pull_request_reviews.bypass_pull_request_allowances.teams[] | .slug])
              | . |= (with(select(.required_pull_request_reviews.bypass_pull_request_allowances.users | length | . == 0) | select(.required_pull_request_reviews.bypass_pull_request_allowances.teams | length | . == 0); del .required_pull_request_reviews.bypass_pull_request_allowances))
              | .required_status_checks.strict = (env(EBP) | .required_status_checks.strict)
              | .restrictions.users = ([env(EBP) | .restrictions.users[] | .login])
              | .restrictions.teams = ([env(EBP) | .restrictions.teams[] | .slug])
              | . |= (with(select(.restrictions.users | length | . == 0) | select(.restrictions.teams | length | . == 0); del .restrictions))
              | .protect = true | .required_status_checks.contexts = env(CHECKS))' "$OUTPUT"
        else
          export BRANCH
          echo "$ORG $REPO $BRANCH $CHECKS"
          yq e -P -i '.branch-protection.orgs[strenv(ORG)].repos[strenv(REPO)].branches[strenv(BRANCH)].protect = true
                   | .branch-protection.orgs[strenv(ORG)].repos[strenv(REPO)].branches[strenv(BRANCH)].required_status_checks.contexts = env(CHECKS)' "$OUTPUT"
        fi
    done
done
