#!/usr/bin/env bash
# validate-plugins.sh — Validates plugin structure, JSON, versions, hooks, skills, and shell scripts
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MARKETPLACE="$REPO_ROOT/.claude-plugin/marketplace.json"
ERRORS=0

error() {
  echo "ERROR: $*" >&2
  ERRORS=$((ERRORS + 1))
}

info() {
  echo "INFO: $*"
}

# ─── Validate marketplace.json ───────────────────────────────────────────────

info "Validating marketplace.json..."
if ! jq empty "$MARKETPLACE" 2>/dev/null; then
  error "marketplace.json is not valid JSON"
  echo "Cannot continue without valid marketplace.json" >&2
  exit 1
fi

PLUGIN_COUNT=$(jq '.plugins | length' "$MARKETPLACE")
info "Found $PLUGIN_COUNT plugins in marketplace.json"

# ─── Per-plugin validation ───────────────────────────────────────────────────

for i in $(seq 0 $((PLUGIN_COUNT - 1))); do
  MP_NAME=$(jq -r ".plugins[$i].name" "$MARKETPLACE")
  MP_SOURCE=$(jq -r ".plugins[$i].source" "$MARKETPLACE")
  MP_HAS_VERSION=$(jq ".plugins[$i] | has(\"version\")" "$MARKETPLACE")

  # Skip non-local plugins (source is not a string starting with ./)
  if [[ "$MP_SOURCE" != ./* ]]; then
    info "[$MP_NAME] Remote plugin — skipping local validation"
    continue
  fi

  PLUGIN_DIR="$REPO_ROOT/$MP_NAME"
  info "[$MP_NAME] Validating local plugin..."

  # ── Structure checks ────────────────────────────────────────────────────

  if [[ ! -d "$PLUGIN_DIR" ]]; then
    error "[$MP_NAME] Plugin directory does not exist: $MP_NAME/"
    continue
  fi

  PLUGIN_JSON="$PLUGIN_DIR/.claude-plugin/plugin.json"
  if [[ ! -f "$PLUGIN_JSON" ]]; then
    error "[$MP_NAME] Missing .claude-plugin/plugin.json"
    continue
  fi

  if ! jq empty "$PLUGIN_JSON" 2>/dev/null; then
    error "[$MP_NAME] plugin.json is not valid JSON"
    continue
  fi

  # ── Name consistency ────────────────────────────────────────────────────

  PJ_NAME=$(jq -r '.name' "$PLUGIN_JSON")
  if [[ "$PJ_NAME" != "$MP_NAME" ]]; then
    error "[$MP_NAME] Name mismatch: plugin.json has \"$PJ_NAME\", marketplace has \"$MP_NAME\""
  fi

  DIR_BASENAME=$(basename "$PLUGIN_DIR")
  if [[ "$DIR_BASENAME" != "$MP_NAME" ]]; then
    error "[$MP_NAME] Directory name \"$DIR_BASENAME\" does not match marketplace name \"$MP_NAME\""
  fi

  # ── Version rules ───────────────────────────────────────────────────────

  # Local plugins must NOT have version in marketplace entry
  if [[ "$MP_HAS_VERSION" == "true" ]]; then
    error "[$MP_NAME] Local plugin should NOT have \"version\" in marketplace.json (version belongs in plugin.json only)"
  fi

  # plugin.json must have a semver version
  PJ_VERSION=$(jq -r '.version // empty' "$PLUGIN_JSON")
  if [[ -z "$PJ_VERSION" ]]; then
    error "[$MP_NAME] plugin.json is missing \"version\" field"
  elif ! echo "$PJ_VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+'; then
    error "[$MP_NAME] plugin.json version \"$PJ_VERSION\" is not valid semver (expected X.Y.Z)"
  fi

  # ── Hook validation ─────────────────────────────────────────────────────

  HOOKS_JSON="$PLUGIN_DIR/hooks/hooks.json"
  if [[ -f "$HOOKS_JSON" ]]; then
    if ! jq empty "$HOOKS_JSON" 2>/dev/null; then
      error "[$MP_NAME] hooks/hooks.json is not valid JSON"
    else
      # Extract all command paths from hooks.json
      # Commands use ${CLAUDE_PLUGIN_ROOT} as prefix — replace with plugin dir for checking
      HOOK_COMMANDS=$(jq -r '.. | .command? // empty' "$HOOKS_JSON" | sed "s|\\\${CLAUDE_PLUGIN_ROOT}|$PLUGIN_DIR|g")
      while IFS= read -r cmd; do
        [[ -z "$cmd" ]] && continue
        if [[ ! -f "$cmd" ]]; then
          error "[$MP_NAME] Hook script not found: $cmd"
        elif [[ ! -x "$cmd" ]]; then
          error "[$MP_NAME] Hook script not executable: $cmd"
        fi
      done <<< "$HOOK_COMMANDS"
    fi
  fi

  # ── Skill validation ────────────────────────────────────────────────────

  if [[ -d "$PLUGIN_DIR/skills" ]]; then
    while IFS= read -r skill_md; do
      [[ -z "$skill_md" ]] && continue
      # Check for YAML frontmatter delimiters
      FIRST_LINE=$(head -1 "$skill_md")
      if [[ "$FIRST_LINE" != "---" ]]; then
        error "[$MP_NAME] SKILL.md missing YAML frontmatter: $skill_md"
        continue
      fi

      # Extract frontmatter (between first and second ---)
      FRONTMATTER=$(sed -n '2,/^---$/p' "$skill_md" | sed '$d')
      if [[ -z "$FRONTMATTER" ]]; then
        error "[$MP_NAME] SKILL.md has empty frontmatter: $skill_md"
        continue
      fi

      # Check required fields (simple grep, avoids yq dependency)
      if ! echo "$FRONTMATTER" | grep -qE '^name:'; then
        error "[$MP_NAME] SKILL.md frontmatter missing \"name\": $skill_md"
      fi
      if ! echo "$FRONTMATTER" | grep -qE '^description:'; then
        error "[$MP_NAME] SKILL.md frontmatter missing \"description\": $skill_md"
      fi
    done < <(find "$PLUGIN_DIR/skills" -name "SKILL.md" 2>/dev/null)
  fi

  # ── Shell script validation ─────────────────────────────────────────────

  while IFS= read -r sh_file; do
    [[ -z "$sh_file" ]] && continue
    # Check shebang
    FIRST_LINE=$(head -1 "$sh_file")
    if [[ "$FIRST_LINE" != "#!"* ]]; then
      error "[$MP_NAME] Shell script missing shebang: $sh_file"
    fi
    # Syntax check
    if ! bash -n "$sh_file" 2>/dev/null; then
      error "[$MP_NAME] Shell script has syntax errors: $sh_file"
    fi
  done < <(find "$PLUGIN_DIR" -name "*.sh" -not -path "*/node_modules/*" 2>/dev/null)

done

# ─── Summary ─────────────────────────────────────────────────────────────────

echo ""
if [[ "$ERRORS" -gt 0 ]]; then
  echo "FAILED: $ERRORS error(s) found"
  exit 1
else
  echo "PASSED: All plugins validated successfully"
  exit 0
fi
