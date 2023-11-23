#!/bin/bash
REPO=$(echo "$1" | cut -d, -f1)
BRANCH=$(echo "$1" | cut -d, -f2)
gh api --method POST -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" -f branch="$BRANCH" "/repos/$REPO/merge-upstream"
