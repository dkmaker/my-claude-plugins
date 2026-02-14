#!/bin/bash

# WSL SSH Agent Bridge for Claude Code
# Bridges Windows SSH agent to WSL for SSH/SCP/Git operations
# Works with 1Password, native Windows OpenSSH agent, etc.

# Configuration
EXPECTED_SOCK="$HOME/.ssh/agent.sock"
AGENT_BRIDGE_SCRIPT="$HOME/.ssh/agent-bridge.sh"
LAST_CHECK_FILE="$HOME/.claude/.wsl-ssh-agent-last-check"
CHECK_INTERVAL_HOURS=2

# Ensure .claude directory exists
mkdir -p "$HOME/.claude" 2>/dev/null || true

# Track what we did
ACTIONS_TAKEN=()

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

output_error() {
    local context_msg="$1"
    local system_msg="$2"

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
}

output_success() {
    local system_msg="$1"
    jq -n --arg sysmsg "$system_msg" '{systemMessage: $sysmsg}'
}

is_bridge_running() {
    pgrep -f "npiperelay.exe.*openssh-ssh-agent" > /dev/null 2>&1
}

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

get_win_home() {
    local win_home=""
    local win_profile=""
    local cmd_exe="/mnt/c/Windows/System32/cmd.exe"

    # Get Windows USERPROFILE using cmd.exe with full path
    if [[ -x "$cmd_exe" ]]; then
        win_profile=$("$cmd_exe" /c "echo %USERPROFILE%" 2>/dev/null | tr -d '\r')
    fi

    # Convert to WSL path
    if [[ -n "$win_profile" ]]; then
        win_home=$(wslpath -u "$win_profile" 2>/dev/null)
    fi

    echo "$win_home"
}

# ============================================================================
# CONFLICT CHECK (always run, even if throttled)
# ============================================================================

if [[ -n "$SSH_AUTH_SOCK" && "$SSH_AUTH_SOCK" != "$EXPECTED_SOCK" ]]; then
    output_error \
        "Conflicting SSH_AUTH_SOCK detected: $SSH_AUTH_SOCK. Remove existing SSH agent configuration from ~/.bashrc or ~/.zshrc before using this plugin." \
        "WSL SSH Agent: Conflicting SSH_AUTH_SOCK ($SSH_AUTH_SOCK). Remove old config from shell rc files."
    exit 0
fi

# ============================================================================
# THROTTLE CHECK
# ============================================================================

if ! should_run_check; then
    # Within throttle window - just make sure bridge is running
    if ! is_bridge_running; then
        # Bridge not running, need to start it - continue with setup
        :
    else
        # Everything is fine, exit silently
        exit 0
    fi
fi

# ============================================================================
# WSL ENVIRONMENT VALIDATION
# ============================================================================

# Check WSL interop (newer kernels use WSLInterop-late)
if ! grep -q "^enabled" /proc/sys/fs/binfmt_misc/WSLInterop 2>/dev/null \
   && ! grep -q "^enabled" /proc/sys/fs/binfmt_misc/WSLInterop-late 2>/dev/null; then
    output_error \
        "WSL interop is disabled. Enable in /etc/wsl.conf under [interop] enabled=true, then run 'wsl --shutdown' from PowerShell." \
        "WSL SSH Agent: Interop disabled. Enable in /etc/wsl.conf"
    exit 0
fi

# Check /mnt/c mount
if ! mount | grep -q '/mnt/c'; then
    output_error \
        "Windows drive not mounted at /mnt/c. Check WSL configuration." \
        "WSL SSH Agent: /mnt/c not mounted"
    exit 0
fi

# Check cmd.exe exists (needed to get Windows user profile)
CMD_EXE="/mnt/c/Windows/System32/cmd.exe"
if [[ ! -x "$CMD_EXE" ]]; then
    output_error \
        "Windows cmd.exe not found at $CMD_EXE. Check that Windows is properly accessible from WSL." \
        "WSL SSH Agent: cmd.exe not found"
    exit 0
fi

# ============================================================================
# PREREQUISITES CHECK
# ============================================================================

# Check socat
if ! command -v socat &>/dev/null; then
    output_error \
        "socat not installed. Run: sudo apt install socat" \
        "WSL SSH Agent: Missing socat. Run: sudo apt install socat"
    exit 0
fi

# Get Windows home directory
WIN_HOME=$(get_win_home)
if [[ -z "$WIN_HOME" ]]; then
    output_error \
        "Could not detect Windows user home directory." \
        "WSL SSH Agent: Cannot detect Windows home"
    exit 0
fi

NPIPERELAY_PATH="$WIN_HOME/.bin/npiperelay.exe"
PLUGIN_NPIPERELAY="${CLAUDE_PLUGIN_ROOT}/bin/npiperelay.exe"

# Install npiperelay.exe if needed
if [[ ! -f "$NPIPERELAY_PATH" ]]; then
    # Create .bin directory if needed
    mkdir -p "$WIN_HOME/.bin" 2>/dev/null

    # Copy from plugin
    if [[ -f "$PLUGIN_NPIPERELAY" ]]; then
        cp "$PLUGIN_NPIPERELAY" "$NPIPERELAY_PATH"
        chmod +x "$NPIPERELAY_PATH"
        ACTIONS_TAKEN+=("Installed npiperelay.exe to $WIN_HOME/.bin/")
    else
        output_error \
            "npiperelay.exe not found in plugin. Reinstall the wsl-ssh-agent plugin." \
            "WSL SSH Agent: Plugin corrupted - npiperelay.exe missing"
        exit 0
    fi
