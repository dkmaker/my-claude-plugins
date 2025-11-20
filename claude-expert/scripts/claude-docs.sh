#!/usr/bin/env bash
set -euo pipefail

# Claude Code Documentation Manager
# Manages downloading, diffing, and tracking changes to Claude Code documentation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$0"
DOCS_DIR="${HOME}/.claude/docs"
CACHE_DIR="${DOCS_DIR}/.cache"
DIFF_DIR="${DOCS_DIR}/.diffs"
JSON_FILE="${SCRIPT_DIR}/claude-docs-urls.json"
CHANGELOG_FILE="${DOCS_DIR}/CHANGELOG.md"
LAST_UPDATE_FILE="${DOCS_DIR}/.last-update"
MISSING_DOCS_FILE="${DOCS_DIR}/.missing-docs"

# Cache version - increment when pipeline changes to invalidate all caches
CACHE_VERSION="v1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Show warning for missing documents
show_missing_docs_warning() {
    if [[ -f "$MISSING_DOCS_FILE" ]] && [[ -s "$MISSING_DOCS_FILE" ]]; then
        local count=$(wc -l < "$MISSING_DOCS_FILE")
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
        echo -e "${YELLOW}⚠  WARNING: $count documentation section(s) unavailable${NC}" >&2
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
        echo "" >&2
        echo "The following sections could not be downloaded:" >&2
        echo "" >&2

        while IFS='|' read -r slug url; do
            echo "  ✗ $slug" >&2
            echo "    URL: $url.md" >&2
        done < "$MISSING_DOCS_FILE"

        echo "" >&2
        echo "Possible reasons:" >&2
        echo "  - Section was renamed or removed from official docs" >&2
        echo "  - URL in claude-docs-urls.json is incorrect" >&2
        echo "  - Temporary network/server issue" >&2
        echo "" >&2
        echo "To fix: Update claude-docs-urls.json and run 'claude-docs.sh update'" >&2
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
        echo "" >&2
    fi
}

# Check if documentation has been downloaded
check_docs_exist() {
    if [[ ! -d "$DOCS_DIR" ]] || [[ -z "$(ls -A "$DOCS_DIR" 2>/dev/null | grep -v '^\.')" ]]; then
        log_error "No documentation found!"
        echo ""
        log_info "Documentation has not been downloaded yet."
        log_info "To download the documentation, run:"
        echo ""
        echo "    $SCRIPT_NAME update"
        echo ""
        log_info "This will download all Claude Code documentation to ~/.claude/docs/"
        exit 1
    fi
}

# ============================================================================
# Document Processing Helper Functions
# ============================================================================

# Generate GitHub-style anchor slug from heading text
generate_slug() {
    local text="$1"

    # Convert to lowercase and replace spaces with hyphens
    local slug=$(echo "$text" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

    # Remove special characters except hyphens and underscores
    slug=$(echo "$slug" | sed 's/[^a-z0-9_-]//g')

    # Remove duplicate hyphens
    slug=$(echo "$slug" | sed 's/--\+/-/g')

    # Trim leading/trailing hyphens
    slug=$(echo "$slug" | sed 's/^-\+//; s/-\+$//')

    echo "$slug"
}

# Extract all headings from a file with their level and line number
extract_headings() {
    local file="$1"

    grep -n '^#\{1,6\} ' "$file" | while IFS=: read -r line_num line_content; do
        # Count heading level (number of # characters)
        local level=$(echo "$line_content" | sed 's/^\(#\+\).*/\1/' | wc -c)
        level=$((level - 1))  # Subtract 1 for newline

        # Extract heading text (remove leading # and spaces)
        local text=$(echo "$line_content" | sed 's/^#\+ *//')

        echo "$line_num|$level|$text"
    done
}

# Generate table of contents for a single document
generate_doc_toc() {
    local file="$1"
    local filename=$(basename "$file")
    local slug_name="${filename%.md}"

    # Get the first heading to show in header
    local first_heading=$(grep -m 1 "^# " "$file" | sed 's/^# //')

    echo "# Index of ${first_heading} (${slug_name})"
    echo ""

    local first_line=true
    extract_headings "$file" | while IFS='|' read -r line_num level text; do
        # Skip the first heading (level 1)
        if [[ "$first_line" == "true" ]]; then
            first_line=false
            continue
        fi

        # Generate slug
        local slug=$(generate_slug "$text")

        # Calculate indentation (2 spaces per level, starting from level 2 as base)
        local indent_count=$(( (level - 2) * 2 ))
        local indent=$(printf '%*s' "$indent_count" '')

        # Output TOC line with CLI command syntax
        echo "${indent}- ${text} - Read with \`${SCRIPT_NAME} get ${slug_name}#${slug}\`"
    done
}

# Extract section content by anchor (includes subsections)
extract_section() {
    local file="$1"
    local anchor="$2"

    awk -v anchor="$anchor" '
        BEGIN { found=0; in_section=0; section_level=0 }

        # Match heading lines (any level)
        /^#/ {
            # Generate slug from current heading
            heading_text = $0
            gsub(/^#+ */, "", heading_text)
            slug = tolower(heading_text)
            gsub(/ /, "-", slug)
            gsub(/[^a-z0-9_-]/, "", slug)
            gsub(/--+/, "-", slug)
            gsub(/^-+/, "", slug)
            gsub(/-+$/, "", slug)

            if (slug == anchor) {
                found=1
                in_section=1
                # Determine heading level
                match($0, /^#+/)
                section_level=RLENGTH
                print
                next
            }

            if (found && in_section) {
                # Check if this is a same-level or higher heading
                match($0, /^#+/)
                if (RLENGTH <= section_level) {
                    exit
                }
                # Still in subsection, print the heading
                print
                next
            }
        }

        # Print non-heading lines when in section
        in_section { print }
    ' "$file"
}

# Replace /en/<slug> links with CLI command references (on-the-fly)
replace_links_live() {
    local script_name="$1"

    sed -E "
        # Pattern: [Link Text](/en/slug) -> Link Text - Read the doc with \`script get slug\`
        s|\[([^]]+)\]\(/en/([^#)]+)\)|\1 - Read the doc with \`${script_name} get \2\`|g

        # Pattern: [Link Text](/en/slug#anchor) -> Link Text - Read section with \`script get slug#anchor\`
        s|\[([^]]+)\]\(/en/([^#)]+)#([^)]+)\)|\1 - Read section with \`${script_name} get \2#\3\`|g
    "
}

# Get document or section with full transformation pipeline
get_doc() {
    local slug="$1"
    local section=""

    # Parse slug#anchor format
    if [[ "$slug" == *"#"* ]]; then
        section="${slug#*#}"
        slug="${slug%%#*}"
    fi

    local file="${DOCS_DIR}/${slug}.md"

    if [[ ! -f "$file" ]]; then
        # Check if it's a known missing document
        if [[ -f "$MISSING_DOCS_FILE" ]] && grep -q "^${slug}|" "$MISSING_DOCS_FILE" 2>/dev/null; then
            local missing_url=$(grep "^${slug}|" "$MISSING_DOCS_FILE" | cut -d'|' -f2)
            log_error "Documentation unavailable: $slug" >&2
            echo "" >&2
            log_warn "This section could not be downloaded from the official docs" >&2
            echo "" >&2
            echo "URL attempted: ${missing_url}.md" >&2
            echo "" >&2
            log_info "Possible reasons:" >&2
            echo "  - Section was renamed or removed" >&2
            echo "  - URL in claude-docs-urls.json is incorrect" >&2
            echo "  - Network/server issue" >&2
            echo "" >&2
            log_info "To fix: Update the URL in claude-docs-urls.json (line $(grep -n "\"${url}\"" "$JSON_FILE" | cut -d: -f1 | head -1))" >&2
            echo "Then run: $SCRIPT_NAME update" >&2
        else
            log_error "Document not found: $slug" >&2
            log_info "Available docs:" >&2
            ls -1 "${DOCS_DIR}"/*.md 2>/dev/null | xargs -n1 basename | sed 's/.md$//' | grep -v "CHANGELOG\|INDEX" | column >&2 || true
        fi
        return 1
    fi

    if [[ -n "$section" ]]; then
        # Special handling for mcp.md: must transform full file first, then extract
        if [[ "$slug" == "mcp" ]]; then
            cat "$file" | apply_markdown_pipeline "$SCRIPT_NAME" > /tmp/mcp-transformed-$$.md
            extract_section /tmp/mcp-transformed-$$.md "$section"
            rm -f /tmp/mcp-transformed-$$.md
        else
            # Extract specific section and apply pipeline
            extract_section "$file" "$section" | apply_markdown_pipeline "$SCRIPT_NAME"
        fi
    else
        # Show entire document with pipeline transformations
        cat "$file" | apply_markdown_pipeline "$SCRIPT_NAME"
    fi
}

# ============================================================================
# MARKDOWN TRANSFORMATION PIPELINE
# ============================================================================

# Transform MDX callout blocks (<Note>, <Tip>, <Warning>) to blockquotes
transform_mdx_callouts() {
    awk '
        /<Note>/ {
            in_note=1
            skip_redundant_label=1
            print ""
            print "> **📝 Note:**  "
            next
        }
        /<\/Note>/ {
            in_note=0
            skip_redundant_label=0
            print ""
            next
        }

        /<Tip>/ {
            in_tip=1
            skip_redundant_label=1
            print ""
            print "> **💡 Tip:**  "
            next
        }
        /<\/Tip>/ {
            in_tip=0
            skip_redundant_label=0
            print ""
            next
        }

        /<Warning>/ {
            in_warn=1
            skip_redundant_label=1
            print ""
            print "> **⚠️ Warning:**  "
            next
        }
        /<\/Warning>/ {
            in_warn=0
            skip_redundant_label=0
            print ""
            next
        }

        in_note || in_tip || in_warn {
            # Trim leading whitespace
            gsub(/^[[:space:]]*/, "")

            # Skip redundant labels like "Tips:" "Notes:" "Warning:" at the start
            if (skip_redundant_label && ($0 ~ /^(Tips?|Notes?|Warnings?):$/)) {
                next
            }

            # Skip blank line immediately after redundant label
            if (skip_redundant_label && length($0) == 0) {
                skip_redundant_label=0
                next
            }
            skip_redundant_label=0

            # Add blockquote prefix if line has content
            if (length($0) > 0) {
                print "> " $0
            } else {
                print ">"
            }
            next
        }

        { print }
    '
}

# Transform <CardGroup> and <Card> elements to bullet list
transform_mdx_cards() {
    awk -v script="$SCRIPT_NAME" '
        /<CardGroup>/ {
            in_cards=1
            print ""
            print "## Related Documentation"
            print ""
            next
        }
        /<\/CardGroup>/ {
            in_cards=0
            print ""
            next
        }

        in_cards && /<Card / {
            # Extract title attribute
            if (match($0, /title="([^"]*)"/, arr)) {
                title = arr[1]
            }

            # Extract href attribute
            if (match($0, /href="([^"]*)"/, arr)) {
                href = arr[1]
                # Remove /en/ prefix
                gsub(/^\/en\//, "", href)
            }

            if (title && href) {
                print "- **" title "** - Read with `" script " get " href "`"
            }

            in_card=1
            next
        }

        /<\/Card>/ {
            in_card=0
            next
        }

        # Skip content inside cards and between cards
        in_card { next }
        in_cards && !in_card { next }

        { print }
    '
}

# Transform <Tabs> and <Tab> elements to sections
transform_mdx_tabs() {
    awk '
        /<Tabs>/ {
            in_tabs=1
            print ""
            print "**Multiple options available:**"
            print ""
            next
        }
        /<\/Tabs>/ {
            in_tabs=0
            print ""
            next
        }

        in_tabs && /<Tab title="([^"]*)"/ {
            # Extract title
            if (match($0, /title="([^"]*)"/, arr)) {
                current_tab = arr[1]
                print "### Option: " current_tab
                print ""
            }
            in_tab=1
            next
        }

        /<\/Tab>/ {
            in_tab=0
            print ""
            next
        }

        # Print tab content
        in_tab { print; next }

        # Skip whitespace between tabs
        in_tabs && !in_tab && /^[[:space:]]*$/ { next }

        { print }
    '
}

