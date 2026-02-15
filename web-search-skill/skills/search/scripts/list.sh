#!/usr/bin/env bash
# List all stored search results with their metadata
# Usage: list.sh <results-dir> [--short]
# <results-dir>: path to search_results directory
# --short: only show slug and title (one line each)

set -euo pipefail

if [ $# -eq 0 ]; then
  echo "Usage: list.sh <results-dir> [--short]" >&2
  exit 1
fi

RESULTS_DIR="$1"
shift

if [ ! -d "$RESULTS_DIR" ]; then
  echo "No search results found."
  exit 0
fi

files=$(find "$RESULTS_DIR" -name '*.md' ! -name 'CLAUDE.md' -type f | sort -r)

if [ -z "$files" ]; then
  echo "No search results found."
  exit 0
fi

short=false
if [ "${1:-}" = "--short" ]; then
  short=true
fi

count=0
while IFS= read -r file; do
  slug=$(basename "$file" .md)

  # Parse frontmatter
  query=""
  mode=""
  date=""

  in_frontmatter=false
  while IFS= read -r line; do
    if [ "$line" = "---" ]; then
      if $in_frontmatter; then
        break
      else
        in_frontmatter=true
        continue
      fi
    fi
    if $in_frontmatter; then
      case "$line" in
        query:*) query="${line#query: }" ;;
        mode:*) mode="${line#mode: }" ;;
        date:*) date="${line#date: }" ;;
      esac
    fi
  done < "$file"

  if $short; then
    echo "$slug | $query"
  else
    echo "---"
    echo "  File: $slug.md"
    echo "  Query: $query"
    echo "  Mode: $mode"
    echo "  Date: $date"
  fi
  count=$((count + 1))
done <<< "$files"

echo ""
echo "Total: $count result(s)"
