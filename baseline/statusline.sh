#!/usr/bin/env bash
#============================================================================
# ClaudeCode Status Line Script - OPTIMIZED
# Version: 2.1.0
# Optimized for minimal CPU/IO - runs every 300ms
#============================================================================

# Minimal initialization - no subshells
[[ "${BASH_VERSION%%.*}" -lt 4 ]] && { echo "Claude Code"; exit 0; }

# Colors (inline, no conditionals in hot path)
C_CYAN=$'\033[96m'
C_GREEN=$'\033[92m'
C_RED=$'\033[91m'
C_ORANGE=$'\033[38;5;208m'
C_YELLOW=$'\033[93m'
C_RESET=$'\033[0m'
C_ASTERISK=$'\033[48;2;218;115;88m\033[97m'
C_DIM=$'\033[2m'

# Read input (single read, no timeout command)
read -t 1 -r input || true
[[ -z "$input" ]] && { echo "Claude Code"; exit 0; }

# Parse all JSON values in ONE pass using a single regex scan
# Extract: display_name, version, current_dir, project_dir, total_lines_added/removed, total_input/output_tokens, used_percentage
model="Claude" version="" current_dir="" project_dir=""
lines_added=0 lines_removed=0 input_tokens=0 output_tokens=0 context_pct=0 context_remaining=0

# Remove newlines/tabs only (keep spaces in values)
input="${input//[$'\n\r\t']/}"

