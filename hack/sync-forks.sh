#!/bin/bash
for FORK in "${!FORKS[@]}";
do
    printf "fork: %s\n" ${FORKS[$FORK]}
    BRANCH=$(gh api \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    /repos/${FORKS[$FORK]} | jq -rc .default_branch)
    printf "branch: %s\n" ${BRANCH}
    gh api \
    --method POST \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "/repos/${FORKS[$FORK]}/merge-upstream" \
    -f branch="${BRANCH}"
done
