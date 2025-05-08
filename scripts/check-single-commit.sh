#!/bin/bash
set -e

# Fetch all branches and PR refs
git fetch origin "+refs/heads/*:refs/remotes/origin/*" --depth=1

# Get the PR source and base branches
BASE="${GITHUB_BASE_REF}"
HEAD_REF="${GITHUB_HEAD_REF}"

echo "🔍 Comparing commits between origin/$BASE and origin/$HEAD_REF"

# Count commits in the PR branch that are not in the base
COMMITS=$(git rev-list --count origin/"$BASE"..origin/"$HEAD_REF")

echo "📝 Commits in this pull request: $COMMITS"

if [[ "$COMMITS" -ne 1 ]]; then
  echo "❌ Pull request must contain exactly ONE commit. Found: $COMMITS"
  exit 1
fi

echo "✅ Pull request has a single commit."