# Transform <Steps> and <Step> elements to numbered list
transform_mdx_steps() {
    awk '
        /<Steps>/ {
            in_steps=1
            step_num=0
            print ""
            next
        }
        /<\/Steps>/ {
            in_steps=0
            print ""
            next
        }

        in_steps && /<Step title="([^"]*)"/ {
            step_num++
            # Extract title
            if (match($0, /title="([^"]*)"/, arr)) {
                print step_num ". **" arr[1] "**"
                print ""
            }
            in_step=1
            next
        }

        /<\/Step>/ {
            in_step=0
            print ""
            next
        }

        # Indent step content
        in_step {
            print "   " $0
            next
        }

        # Skip whitespace between steps
        in_steps && !in_step && /^[[:space:]]*$/ { next }

        { print }
    '
}

# Clean code block attributes (theme={null}, etc.)
transform_code_block_attrs() {
    sed -E '
        # Remove theme={null} and similar JSX attributes, preserving descriptive text
        # Pattern: ```lang [text] theme={null} → ```lang [text]
        s/(```[a-z]+[[:space:]]+.*)[[:space:]]+theme=\{[^}]+\}/\1/g

        # Remove theme={null} when no descriptive text
        # Pattern: ```lang  theme={null} → ```lang
        s/```([a-z]+)[[:space:]]+theme=\{[^}]+\}/```\1/g

        # Remove other JSX-style attributes like icon="..."
        s/(```[a-z]+[[:space:]]+.*)[[:space:]]+[a-zA-Z]+="[^"]*"/\1/g
        s/(```[a-z]+[[:space:]]+.*)[[:space:]]+[a-zA-Z]+=\{[^}]+\}/\1/g
    '
}

# Transform internal links to CLI commands (renamed from replace_links_live)
transform_links_to_cli() {
    local script_name="$1"

    sed -E "
        # Pattern: [Link Text](/en/slug) -> Link Text - Read with \`script get slug\`
        s|\[([^]]+)\]\(/en/([^#)]+)\)|\1 - Read with \`${script_name} get \2\`|g

        # Pattern: [Link Text](/en/slug#anchor) -> Link Text - Read with \`script get slug#anchor\`
        s|\[([^]]+)\]\(/en/([^#)]+)#([^)]+)\)|\1 - Read with \`${script_name} get \2#\3\`|g
    "
}

# Transform MCP servers component (mcp.md specific)
# Removes JavaScript component and generates markdown table from embedded JSON
transform_mcp_component() {
    local temp_input=$(mktemp)
    local temp_js=$(mktemp)
    local temp_table=$(mktemp)

    # Save stdin
    cat > "$temp_input"

    # Extract JavaScript servers array if Node.js is available
    if command -v node &>/dev/null; then
        # Extract and wrap for Node.js
        awk '/const servers = \[\{/,/^  \}\];$/' "$temp_input" | \
            sed '1s/const servers = /module.exports = /' > "$temp_js"

        # Generate markdown table with Node.js
        if [[ -s "$temp_js" ]]; then
            TEMP_JS="$temp_js" node << 'NODESCRIPT' > "$temp_table" 2>/dev/null
const servers = require(process.env.TEMP_JS);
console.log('### Available MCP Servers\n');
console.log('| Name | Category | Description | Install Command |');
console.log('|------|----------|-------------|-----------------|');
servers
    .filter(s => s.availability && s.availability.claudeCode)
    .forEach(s => {
        // Determine install command
        let cmd = '';
        if (s.customCommands && s.customCommands.claudeCode) {
            cmd = s.customCommands.claudeCode;
        } else if (s.urls.http) {
            const slug = s.name.toLowerCase().replace(/[^a-z0-9]/g, '-');
            cmd = `claude mcp add --transport http ${slug} ${s.urls.http}`;
        } else if (s.urls.sse) {
            const slug = s.name.toLowerCase().replace(/[^a-z0-9]/g, '-');
            cmd = `claude mcp add --transport sse ${slug} ${s.urls.sse}`;
        } else if (s.urls.stdio) {
            const slug = s.name.toLowerCase().replace(/[^a-z0-9]/g, '-');
            cmd = `claude mcp add --transport stdio ${slug} -- ${s.urls.stdio}`;
        } else {
            cmd = 'See documentation';
        }

        console.log('| ' + s.name + ' | ' + s.category + ' | ' + s.description + ' | `' + cmd + '` |');
    });
console.log('');
NODESCRIPT
        fi
    fi

    # Transform document: remove component and inject table at render tag
    awk -v table_file="$temp_table" '
        # Skip JavaScript component entirely
        /^export const MCPServersTable/ { in_comp=1; next }
        in_comp && /^};$/ { in_comp=0; next }
        in_comp { next }

        # Replace render tag with generated table
        /<MCPServersTable/ {
            if (table_file) {
                while ((getline line < table_file) > 0) {
                    print line
                }
                close(table_file)
            }
            next
        }

        # Print everything else
        { print }
    ' "$temp_input"

    rm -f "$temp_input" "$temp_js" "$temp_table"
}

# Remove excessive blank lines (collapse multiple blank lines to single)
transform_remove_excess_newlines() {
    cat -s
}

# Master pipeline: Apply all transformations in sequence
apply_markdown_pipeline() {
    local script_name="$1"

    # Chain all transformations via pipes
    # Order matters: clean MDX first, then MCP component, then links, finally cleanup
    transform_mdx_callouts \
        | transform_mdx_cards \
        | transform_mdx_tabs \
        | transform_mdx_steps \
        | transform_mcp_component \
        | transform_code_block_attrs \
        | transform_links_to_cli "$script_name" \
        | transform_remove_excess_newlines
}

# ============================================================================
# End Markdown Transformation Pipeline
# ============================================================================

# ============================================================================
# CACHING SYSTEM
# ============================================================================

# Generate cache key from slug (handles slug#anchor format)
generate_cache_key() {
    local input="$1"
    local slug section cache_key

    if [[ "$input" == *"#"* ]]; then
        section="${input#*#}"
        slug="${input%%#*}"
        # Sanitize anchor: replace special chars with underscore
        section=$(echo "$section" | sed 's/[^a-z0-9_-]/_/g')
        cache_key="${slug}__${section}"
    else
        cache_key="$input"
    fi

    echo "$cache_key"
}

# Validate cache file structure
validate_cache() {
    local cache_file="$1"

    # Check readable
    [[ -r "$cache_file" ]] || return 1

    # Check metadata line format
    local meta_line=$(head -n1 "$cache_file" 2>/dev/null)
    [[ "$meta_line" =~ ^#\ Cache\ metadata:\ v[0-9]+\| ]] || return 1

    # Check minimum size (metadata + content)
    local size=$(stat -c %s "$cache_file" 2>/dev/null || echo 0)
    [[ $size -gt 50 ]] || return 1

    return 0
}

# Check if cache is valid for a document
is_cache_valid() {
    local slug="$1"
    local cache_file="$2"

    # Extract base slug (without anchor)
    local base_slug="${slug%%#*}"
    local source_file="${DOCS_DIR}/${base_slug}.md"

    # Cache doesn't exist
    [[ -f "$cache_file" ]] || return 1

    # Source file doesn't exist
    [[ -f "$source_file" ]] || return 1

    # Source newer than cache
    [[ "$source_file" -nt "$cache_file" ]] && return 1

    # Validate cache structure
    validate_cache "$cache_file" || return 1

    # Check version match
    local meta_line=$(head -n1 "$cache_file")
    local cache_ver=$(echo "$meta_line" | grep -oP 'v\d+' || echo "v0")
    [[ "$cache_ver" == "$CACHE_VERSION" ]] || return 1

    return 0
}

# Update cache statistics
update_cache_stats() {
    local event="$1"  # "hit" or "miss"
    local meta_file="${CACHE_DIR}/__meta__.json"

    # Ensure cache directory exists
    mkdir -p "$CACHE_DIR" 2>/dev/null || return 0

    # Initialize if doesn't exist
    if [[ ! -f "$meta_file" ]]; then
        echo '{"version":"'"$CACHE_VERSION"'","stats":{"hits":0,"misses":0}}' > "$meta_file" 2>/dev/null || return 0
    fi

    # Update stats
    local temp_meta=$(mktemp)
    if [[ "$event" == "hit" ]]; then
        jq '.stats.hits += 1' "$meta_file" > "$temp_meta" 2>/dev/null && mv "$temp_meta" "$meta_file" || rm -f "$temp_meta"
    else
        jq '.stats.misses += 1' "$meta_file" > "$temp_meta" 2>/dev/null && mv "$temp_meta" "$meta_file" || rm -f "$temp_meta"
    fi
}

# Cached version of get_doc
get_doc_cached() {
    local slug="$1"
    local no_cache="${2:-false}"

    local cache_key=$(generate_cache_key "$slug")
    local cache_file="${CACHE_DIR}/${cache_key}.cache"

    # Use cache if valid and not disabled
    if [[ "$no_cache" == "false" ]] && is_cache_valid "$slug" "$cache_file"; then
        update_cache_stats "hit"
        tail -n +2 "$cache_file"  # Skip metadata line
        return 0
    fi

    # Cache miss - generate content
    update_cache_stats "miss"

    local temp_output=$(mktemp)
    if get_doc "$slug" > "$temp_output" 2>&1; then
        # Ensure cache directory exists
        mkdir -p "$CACHE_DIR" 2>/dev/null || true

        # Write cache with metadata (ignore write errors)
        {
            echo "# Cache metadata: ${CACHE_VERSION}|${slug}|$(date +%s)"
            cat "$temp_output"
        } > "$cache_file" 2>/dev/null || true

        cat "$temp_output"
        rm -f "$temp_output"
        return 0
    else
        local exit_code=$?
        rm -f "$temp_output"
        return $exit_code
    fi
}

# Cached version of list_docs
list_docs_cached() {
    local slug="${1:-}"
    local no_cache="${2:-false}"

    local cache_key
    if [[ -n "$slug" ]]; then
        cache_key="${slug}__toc__"
    else
        cache_key="__index__"
    fi

    local cache_file="${CACHE_DIR}/${cache_key}.cache"

    # For index, check if ANY doc is newer
    if [[ -z "$slug" ]] && [[ "$no_cache" == "false" ]] && [[ -f "$cache_file" ]]; then
        # Check version
        local meta_line=$(head -n1 "$cache_file")
        local cache_ver=$(echo "$meta_line" | grep -oP 'v\d+' || echo "v0")

        if [[ "$cache_ver" == "$CACHE_VERSION" ]]; then
            # Check if any doc is newer than cache
            local any_newer=$(find "$DOCS_DIR" -name "*.md" -type f -newer "$cache_file" 2>/dev/null | head -1)

            if [[ -z "$any_newer" ]] && validate_cache "$cache_file"; then
                update_cache_stats "hit"
                tail -n +2 "$cache_file"
                return 0
            fi
        fi
    elif [[ -n "$slug" ]] && [[ "$no_cache" == "false" ]] && is_cache_valid "$slug" "$cache_file"; then
        # For doc structure, use normal validation
        update_cache_stats "hit"
        tail -n +2 "$cache_file"
        return 0
    fi

    # Cache miss
    update_cache_stats "miss"

    local temp_output=$(mktemp)
    if list_docs "$slug" > "$temp_output" 2>&1; then
        # Ensure cache directory exists
        mkdir -p "$CACHE_DIR" 2>/dev/null || true

        # Write cache
        {
            echo "# Cache metadata: ${CACHE_VERSION}|${slug:-index}|$(date +%s)"
            cat "$temp_output"
        } > "$cache_file" 2>/dev/null || true

        cat "$temp_output"
        rm -f "$temp_output"
        return 0
    else
        local exit_code=$?
        rm -f "$temp_output"
        return $exit_code
    fi
}

# Cache management: clear
cache_clear() {
    local pattern="${1:-*}"

    if [[ "$pattern" == "*" ]]; then
        log_info "Clearing entire cache..."
        rm -f "${CACHE_DIR}"/*.cache 2>/dev/null || true
        rm -f "${CACHE_DIR}/__meta__.json" 2>/dev/null || true
        log_success "Cache cleared"
    else
        log_info "Clearing cache for: $pattern"
        rm -f "${CACHE_DIR}/${pattern}"*.cache 2>/dev/null || true
        log_success "Cache cleared for $pattern"
    fi
}

# Cache management: info
cache_info() {
    if [[ ! -d "$CACHE_DIR" ]]; then
        log_info "Cache directory does not exist"
        return
    fi

    local total_files=$(find "$CACHE_DIR" -name "*.cache" -type f 2>/dev/null | wc -l)
    local total_size=$(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1)

    echo "Cache Statistics"
    echo "================"
    echo "Cached items: $total_files"
    echo "Total size:   $total_size"
    echo ""

    # Load stats from metadata
    if [[ -f "${CACHE_DIR}/__meta__.json" ]]; then
        local hits=$(jq -r '.stats.hits // 0' "${CACHE_DIR}/__meta__.json" 2>/dev/null)
        local misses=$(jq -r '.stats.misses // 0' "${CACHE_DIR}/__meta__.json" 2>/dev/null)
        local total=$((hits + misses))

        if [[ $total -gt 0 ]]; then
            local hit_rate=$(awk "BEGIN {printf \"%.1f\", ($hits/$total)*100}")
            echo "Cache hits:   $hits"
            echo "Cache misses: $misses"
            echo "Hit rate:     ${hit_rate}%"
            echo ""
        fi
    fi

    # Show largest cache files
    echo "Largest cache files:"
    find "$CACHE_DIR" -name "*.cache" -type f -exec ls -lh {} \; 2>/dev/null | \
        awk '{print $5"\t"$9}' | \
        sort -rh | \
        head -10 | \
        sed 's|.*/||' || echo "  (none)"
}

# Cache management: warm (pre-generate all caches)
cache_warm() {
    log_info "Warming cache for all documentation..."

    local total_docs
    total_docs=$(jq -r '[.categories[].docs[]] | length' "$JSON_FILE")

    echo -n "Caching $total_docs sections: "

    local count=0
    local cached=0

    # Cache each document
    jq -r '.categories[].docs[] | @json' "$JSON_FILE" > /tmp/docs-warm.tmp
    while IFS= read -r doc; do
        local filename
        filename=$(echo "$doc" | jq -r '.filename')
        local slug="${filename%.md}"

        # Cache full document
        if get_doc_cached "$slug" "false" >/dev/null 2>&1; then
            cached=$((cached + 1))
        fi

        # Cache document structure (list output)
        list_docs_cached "$slug" "false" >/dev/null 2>&1 || true

        # Progress indicator
        count=$((count + 1))
        if (( count % 2 == 0 )); then
            echo -n "."
        fi
    done < /tmp/docs-warm.tmp
    rm -f /tmp/docs-warm.tmp

    # Cache full index
    list_docs_cached "" "false" >/dev/null 2>&1 || true

    echo " Done"
    log_success "Cached $cached sections"
}

# Ensure cache is warm for search (validate and warm missing)
ensure_cache_warm() {
    local total_docs
    total_docs=$(jq -r '[.categories[].docs[]] | length' "$JSON_FILE")

    local missing=0

    # Check each document cache
    jq -r '.categories[].docs[] | @json' "$JSON_FILE" > /tmp/docs-check.tmp
    while IFS= read -r doc; do
        local filename
        filename=$(echo "$doc" | jq -r '.filename')
        local slug="${filename%.md}"
        local source_file="${DOCS_DIR}/${slug}.md"

        # Skip if source document doesn't exist (not downloaded)
        [[ -f "$source_file" ]] || continue

        local cache_key=$(generate_cache_key "$slug")
        local cache_file="${CACHE_DIR}/${cache_key}.cache"

        # Check if cache valid
        if ! is_cache_valid "$slug" "$cache_file"; then
            missing=$((missing + 1))
        fi
    done < /tmp/docs-check.tmp
    rm -f /tmp/docs-check.tmp

    # Warm missing caches (silently if all cached)
    if [[ $missing -gt 0 ]]; then
        log_info "Warming $missing missing cache entries..." >&2
        cache_warm >/dev/null 2>&1
    fi
}

# Search documentation
search_docs() {
    local query="$1"

    if [[ -z "$query" ]]; then
        log_error "Search query required"
        log_info "Usage: $SCRIPT_NAME search '<query>'"
        return 1
    fi

    # Ensure cache is ready for search
    ensure_cache_warm

    log_info "Searching for: $query" >&2
    echo "" >&2

    # Search in all cached documents
    local temp_results=$(mktemp)
    local temp_caches=$(mktemp)

    # Build list of cache files to search (exclude special caches)
    for cache_file in "$CACHE_DIR"/*.cache; do
        [[ -f "$cache_file" ]] || continue
        local cache_name=$(basename "$cache_file" .cache)
        [[ "$cache_name" == "__"* ]] && continue
        [[ "$cache_name" == *"__toc__" ]] && continue
        echo "$cache_file"
    done > "$temp_caches"

    # Search all caches with grep (with filename and line number)
    if [[ -s "$temp_caches" ]]; then
        # Use xargs with grep for better performance
        cat "$temp_caches" | xargs grep -n -i -H "$query" 2>/dev/null | while IFS=: read -r cache_file line_num line_content; do
            # Skip metadata lines
            [[ "$line_num" == "1" ]] && continue

            local cache_name=$(basename "$cache_file" .cache)
            local slug="${cache_name%%__*}"

            # Adjust line number (subtract 1 for metadata line)
            local actual_line=$((line_num - 1))

            echo "$slug|$actual_line|$line_content"
        done > "$temp_results"
    fi

    rm -f "$temp_caches"

    # Count total matches
    local total_matches=0
    if [[ -f "$temp_results" && -s "$temp_results" ]]; then
        total_matches=$(wc -l < "$temp_results")
    fi

    # Format output based on match count
    if [[ $total_matches -eq 0 ]]; then
        log_info "No matches found for: $query" >&2
        rm -f "$temp_results"
        return 1
    elif [[ $total_matches -gt 10 ]]; then
        # Too many matches - show summary only
        echo "=== SEARCH RESULTS: $total_matches matches (too many, showing summary) ==="
        echo ""
        echo "Found in these sections:"
        echo ""

        awk -F'|' '{print $1"|"$2}' "$temp_results" | \
            awk -F'|' '{count[$1]++; lines[$1]=lines[$1]","$2} END {
                for (slug in count) {
                    gsub(/^,/, "", lines[slug])
                    print "  " slug " (" count[slug] " matches) - lines: " lines[slug]
                }
            }' | sort

        echo ""
        echo "Refine your search to see detailed results (limit: 10 matches)"
    else
        # Show detailed results with context
        echo "=== SEARCH RESULTS: $total_matches matches ==="
        echo ""

        while IFS='|' read -r slug line_num match_line; do
            local cache_file="${CACHE_DIR}/${slug}.cache"

            echo "--- $slug (line $line_num) ---"

            # Show context: -5 to +5 lines (in content, not including metadata)
            local start_line=$((line_num - 5))
            local end_line=$((line_num + 5))
            [[ $start_line -lt 1 ]] && start_line=1

            # Extract from cache file (line numbers include metadata at line 1)
            # So content line N is at cache file line N+1
            local cache_start=$((start_line + 1))
            local cache_end=$((end_line + 1))

            # Extract and number starting from start_line (number all lines including blank)
            sed -n "${cache_start},${cache_end}p" "$cache_file" | nl -ba -v "$start_line" -w 4 -s ': '

            echo ""
        done < "$temp_results"
    fi

    rm -f "$temp_results"
}

# ============================================================================
# End Caching System
# ============================================================================

# ============================================================================
# UPDATE TRACKING
# ============================================================================

# Mark last update timestamp
mark_last_update() {
    date +%s > "$LAST_UPDATE_FILE" 2>/dev/null || true
}

# Check if update is needed (>24 hours old)
check_update_needed() {
    # Skip check for update commands themselves
    local command="$1"
    [[ "$command" =~ ^update ]] && return 0

    # Check if last update file exists
    if [[ ! -f "$LAST_UPDATE_FILE" ]]; then
        return 0  # First run, don't nag
    fi

    local last_update
    last_update=$(cat "$LAST_UPDATE_FILE" 2>/dev/null || echo "0")
    last_update=${last_update:-0}  # Ensure it's a number

    local now=$(date +%s)
    local age=$((now - last_update))
    local hours=$((age / 3600))

    # Warn if older than 24 hours
    if [[ $hours -gt 24 ]]; then
        echo "" >&2
        log_warn "Documentation not updated in $hours hours" >&2
        log_info "Run: $SCRIPT_NAME update" >&2
        echo "" >&2
    fi
}

# ============================================================================
# End Update Tracking
# ============================================================================

# Ensure required directories exist
init_dirs() {
    mkdir -p "${DOCS_DIR}" "${CACHE_DIR}" "${DIFF_DIR}"
    if [[ ! -f "${CHANGELOG_FILE}" ]]; then
        cat > "${CHANGELOG_FILE}" << 'EOF'
# Claude Code Documentation Changelog

This file tracks all changes to the Claude Code documentation over time.

---

EOF
    fi
}

# Check dependencies
check_deps() {
    local missing_deps=()

    for cmd in curl jq diff; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_info "Please install: sudo apt-get install curl jq diffutils"
        exit 1
    fi
}

# Convert urls.md to JSON structure
convert_urls_to_json() {
    local input_file="${1:-urls.md}"
    local output_file="${2:-claude-docs-urls.json}"

    if [[ ! -f "$input_file" ]]; then
        log_error "Input file not found: $input_file"
        exit 1
    fi

    log_info "Converting $input_file to $output_file"
    log_warn "JSON structure already exists at: $JSON_FILE"
    log_info "Use the existing JSON file for full hierarchy and descriptions"
}

# Download a single document
download_doc() {
    local url="$1"
    local output_file="$2"
    local temp_file="${3:-}"

    local md_url="${url}.md"
    local final_output="${output_file}"

    if [[ -n "$temp_file" ]]; then
        final_output="$temp_file"
    fi

    log_info "Downloading: $md_url"

    # Retry up to 3 times with 2 second delay
    local max_retries=3
    local retry_delay=2

    for attempt in $(seq 1 $max_retries); do
        if curl -sf "$md_url" -o "$final_output"; then
            log_success "Downloaded: $(basename "$output_file")"
            return 0
        fi

        if [[ $attempt -lt $max_retries ]]; then
            log_warn "Download failed (attempt $attempt/$max_retries), retrying in ${retry_delay}s..."
            sleep $retry_delay
        fi
    done

    log_error "Failed to download after $max_retries attempts: $md_url"
    return 1
}

# Download all documents from JSON
update_check() {
    if [[ ! -f "$JSON_FILE" ]]; then
        log_error "JSON file not found: $JSON_FILE"
        exit 1
    fi

    init_dirs

    local pending_dir="${DOCS_DIR}/.pending"

    # Check if pending update already exists
    if [[ -d "$pending_dir" ]]; then
        log_warn "Pending update already exists from: $(cat "${pending_dir}/timestamp" 2>/dev/null || echo 'unknown')"
        log_info "Overwriting pending update..."
        rm -rf "$pending_dir"
    fi

    # Create pending directory structure
    mkdir -p "${pending_dir}/downloads" "${pending_dir}/diffs"
    date -Iseconds > "${pending_dir}/timestamp"

    local total_docs
    total_docs=$(jq -r '[.categories[].docs[]] | length' "$JSON_FILE")

    echo -n "Checking $total_docs documents: "

    # Progress counter
    local count=0
    local docs_list="${pending_dir}/docs.tmp"

    # Generate list of docs to process
    jq -r '.categories[].docs[] | @json' "$JSON_FILE" > "$docs_list"

    # Process each document
    while IFS= read -r doc; do
        local url filename
        url=$(echo "$doc" | jq -r '.url')
        filename=$(echo "$doc" | jq -r '.filename')

        local pending_file="${pending_dir}/downloads/${filename}"
        local current_file="${DOCS_DIR}/${filename}"

        # Download to pending (suppress output)
        if download_doc "$url" "$current_file" "$pending_file" >/dev/null 2>&1; then
            # Compare with existing
            if [[ -f "$current_file" ]]; then
                if ! diff -q "$current_file" "$pending_file" > /dev/null 2>&1; then
                    # Generate diff
                    diff -u "$current_file" "$pending_file" > "${pending_dir}/diffs/${filename%.md}.diff" 2>&1 || true
                    echo "$filename" >> "${pending_dir}/changed.list"
                else
                    rm "$pending_file"
                fi
            else
                echo "$filename" >> "${pending_dir}/new.list"
                echo "NEW FILE" > "${pending_dir}/diffs/${filename%.md}.diff"
            fi
        else
            echo "$filename" >> "${pending_dir}/failed.list"
            # Track URL for missing docs file
            echo "${filename%.md}|${url}" >> "${pending_dir}/missing-urls.tmp"
        fi

        # Progress indicator (dot every 2 files)
        count=$((count + 1))
        if (( count % 2 == 0 )); then
            echo -n "."
        fi
    done < "$docs_list"

    rm -f "$docs_list"
    echo " Done"

    # Update missing docs file
    if [[ -f "${pending_dir}/missing-urls.tmp" ]]; then
        mv "${pending_dir}/missing-urls.tmp" "$MISSING_DOCS_FILE"
    else
        # No failures - clear missing docs file
        rm -f "$MISSING_DOCS_FILE"
    fi

    # Generate summary
    generate_update_summary "$pending_dir"

    # Show results
    echo ""
    cat "${pending_dir}/summary.txt"

    # Show missing docs warning if any
    if [[ -f "$MISSING_DOCS_FILE" ]]; then
        echo ""
        show_missing_docs_warning
    fi

    # Check if any changes
    local new_count=0
    local changed_count=0
    [[ -f "${pending_dir}/new.list" ]] && new_count=$(wc -l < "${pending_dir}/new.list")
    [[ -f "${pending_dir}/changed.list" ]] && changed_count=$(wc -l < "${pending_dir}/changed.list")
    local total_changes=$((new_count + changed_count))

    if [[ $total_changes -eq 0 ]]; then
        log_success "All documentation is up to date!"
        rm -rf "$pending_dir"
        mark_last_update
        return 0
    fi

    # Show diffs for review
    echo ""
    echo "=== CHANGES DETECTED ==="
    echo ""

    # Show diffs for changed files
    if [[ -f "${pending_dir}/changed.list" ]]; then
        while IFS= read -r filename; do
            local slug="${filename%.md}"
            local diff_file="${pending_dir}/diffs/${slug}.diff"

            if [[ -f "$diff_file" ]]; then
                echo "--- Changes in: $slug ---"
                cat "$diff_file"
                echo ""
            fi
        done < "${pending_dir}/changed.list"
    fi

    # Show new files
    if [[ -f "${pending_dir}/new.list" ]]; then
        while IFS= read -r filename; do
            local slug="${filename%.md}"
            echo "--- New file: $slug ---"
            echo "(New file with $(wc -l < "${pending_dir}/downloads/$filename") lines)"
            echo ""
        done < "${pending_dir}/new.list"
    fi

    # Instructions for Claude Code
    echo "=== INSTRUCTIONS FOR CLAUDE CODE ==="
    echo ""
    echo "Review the changes above and decide:"
    echo ""
    echo "TO APPLY these changes:"
    echo "  Run: $SCRIPT_NAME update commit '<descriptive changelog message>'"
    echo "  Example: $SCRIPT_NAME update commit 'Updated MCP server list with new integrations'"
    echo ""
    echo "The changelog message should:"
    echo "  - Describe what changed and why (10-1000 characters)"
    echo "  - Be specific and descriptive"
    echo "  - Sections will be auto-detected from staged changes"
    echo ""
    echo "TO DISCARD these changes:"
    echo "  Run: $SCRIPT_NAME update discard"
    echo ""
    log_warn "Changes are staged in ${pending_dir}/ but NOT applied yet"
}

generate_update_summary() {
    local pending_dir="$1"
    local summary_file="${pending_dir}/summary.txt"

    {
        echo "=== UPDATE SUMMARY ==="
        echo "Date: $(cat "${pending_dir}/timestamp")"
        echo ""

        # Changed documentation
        if [[ -f "${pending_dir}/changed.list" ]]; then
            local count=$(wc -l < "${pending_dir}/changed.list")
            echo "CHANGED: $count sections"
            while IFS= read -r filename; do
                local slug="${filename%.md}"
                local diff_file="${pending_dir}/diffs/${slug}.diff"
                if [[ -f "$diff_file" ]]; then
                    local adds=$(grep -c "^+" "$diff_file" 2>/dev/null || echo 0)
                    local dels=$(grep -c "^-" "$diff_file" 2>/dev/null || echo 0)
                    echo "  ~ $slug  (+$adds, -$dels)"
                fi
            done < "${pending_dir}/changed.list"
            echo ""
        fi

        # New documentation
        if [[ -f "${pending_dir}/new.list" ]]; then
            local count=$(wc -l < "${pending_dir}/new.list")
            echo "NEW: $count sections"
            while IFS= read -r filename; do
                local slug="${filename%.md}"
                local lines=$(wc -l < "${pending_dir}/downloads/$filename" 2>/dev/null || echo 0)
                echo "  + $slug  ($lines lines)"
            done < "${pending_dir}/new.list"
            echo ""
        fi

        # Failed downloads
        if [[ -f "${pending_dir}/failed.list" ]]; then
            local count=$(wc -l < "${pending_dir}/failed.list")
            echo "FAILED: $count sections"
            while IFS= read -r filename; do
                local slug="${filename%.md}"
                echo "  ✗ $slug  (download failed - check URL in claude-docs-urls.json)"
            done < "${pending_dir}/failed.list"
            echo ""
        fi

        # Unchanged
        local total=$(jq -r '[.categories[].docs[]] | length' "$JSON_FILE")
        local changed=0
        local new=0
        local failed=0
        [[ -f "${pending_dir}/changed.list" ]] && changed=$(wc -l < "${pending_dir}/changed.list")
        [[ -f "${pending_dir}/new.list" ]] && new=$(wc -l < "${pending_dir}/new.list")
        [[ -f "${pending_dir}/failed.list" ]] && failed=$(wc -l < "${pending_dir}/failed.list")
        local unchanged=$((total - changed - new - failed))
        echo "UNCHANGED: $unchanged sections"

    } > "$summary_file"
}

# Validate changelog message
validate_changelog_message() {
    local text="$1"

    # Empty check
    if [[ -z "$text" ]]; then
        log_error "Changelog message cannot be empty"
        log_info "Usage: $SCRIPT_NAME update-commit '<description>'"
        return 1
    fi

    # Length check
    local length=${#text}
    if [[ $length -lt 10 ]]; then
        log_error "Changelog too short (min 10 chars, got $length)"
        log_info "Provide a descriptive message"
        return 1
    fi

    if [[ $length -gt 1000 ]]; then
        log_error "Changelog too long (max 1000 chars, got $length)"
        return 1
    fi

    # Avoid lazy messages
    if [[ "$text" =~ ^(update|fix|change)$ ]]; then
        log_error "Changelog too vague: '$text'"
        log_info "Be specific about what changed"
        return 1
    fi

    return 0
}

# Apply pending update with changelog
update_commit() {
    local changelog_text="$*"
    local pending_dir="${DOCS_DIR}/.pending"

    # Validate pending exists
    if [[ ! -d "$pending_dir" ]]; then
        log_error "No pending update found"
        log_info "Run '$SCRIPT_NAME update' first to check for changes"
        return 1
    fi

    # Validate changelog
    if ! validate_changelog_message "$changelog_text"; then
        return 1
    fi

    # Warn about failures but don't block (they're tracked in .missing-docs)
    if [[ -f "${pending_dir}/failed.list" ]]; then
        local failed_count=$(wc -l < "${pending_dir}/failed.list")
        log_warn "Note: $failed_count section(s) failed to download (tracked in .missing-docs)"
        echo "These will be flagged as unavailable until URLs are fixed"
        echo ""
    fi

    # Show what will be applied
    echo ""
    cat "${pending_dir}/summary.txt"
    echo ""
    log_info "Applying changes..."

    # Apply changes: copy files
    local applied_count=0
    if [[ -d "${pending_dir}/downloads" ]]; then
        for file in "${pending_dir}/downloads"/*.md; do
            [[ -f "$file" ]] || continue
            local basename_file=$(basename "$file")
            cp "$file" "${DOCS_DIR}/${basename_file}"
            log_success "Applied: $basename_file"
            applied_count=$((applied_count + 1))
        done
    fi

    # Auto-detect changed files for changelog
    local files=""
    if [[ -f "${pending_dir}/changed.list" ]]; then
        files=$(cat "${pending_dir}/changed.list")
    fi
    if [[ -f "${pending_dir}/new.list" ]]; then
        files="${files}
$(cat "${pending_dir}/new.list")"
    fi

    # Add changelog entry with file list
    changelog_add "$changelog_text" "$files"

    # Clear old diffs (no longer needed after changelog created)
    rm -rf "$DIFF_DIR"/* 2>/dev/null || true

    # Clear cache (files changed)
    cache_clear "*" >/dev/null 2>&1

    # Remove pending
    rm -rf "$pending_dir"

    # Mark successful update
    mark_last_update

    log_success "Update applied: $applied_count sections"
    log_info "Changelog: $CHANGELOG_FILE"

    # Warm cache with updated documentation
    echo ""
    cache_warm
}

# Discard pending update
update_discard() {
    local pending_dir="${DOCS_DIR}/.pending"

    if [[ ! -d "$pending_dir" ]]; then
        log_info "No pending update to discard"
        return 0
    fi

    echo ""
    cat "${pending_dir}/summary.txt" 2>/dev/null || log_info "Pending update from: $(cat "${pending_dir}/timestamp" 2>/dev/null)"
    echo ""

    log_info "Discarding pending changes..."
    rm -rf "$pending_dir"
    log_success "Pending update discarded"
}

# Show pending update status
update_status() {
    local pending_dir="${DOCS_DIR}/.pending"

    # Show last update time
    if [[ -f "$LAST_UPDATE_FILE" ]]; then
        local last_update=$(cat "$LAST_UPDATE_FILE" 2>/dev/null || echo "0")
        local now=$(date +%s)
        local age=$((now - last_update))
        local hours=$((age / 3600))
        local days=$((hours / 24))

        echo "Last update check: $hours hours ago"
        if [[ $days -gt 0 ]]; then
            echo "  ($days days ago)"
        fi
        echo ""
    else
        echo "Last update check: Never"
        echo ""
    fi

    # Show pending changes if any
    if [[ ! -d "$pending_dir" ]]; then
        log_info "No pending updates"
        return 0
    fi

    cat "${pending_dir}/summary.txt" 2>/dev/null || {
        log_info "Pending update from: $(cat "${pending_dir}/timestamp" 2>/dev/null || echo 'unknown')"
    }
}

# List documentation files
list_docs() {
    local slug="${1:-}"

    if [[ ! -d "$DOCS_DIR" ]]; then
        log_error "Documentation directory not found: $DOCS_DIR" >&2
        log_info "Run '$SCRIPT_NAME download' first" >&2
        exit 1
    fi

    # If slug provided, show structure of that specific doc
    if [[ -n "$slug" ]]; then
        local file="${DOCS_DIR}/${slug}.md"
        if [[ ! -f "$file" ]]; then
            log_error "Document not found: $slug" >&2
            log_info "Available docs:" >&2
            ls -1 "${DOCS_DIR}"/*.md 2>/dev/null | xargs -n1 basename | sed 's/.md$//' | grep -v "CHANGELOG\|INDEX" | column >&2 || true
            return 1
        fi
        generate_doc_toc "$file"
        return 0
    fi

    # Otherwise show full list (existing behavior)
    if [[ ! -f "$JSON_FILE" ]]; then
        log_error "JSON file not found: $JSON_FILE" >&2
        exit 1
    fi

    # Output header
    echo "# Documentation List"
    echo ""
    echo "Below is a list of all available documentation"
    echo ""
    echo "**To see the structure of a specific document, run:** \`${SCRIPT_NAME} list <slug>\`"
    echo ""
    echo "**To read a document with replaced links, run:** \`${SCRIPT_NAME} get <slug>\`"
    echo ""
    echo "---"
    echo ""

    # Process each category
    jq -r '.categories[] | @json' "$JSON_FILE" | while IFS= read -r category; do
        local category_name
        category_name=$(echo "$category" | jq -r '.name')

        echo "## $category_name"
        echo ""
        echo "| Slug | Title | Description | Last updated |"
        echo "|------|-------|-------------|--------------|"

        # Process each doc in category
        echo "$category" | jq -r '.docs[] | @json' | while IFS= read -r doc; do
            local filename url
            filename=$(echo "$doc" | jq -r '.filename')
            url=$(echo "$doc" | jq -r '.url')

            # Extract slug from URL (last part after /)
            local slug
            slug=$(basename "$url")

            local file_path="${DOCS_DIR}/${filename}"

            if [[ -f "$file_path" ]]; then
                # Extract display name (first # heading)
                local display_name
                display_name=$(grep -m 1 "^# " "$file_path" | sed 's/^# //' || echo "")

                # Extract brief (first > quote)
                local brief
                brief=$(grep -m 1 "^> " "$file_path" | sed 's/^> //' || echo "")

                # Get file modification time
                local last_updated
                last_updated=$(date -r "$file_path" "+%d/%m-%Y %H:%M:%S" 2>/dev/null || echo "N/A")

                # Output table row
                echo "| $slug | $display_name | $brief | $last_updated |"
            else
                # Check if it's in the missing docs list
                if [[ -f "$MISSING_DOCS_FILE" ]] && grep -q "^${slug}|" "$MISSING_DOCS_FILE" 2>/dev/null; then
                    # Get URL from missing docs file
                    local missing_url=$(grep "^${slug}|" "$MISSING_DOCS_FILE" | cut -d'|' -f2)
                    echo "| $slug | ⚠️ UNAVAILABLE | Download failed - URL: ${missing_url}.md | |"
                else
                    # File not downloaded yet (initial state)
                    echo "| $slug | (not downloaded) | Run 'update' to download | |"
                fi
            fi
        done

        echo ""
    done
}

# Generate changelog from diffs
generate_changelog() {
    if [[ ! -d "$DIFF_DIR" ]]; then
        log_warn "No diffs directory found"
        return
    fi

    local diff_files
    diff_files=$(find "$DIFF_DIR" -name "*.diff" -type f 2>/dev/null || true)

    if [[ -z "$diff_files" ]]; then
        log_info "No diffs found to process"
        return
    fi

    log_info "Generating changelog from diffs..."

    local changes_text=""
    local changed_files=()

    while IFS= read -r diff_file; do
        local filename
        filename=$(basename "$diff_file" .diff)
        changed_files+=("${filename}.md")

        # Parse diff for changes
        local additions deletions
        additions=$(grep -c "^+" "$diff_file" || echo "0")
        deletions=$(grep -c "^-" "$diff_file" || echo "0")

        changes_text+="- **${filename}.md**: "

        if [[ $additions -gt 0 ]] && [[ $deletions -gt 0 ]]; then
            changes_text+="Updated content (+$additions lines, -$deletions lines)\n"
        elif [[ $additions -gt 0 ]]; then
            changes_text+="New content added (+$additions lines)\n"
        elif [[ $deletions -gt 0 ]]; then
            changes_text+="Content removed (-$deletions lines)\n"
        fi

    done <<< "$diff_files"

    # Create JSON for changelog add
    local json_payload
    json_payload=$(jq -n \
        --arg text "$changes_text" \
        --argjson files "$(printf '%s\n' "${changed_files[@]}" | jq -R . | jq -s .)" \
        '{text: $text, files: $files}')

    echo "$json_payload" | changelog_add_from_json
}

# Add changelog entry from JSON
changelog_add_from_json() {
    local json_input
    json_input=$(cat)

    # Validate JSON
    if ! echo "$json_input" | jq empty 2>/dev/null; then
        log_error "Invalid JSON input"
        return 1
    fi

    # Extract fields
    local text files
    text=$(echo "$json_input" | jq -r '.text // ""')
    files=$(echo "$json_input" | jq -r '.files // [] | .[]' 2>/dev/null || echo "")

    if [[ -z "$text" ]]; then
        log_error "JSON must contain 'text' field"
        return 1
    fi

    changelog_add "$text" "$files"
}

# Add changelog entry
changelog_add() {
    local body="$1"
    local files="${2:-}"

    init_dirs

    local current_date
    current_date=$(date +"%Y-%m-%d %H:%M:%S")

    # Create temp file with new entry
    local temp_changelog
    temp_changelog=$(mktemp)

    # Read existing changelog
    local existing_content
    if [[ -f "$CHANGELOG_FILE" ]]; then
        existing_content=$(cat "$CHANGELOG_FILE")
    else
        existing_content="# Claude Code Documentation Changelog\n\n---\n"
    fi

    # Build new entry
    {
        # Keep header
        echo "# Claude Code Documentation Changelog"
        echo ""
        echo "This file tracks all changes to the Claude Code documentation over time."
        echo ""
        echo "---"
        echo ""
        echo "## $current_date"
        echo ""
        echo -e "$body"

        if [[ -n "$files" ]]; then
            echo ""
            echo "**Files updated:**"
            echo "$files" | while IFS= read -r file; do
                if [[ -n "$file" ]]; then
                    echo "- \`$file\`"
                fi
            done
        fi
        echo ""
        echo "---"
        echo ""

        # Append existing entries (skip header)
        echo "$existing_content" | sed -n '/^## [0-9]/,$p'

    } > "$temp_changelog"

    # Replace changelog
    mv "$temp_changelog" "$CHANGELOG_FILE"

    log_success "Changelog updated: $CHANGELOG_FILE"
}

# Show help
show_help() {
    # Check if docs exist and show warning if not
    if [[ ! -d "$DOCS_DIR" ]] || [[ -z "$(ls -A "$DOCS_DIR" 2>/dev/null | grep -v '^\.')" ]]; then
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}⚠  WARNING: No documentation found!${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "Documentation has not been downloaded yet."
        echo "To download documentation, run:"
        echo ""
        echo "    $SCRIPT_NAME update"
        echo ""
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
    fi

    cat << 'EOF'
Claude Code Documentation Manager

USAGE:
    claude-docs.sh <command> [options]

COMMANDS:
    update              Check for documentation updates (first-time: downloads all docs)
                        Shows diffs and instructions, does NOT apply changes

    update commit       Apply staged updates with changelog
                        Usage: claude-docs.sh update commit '<description>'
                        Sections auto-detected, changelog auto-generated

    update discard      Discard pending updates

    update status       Show pending update status and last check time

    get <slug>          Get a document with transformations applied

    get <slug>#<anchor> Get a specific section from a document
                        Usage: claude-docs.sh get 'vs-code#using-third-party-providers'

    list                List all available documentation

    list <slug>         Show structure/outline of a specific document
                        Usage: claude-docs.sh list plugins

    search '<query>'    Search across all documentation
                        Shows matches with context (±5 lines)
                        Limit: 10 detailed results, summary if more

    cache clear         Clear cache
    cache info          Show cache statistics
    cache warm          Pre-generate cache for all documentation

    help                Show this help message

WORKFLOW:
    1. Check for updates:
       $ claude-docs.sh update
       (Shows diffs and instructions)

    2. Apply or discard:
       $ claude-docs.sh update commit 'Updated plugin examples and MCP servers'
       # OR
       $ claude-docs.sh update discard

EXAMPLES:
    # Check for updates
    claude-docs.sh update

    # Apply updates with changelog
    claude-docs.sh update commit 'Added new MCP integration guide'

    # View status and last check time
    claude-docs.sh update status

    # List all documentation
    claude-docs.sh list

    # Get a document
    claude-docs.sh get plugins

    # Get specific section
    claude-docs.sh get 'mcp#popular-mcp-servers'

    # Search documentation
    claude-docs.sh search 'oauth'
    claude-docs.sh search 'plugin marketplace'

    # Cache management
    claude-docs.sh cache info
    claude-docs.sh cache clear
    claude-docs.sh cache warm

EOF
}

# Main command dispatcher
main() {
    check_deps

    local command="${1:-help}"
    shift || true

    case "$command" in
        download)
            log_error "Command 'download' has been renamed to 'update'"
            log_info "New workflow:"
            log_info "  1. Check updates:  $SCRIPT_NAME update"
            log_info "  2. Apply changes:  $SCRIPT_NAME update commit '<changelog message>'"
            log_info "See: $SCRIPT_NAME help"
            exit 1
            ;;
        update)
            local subcommand="${1:-check}"
            shift || true
            case "$subcommand" in
                check)
                    update_check "$@"
                    ;;
                commit)
                    if [[ -z "$1" ]]; then
                        log_error "Changelog message required"
                        log_info "Usage: $SCRIPT_NAME update commit '<description>'"
                        exit 1
                    fi
                    update_commit "$@"
                    ;;
                discard)
                    update_discard
                    ;;
                status)
                    update_status
                    ;;
                *)
                    log_error "Unknown update subcommand: $subcommand"
                    log_info "Usage: $SCRIPT_NAME update {check|commit|discard|status}"
                    exit 1
                    ;;
            esac
            ;;
        get)
            check_docs_exist
            show_missing_docs_warning
            local no_cache=false
            if [[ "$1" == "--no-cache" ]]; then
                no_cache=true
                shift
            fi

            if [[ -z "$1" ]]; then
                log_error "Usage: $SCRIPT_NAME get <slug> [--no-cache]"
                exit 1
            fi
            get_doc_cached "$1" "$no_cache"
            ;;
        list)
            check_docs_exist
            show_missing_docs_warning
            local no_cache=false
            if [[ "${1:-}" == "--no-cache" ]]; then
                no_cache=true
                shift
            fi
            list_docs_cached "${1:-}" "$no_cache"
            ;;
        search)
            check_docs_exist
            show_missing_docs_warning
            if [[ -z "$1" ]]; then
                log_error "Search query required"
                log_info "Usage: $SCRIPT_NAME search '<query>'"
                exit 1
            fi
            search_docs "$@"
            ;;
        cache)
            check_docs_exist
            local subcommand="${1:-info}"
            shift || true
            case "$subcommand" in
                clear)
                    cache_clear "$@"
                    ;;
                info)
                    cache_info
                    ;;
                warm)
                    cache_warm
                    ;;
                *)
                    log_error "Unknown cache subcommand: $subcommand"
                    log_info "Usage: $SCRIPT_NAME cache {clear|info|warm}"
                    exit 1
                    ;;
            esac
            ;;
        generate-changelog)
            log_error "Command 'generate-changelog' has been removed"
            log_info "Changelogs are now created automatically with update commit"
            log_info "Usage: $SCRIPT_NAME update commit '<description>'"
            exit 1
            ;;
        help|--help|-h)
            show_missing_docs_warning
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac

    # Check if update needed (warn if >24 hours old)
    check_update_needed "$command"
}

main "$@"
