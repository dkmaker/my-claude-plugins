#!/bin/bash

# Baseline Settings Validator for Claude Code
# Ensures optimal defaults and validates required tools
# Runs on SessionStart with 2-hour throttling

# Read input JSON
INPUT_JSON=$(cat)

# Configuration
LAST_CHECK_FILE="$HOME/.claude/.baseline-last-check"
SETTINGS_FILE="$HOME/.claude/settings.json"
CHECK_INTERVAL_HOURS=2

# Ensure .claude directory exists
mkdir -p "$HOME/.claude" 2>/dev/null || true

# ============================================================================
# THROTTLING CHECK
# ============================================================================

should_run_check() {
    if [[ ! -f "$LAST_CHECK_FILE" ]]; then
        return 0  # First run
    fi

    local last_check
    last_check=$(cat "$LAST_CHECK_FILE" 2>/dev/null || echo "0")
    local now=$(date +%s)
    local age=$((now - last_check))
    local hours=$((age / 3600))

    if [[ $hours -lt $CHECK_INTERVAL_HOURS ]]; then
        return 1  # Too soon
    fi

    return 0  # Time to check
}

# Exit silently if within throttle window
if ! should_run_check; then
    exit 0
fi

# ============================================================================
# TOOL VALIDATION
# ============================================================================

CRITICAL_TOOLS=("jq" "git")
OPTIONAL_TOOLS=("rg")

missing_critical=()
missing_optional=()

for tool in "${CRITICAL_TOOLS[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
        missing_critical+=("$tool")
    fi
done

for tool in "${OPTIONAL_TOOLS[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
        missing_optional+=("$tool")
    fi
done

# If critical tools missing, report and exit (delete check file to force recheck)
if [[ ${#missing_critical[@]} -gt 0 ]]; then
    rm -f "$LAST_CHECK_FILE"

    # Build messages
    tool_list=$(IFS=', '; echo "${missing_critical[*]}")
    install_cmd="sudo apt-get install ${missing_critical[*]}"

    context_msg="⚠️ Critical tools missing: $tool_list - Required for Claude Code features. Install with: $install_cmd"
    system_msg="⚠️ Baseline: Missing critical tools ($tool_list). Install: $install_cmd"

    jq -n \
        --arg context "$context_msg" \
        --arg sysmsg "$system_msg" \
        '{
            hookSpecificOutput: {
                hookEventName: "SessionStart",
                additionalContext: $context
            },
            systemMessage: $sysmsg
        }'
    exit 0
fi

# ============================================================================
# SETTINGS MANAGEMENT
# ============================================================================

# Baseline settings to enforce (hardcoded)
BASELINE_SETTINGS='{
  "env": {
    "BASH_DEFAULT_TIMEOUT_MS": "300000",
    "BASH_MAX_TIMEOUT_MS": "600000",
    "CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR": "1",
    "DISABLE_NON_ESSENTIAL_MODEL_CALLS": "1"
  },
  "includeCoAuthoredBy": false,
  "alwaysThinkingEnabled": false,
  "spinnerTipsEnabled": false
}'

# Read current settings
if [[ -f "$SETTINGS_FILE" ]]; then
    CURRENT_SETTINGS=$(cat "$SETTINGS_FILE")
else
    CURRENT_SETTINGS="{}"
fi

# Resolve plugin root path for statusline
PLUGIN_STATUSLINE_PATH="${CLAUDE_PLUGIN_ROOT}/statusline.sh"

# Add statusline to baseline (with resolved path)
BASELINE_WITH_STATUSLINE=$(echo "$BASELINE_SETTINGS" | jq --arg path "$PLUGIN_STATUSLINE_PATH" '. + {statusLine: {type: "command", command: $path}}')

# Deep merge: baseline + current, removing "model" key
# Strategy: Start with current, overlay baseline values, remove model
MERGED_SETTINGS=$(jq -s '
    .[1] as $current |
    .[0] as $baseline |

    # Start with current settings
    $current |

    # Deep merge baseline settings
    .env = (($current.env // {}) * ($baseline.env // {})) |
    .includeCoAuthoredBy = $baseline.includeCoAuthoredBy |
    .statusLine = $baseline.statusLine |
    .alwaysThinkingEnabled = $baseline.alwaysThinkingEnabled |
    .spinnerTipsEnabled = $baseline.spinnerTipsEnabled |

    # Remove model key
    del(.model)
' <(echo "$BASELINE_WITH_STATUSLINE") <(echo "$CURRENT_SETTINGS"))

# Check if changes needed
if [[ "$MERGED_SETTINGS" == "$CURRENT_SETTINGS" ]]; then
    # No changes needed

    # Report optional tools if missing
    if [[ ${#missing_optional[@]} -gt 0 ]]; then
        tool_list=$(IFS=', '; echo "${missing_optional[*]}")
        system_msg="ℹ️ Baseline: Optional tools recommended: $tool_list (ripgrep improves performance)"

        jq -n --arg sysmsg "$system_msg" '{systemMessage: $sysmsg}'
    fi

    # Update check file
    date +%s > "$LAST_CHECK_FILE"
    exit 0
fi

# ============================================================================
# BACKUP AND UPDATE
# ============================================================================

# Create backup with timestamp
TIMESTAMP=$(date +"%Y-%m-%d-%H%M%S")
BACKUP_FILE="$HOME/.claude/settings.json.backup-$TIMESTAMP"

cp "$SETTINGS_FILE" "$BACKUP_FILE" 2>/dev/null || {
    # If current file doesn't exist, create empty backup
    echo "{}" > "$BACKUP_FILE"
}

# Rotate backups (keep max 10)
BACKUP_DIR="$HOME/.claude"
BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/settings.json.backup-* 2>/dev/null | wc -l)

if [[ $BACKUP_COUNT -gt 10 ]]; then
    # Delete oldest backups
    ls -1t "$BACKUP_DIR"/settings.json.backup-* | tail -n +11 | xargs rm -f
fi

# Write new settings
echo "$MERGED_SETTINGS" | jq '.' > "$SETTINGS_FILE"

# Build system message
SYSTEM_MSG="✅ Baseline: Settings updated (backup: $BACKUP_FILE)

⚠️ RESTART Claude Code to apply changes:
  - Exit this session
  - Run 'claude' again

Changes applied:
  - Ensured optimal bash timeouts
  - Disabled non-essential messages
  - Configured statusline
  - Removed model override (if present)
"

# Add optional tools warning if needed
if [[ ${#missing_optional[@]} -gt 0 ]]; then
    tool_list=$(IFS=', '; echo "${missing_optional[*]}")
    SYSTEM_MSG="$SYSTEM_MSG
ℹ️ Optional tools recommended: $tool_list"
fi

# Update check file (success)
date +%s > "$LAST_CHECK_FILE"

# Output
jq -n --arg sysmsg "$SYSTEM_MSG" '{systemMessage: $sysmsg}'

exit 0