# Parse string values
[[ $input =~ \"display_name\":\"([^\"]+)\" ]] && model="${BASH_REMATCH[1]}"
[[ $input =~ \"version\":\"([^\"]+)\" ]] && version="${BASH_REMATCH[1]}"
[[ $input =~ \"current_dir\":\"([^\"]+)\" ]] && current_dir="${BASH_REMATCH[1]}"
[[ $input =~ \"project_dir\":\"([^\"]+)\" ]] && project_dir="${BASH_REMATCH[1]}"

# Parse numeric values
[[ $input =~ \"total_lines_added\":([0-9]+) ]] && lines_added="${BASH_REMATCH[1]}"
[[ $input =~ \"total_lines_removed\":([0-9]+) ]] && lines_removed="${BASH_REMATCH[1]}"
[[ $input =~ \"total_input_tokens\":([0-9]+) ]] && input_tokens="${BASH_REMATCH[1]}"
[[ $input =~ \"total_output_tokens\":([0-9]+) ]] && output_tokens="${BASH_REMATCH[1]}"
[[ $input =~ \"used_percentage\":([0-9]+) ]] && context_pct="${BASH_REMATCH[1]}"
[[ $input =~ \"remaining_percentage\":([0-9]+) ]] && context_remaining="${BASH_REMATCH[1]}"

# Fallback if critical fields missing
[[ -z "$current_dir" || -z "$project_dir" ]] && { echo "🤖 ${model}${version:+ * $version}"; exit 0; }

# Format number with K/M suffix - pure bash, no external commands
fmt_num() {
    local n=$1
    if (( n >= 1000000 )); then
        printf "%d.%dM" $((n/1000000)) $(((n%1000000)/100000))
    elif (( n >= 1000 )); then
        printf "%d.%dK" $((n/1000)) $(((n%1000)/100))
    else
        printf "%d" "$n"
    fi
}

# Git info with caching - use /dev/shm for speed, session_id for uniqueness
git_info=""
if [[ $input =~ \"session_id\":\"([^\"]+)\" ]]; then
    session_id="${BASH_REMATCH[1]}"
    cache_file="/dev/shm/claude_git_${session_id}"

    # Check cache (read is faster than stat + date)
    if [[ -f "$cache_file" ]]; then
        IFS=: read -r cached_time cached_dir cached_info < "$cache_file"
        now=${EPOCHSECONDS:-$(printf '%(%s)T' -1)}
        if [[ "$cached_dir" == "$project_dir" && $((now - cached_time)) -lt 5 ]]; then
            git_info="$cached_info"
        fi
    fi

    # Cache miss - fetch git info
    if [[ -z "$git_info" ]]; then
        git_dir="" is_worktree=""
        if [[ -d "${project_dir}/.git" ]]; then
            # Regular repo - .git is a directory
            git_dir="${project_dir}/.git"
        elif [[ -f "${project_dir}/.git" ]]; then
            # Worktree - .git is a file pointing to main repo
            read -r gitdir_line < "${project_dir}/.git"
            [[ $gitdir_line == gitdir:\ * ]] && git_dir="${gitdir_line#gitdir: }"
            is_worktree=1
        fi
        if [[ -n "$git_dir" ]]; then
            # Read branch from HEAD
            if [[ -f "${git_dir}/HEAD" ]]; then
                read -r head < "${git_dir}/HEAD"
                [[ $head == ref:\ refs/heads/* ]] && branch="${head#ref: refs/heads/}"
            fi
            # Read remote URL - for worktrees, config is in main .git dir
            config_file="${git_dir}/config"
            [[ -n "$is_worktree" && ! -f "$config_file" ]] && config_file="${git_dir%/worktrees/*}/config"
            if [[ -f "$config_file" && -n "$branch" ]]; then
                while IFS= read -r line; do
                    [[ $line =~ url\ =\ .*github\.com[:/]([^/]+)/([^/.]+) ]] && {
                        git_info="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}:${branch}"
                        break
                    }
                done < "$config_file"
                [[ -z "$git_info" && -n "$branch" ]] && git_info="$branch"
            fi
            # Prefix with wt: if in a worktree
            [[ -n "$is_worktree" && -n "$git_info" ]] && git_info="wt:${git_info}"
            [[ -n "$is_worktree" && -z "$git_info" ]] && git_info="wt:"
        fi
        # Update cache
        now=${EPOCHSECONDS:-$(printf '%(%s)T' -1)}
        printf '%s:%s:%s' "$now" "$project_dir" "$git_info" > "$cache_file" 2>/dev/null
    fi
fi

# Version update check - only read cache file, never write in hot path
latest_version=""
version_cache="${HOME}/.claude/latest_version_check"
if [[ -n "$version" && -f "$version_cache" ]]; then
    read -r cached_ver < "$version_cache"
    [[ -n "$cached_ver" && "$cached_ver" != "$version" ]] && latest_version="$cached_ver"
fi

# Build output - single printf is faster than multiple
out="${C_CYAN}🤖 ${model}${C_RESET} ${C_ASTERISK} * ${C_RESET} "

# Version (green or orange if update available)
if [[ -n "$latest_version" ]]; then
    out+="${C_ORANGE}${version}${C_RESET} 🔄 ${C_GREEN}${latest_version}${C_RESET}"
else
    out+="${C_GREEN}${version}${C_RESET}"
fi

# Git info
[[ -n "$git_info" ]] && out+=" ${C_ORANGE}🌿 ${git_info}${C_RESET}"

# Path (only if not at project root)
if [[ "$current_dir" != "$project_dir" ]]; then
    rel_path="${current_dir#"$project_dir"/}"
    out+=" ${C_RED}📂 ${rel_path}${C_RESET}"
fi

# Lines added/removed
(( lines_added || lines_removed )) && out+=" ${C_GREEN}+${lines_added}${C_RESET}/${C_RED}-${lines_removed}${C_RESET}"

# Tokens
out+=" ${C_DIM}→$(fmt_num "$input_tokens")${C_RESET}/${C_DIM}←$(fmt_num "$output_tokens")${C_RESET}"

# Context display strategy:
# Below soft limit (95%): Show single % indicator
# Above soft limit: Show used%/remaining% to highlight proximity to hard limit
SOFT_LIMIT=95

if (( context_pct < SOFT_LIMIT )); then
    # Below soft limit - single indicator showing progress
    if (( context_pct >= 80 )); then
        ctx_color="$C_YELLOW"
    else
        ctx_color="$C_GREEN"
    fi
    out+=" ${ctx_color}📥${context_pct}%${C_RESET}"
else
    # Past soft limit - show both to emphasize urgency
    if (( context_remaining <= 5 )); then
        ctx_color="$C_RED"
    elif (( context_remaining <= 15 )); then
        ctx_color="$C_YELLOW"
    else
        ctx_color="$C_ORANGE"
    fi
    out+=" ${ctx_color}📥${context_pct}%${C_RESET}/${ctx_color}📤${context_remaining}%${C_RESET}"
fi

printf '%b' "$out"
exit 0
