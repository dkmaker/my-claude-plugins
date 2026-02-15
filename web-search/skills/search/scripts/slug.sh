#!/usr/bin/env bash
# Generate a slug from a search query string
# Usage: slug.sh "My Search Query Here"
# Output: 2026-02-07-my-search-query-here

set -euo pipefail

if [ $# -eq 0 ]; then
  echo "Usage: slug.sh <query>" >&2
  exit 1
fi

query="$*"
date_prefix=$(date +%Y-%m-%d)

slug=$(echo "$query" \
  | tr '[:upper:]' '[:lower:]' \
  | sed 's/[^a-z0-9 ]//g' \
  | sed 's/  */ /g' \
  | sed 's/^ //;s/ $//' \
  | sed 's/ /-/g' \
  | cut -c1-80)

echo "${date_prefix}-${slug}"
