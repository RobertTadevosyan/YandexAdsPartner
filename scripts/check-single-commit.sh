#!/bin/bash
set -e

# Get the number of commits in this pull request
COMMITS=$(git rev-list --count origin/${GITHUB_BASE_REF}..HEAD)

echo "📝 Commits in this pull request: $COMMITS"

if [[ "$COMMITS" -ne 1 ]]; then
  echo "❌ Pull request must contain exactly ONE commit. Found: $COMMITS"
  exit 1
fi

echo "✅ Pull request has a single commit."