fi

# ============================================================================
# SSH DIRECTORY SETUP
# ============================================================================

if [[ ! -d "$HOME/.ssh" ]]; then
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    ACTIONS_TAKEN+=("Created ~/.ssh directory")
fi

# ============================================================================
# AGENT BRIDGE SCRIPT
# ============================================================================

# Generate the expected content
EXPECTED_BRIDGE_CONTENT='#!/bin/bash
# WSL SSH Agent Bridge - bridges Windows SSH agent to WSL
# Generated by wsl-ssh-agent plugin

export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"

# Start bridge if not running
if ! pgrep -f "npiperelay.exe.*openssh-ssh-agent" > /dev/null 2>&1; then
    rm -f "$SSH_AUTH_SOCK"
    WIN_PROFILE=$(/mnt/c/Windows/System32/cmd.exe /c "echo %USERPROFILE%" 2>/dev/null | tr -d "\r")
    WIN_HOME=$(wslpath -u "$WIN_PROFILE" 2>/dev/null)
    if [[ -n "$WIN_HOME" && -x "$WIN_HOME/.bin/npiperelay.exe" ]]; then
        nohup socat UNIX-LISTEN:"$SSH_AUTH_SOCK",fork \
            EXEC:"$WIN_HOME/.bin/npiperelay.exe -ei -s //./pipe/openssh-ssh-agent",nofork > /dev/null 2>&1 &
        # Wait briefly for socket to be created
        sleep 0.3
    fi
fi

# Verify agent is accessible (silent check)
if [[ -S "$SSH_AUTH_SOCK" ]]; then
    ssh-add -l > /dev/null 2>&1 || true
fi'

# Check if script needs to be created/updated
if [[ ! -f "$AGENT_BRIDGE_SCRIPT" ]]; then
    echo "$EXPECTED_BRIDGE_CONTENT" > "$AGENT_BRIDGE_SCRIPT"
    chmod +x "$AGENT_BRIDGE_SCRIPT"
    ACTIONS_TAKEN+=("Created ~/.ssh/agent-bridge.sh")
fi

# ============================================================================
# BASHRC SETUP
# ============================================================================

BASHRC="$HOME/.bashrc"
SOURCE_LINE='source ~/.ssh/agent-bridge.sh'

# Check for existing SSH agent configurations that would conflict
if [[ -f "$BASHRC" ]]; then
    # Look for other SSH_AUTH_SOCK exports or agent configs (excluding our own)
    EXISTING_CONFIG=$(grep -n "SSH_AUTH_SOCK\|ssh-agent\|\.agent-bridge" "$BASHRC" 2>/dev/null | grep -v "source ~/.ssh/agent-bridge.sh" | grep -v "# WSL SSH Agent" || true)
    if [[ -n "$EXISTING_CONFIG" ]]; then
        output_error \
            "Existing SSH agent configuration found in ~/.bashrc. Please remove or comment out these lines before using this plugin:\n$EXISTING_CONFIG" \
            "WSL SSH Agent: Existing SSH config in .bashrc. Remove conflicting lines first."
        exit 0
    fi
fi

if [[ -f "$BASHRC" ]]; then
    if ! grep -qF "$SOURCE_LINE" "$BASHRC"; then
        echo "" >> "$BASHRC"
        echo "# WSL SSH Agent Bridge" >> "$BASHRC"
        echo "$SOURCE_LINE" >> "$BASHRC"
        ACTIONS_TAKEN+=("Added SSH agent bridge to ~/.bashrc")
    fi
else
    # Create .bashrc with the source line
    echo "# WSL SSH Agent Bridge" > "$BASHRC"
    echo "$SOURCE_LINE" >> "$BASHRC"
    ACTIONS_TAKEN+=("Created ~/.bashrc with SSH agent bridge")
fi

# ============================================================================
# START BRIDGE IF NOT RUNNING
# ============================================================================

if ! is_bridge_running; then
    # Remove stale socket
    rm -f "$EXPECTED_SOCK"

    # Start the bridge using nohup for reliable backgrounding
    nohup socat UNIX-LISTEN:"$EXPECTED_SOCK",fork \
        EXEC:"$NPIPERELAY_PATH -ei -s //./pipe/openssh-ssh-agent",nofork > /dev/null 2>&1 &

    # Wait briefly and verify it started
    sleep 0.5
    if is_bridge_running; then
        ACTIONS_TAKEN+=("Started SSH agent bridge")
    else
        output_error \
            "Failed to start SSH agent bridge. Check that Windows OpenSSH agent is running." \
            "WSL SSH Agent: Failed to start bridge"
        exit 0
    fi
fi

# ============================================================================
# UPDATE THROTTLE TIMESTAMP
# ============================================================================

date +%s > "$LAST_CHECK_FILE"

# ============================================================================
# OUTPUT
# ============================================================================

if [[ ${#ACTIONS_TAKEN[@]} -gt 0 ]]; then
    # Build action list
    action_list=""
    for action in "${ACTIONS_TAKEN[@]}"; do
        action_list="${action_list}\n  - ${action}"
    done

    output_success "WSL SSH Agent: Setup complete${action_list}"
fi

# Silent exit if no actions taken
exit 0
