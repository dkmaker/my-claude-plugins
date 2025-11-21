#!/bin/bash

# JavaScript-based HTML renderer for Claude Code transcripts
# Uses normalized JSON embedded in HTML for clean client-side rendering

FILE="$1"

if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
    echo "Error: Transcript file not found: $FILE" >&2
    exit 1
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Output HTML with embedded JSON
cat << 'HTML_START'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Transcript</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        :root {
            --bg: #0a0a0a;
            --bg-secondary: #1a1a1a;
            --bg-elevated: #2a2a2a;
            --text: #e0e0e0;
            --text-dim: #888;
            --user: #1e40af;
            --assistant: #7c3aed;
        }
        body {
            font-family: 'SF Mono', Monaco, 'Courier New', monospace, 'Apple Color Emoji', 'Segoe UI Emoji', 'Noto Color Emoji';
            background: var(--bg);
            color: var(--text);
            font-size: 13px;
            line-height: 1.5;
            padding-top: 36px;
        }

        /* Header */
        .header {
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            background: var(--bg-secondary);
            border-bottom: 1px solid var(--assistant);
            padding: 8px 16px;
            display: flex;
            justify-content: space-between;
            z-index: 100;
            font-size: 11px;
        }
        .header-left { display: flex; gap: 16px; color: var(--text-dim); }
        .header-right { color: var(--text-dim); }

        /* Container */
        .container { max-width: 1400px; margin: 0 auto; padding: 12px; }

        /* Messages */
        .msg {
            margin: 8px 0;
            padding: 12px 16px;
            border-left: 3px solid;
            border-radius: 4px;
        }
        .msg-user { background: rgba(30, 64, 175, 0.1); border-color: var(--user); }
        .msg-assistant { background: rgba(124, 58, 237, 0.1); border-color: var(--assistant); }
        .msg-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 8px;
            font-size: 11px;
        }
        .msg-role {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 2px 8px;
            background: rgba(255,255,255,0.05);
            border-radius: 3px;
            font-weight: 600;
            font-size: 11px;
        }
        .msg-role svg {
            width: 14px;
            height: 14px;
            flex-shrink: 0;
        }
        .msg-time { color: var(--text-dim); }
        .msg-content { color: var(--text); white-space: pre-wrap; }

        /* Twemoji emoji sizing */
        img.emoji {
            height: 1.2em;
            width: 1.2em;
            margin: 0 0.05em 0 0.1em;
            vertical-align: -0.1em;
            display: inline-block;
        }

        /* Universal Tool Pattern */
        .tool {
            margin: 6px 0;
            border-radius: 4px;
            overflow: hidden;
            border-left: 3px solid;
        }
        .tool-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 8px 12px;
            cursor: pointer;
            user-select: none;
            background: rgba(0, 0, 0, 0.3);
        }
        .tool-header:hover { background: rgba(0, 0, 0, 0.5); }
        .tool-left {
            display: flex;
            align-items: center;
            gap: 8px;
            flex: 1;
        }
        .tool-icon {
            width: 14px;
            height: 14px;
            flex-shrink: 0;
        }
        .tool-type { font-weight: 600; }
        .tool-desc { color: var(--text-dim); margin-left: 8px; }
        .tool-expand {
            color: var(--text-dim);
            font-size: 10px;
            flex-shrink: 0;
        }
        .tool-expand::before { content: '▶'; display: inline-block; transition: transform 0.2s; }
        .tool.open .tool-expand::before { transform: rotate(90deg); }

        /* Tool Content */
        .tool-content {
            display: none;
            padding: 12px;
            border-top: 1px solid rgba(255,255,255,0.05);
        }
        .tool.open .tool-content { display: block; }

        .tool-section {
            margin: 8px 0;
        }
        .tool-label {
            font-weight: 600;
            font-size: 11px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-bottom: 4px;
            color: #888;
        }

        .tool-code {
            background: #000;
            padding: 8px;
            border-radius: 3px;
            overflow-x: auto;
            font-size: 12px;
            max-height: 300px;
            overflow-y: auto;
            white-space: pre-wrap;
            word-break: break-word;
        }

        .role-badge {
            display: inline-flex;
            align-items: center;
            gap: 4px;
            padding: 2px 8px;
            border-radius: 3px;
            font-size: 10px;
            font-weight: 600;
            background: rgba(255,255,255,0.05);
        }
        .role-badge svg {
            width: 12px;
            height: 12px;
        }

        /* Stats footer */
        .stats {
            margin-top: 32px;
            padding: 16px;
            background: var(--bg-secondary);
            border-radius: 6px;
            border-top: 2px solid var(--assistant);
        }
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
            gap: 12px;
            margin-top: 12px;
        }
        .stat { text-align: center; }
        .stat-value {
            font-size: 24px;
            font-weight: 700;
            color: var(--assistant);
        }
        .stat-label {
            font-size: 10px;
            color: var(--text-dim);
            margin-top: 4px;
        }

        /* Message expansion - GitHub style */
        .msg-expand-btn {
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 0 8px;
            margin: 0;
            height: 22px;
            background: rgba(124, 58, 237, 0.1);
            color: var(--assistant);
            cursor: pointer;
            font-size: 10px;
            border-top: 1px solid rgba(124, 58, 237, 0.2);
            border-bottom: 1px solid rgba(124, 58, 237, 0.2);
        }
        .msg-expand-btn:hover {
            background: rgba(124, 58, 237, 0.2);
        }
        .msg-expand-icon {
            display: flex;
            gap: 2px;
            font-size: 8px;
        }

        /* Utility */
        .hint {
            position: fixed;
            bottom: 12px;
            right: 12px;
            background: var(--bg-secondary);
            padding: 6px 10px;
            border-radius: 4px;
            font-size: 10px;
            color: var(--text-dim);
            border: 1px solid var(--assistant);
        }
    </style>
</head>
<body>
    <div class="header">
        <div class="header-left">
            <span>Session <strong id="session-id"></strong></span>
            <span>Branch: <span id="branch"></span></span>
            <span id="started-at"></span>
        </div>
        <div class="header-right" id="header-stats"></div>
    </div>

    <div class="container">
        <h2 style="color: var(--assistant); margin-bottom: 16px; font-size: 18px;">Conversation History</h2>
        <div id="timeline"></div>

        <div class="stats">
            <h3 style="color: var(--assistant); font-size: 14px;">Session Statistics</h3>
            <div class="stats-grid" id="stats-grid"></div>
        </div>
    </div>

    <div class="hint">Press E to toggle all tools</div>

HTML_START

echo '    <script src="https://cdn.jsdelivr.net/npm/@twemoji/api@latest/dist/twemoji.min.js"></script>
    <script id="transcript-data" type="text/plain">'
# Base64 encode the JSON to avoid ALL escaping issues
"$SCRIPT_DIR/normalize-transcript.sh" "$FILE" | base64 -w 0
echo '</script>'

cat << 'HTML_END'

    <script>
        // Load transcript data (decode from base64 with UTF-8 support)
        const base64Data = document.getElementById('transcript-data').textContent.trim();
        // Decode base64 with proper UTF-8 handling
        const binaryString = atob(base64Data);
        const bytes = Uint8Array.from(binaryString, c => c.charCodeAt(0));
        const jsonString = new TextDecoder('utf-8').decode(bytes);
        const data = JSON.parse(jsonString);

        // Tool styling configuration
        const TOOL_CONFIG = {
            SlashCommand: { color: '#059669', bg: 'rgba(5, 150, 105, 0.08)', icon: 'slash' },
            Bash: { color: '#d97706', bg: 'rgba(217, 119, 6, 0.08)', icon: 'wrench' },
            Read: { color: '#3b82f6', bg: 'rgba(59, 130, 246, 0.08)', icon: 'wrench' },
            Write: { color: '#8b5cf6', bg: 'rgba(139, 92, 246, 0.08)', icon: 'wrench' },
            Edit: { color: '#ec4899', bg: 'rgba(236, 72, 153, 0.08)', icon: 'wrench' },
            Glob: { color: '#22c55e', bg: 'rgba(34, 197, 94, 0.08)', icon: 'wrench' },
            Grep: { color: '#eab308', bg: 'rgba(234, 179, 8, 0.08)', icon: 'wrench' },
            TodoWrite: { color: '#8b5cf6', bg: 'rgba(139, 92, 246, 0.08)', icon: 'wrench' },
            Task: { color: '#06b6d4', bg: 'rgba(6, 182, 212, 0.08)', icon: 'wrench' },
            AskUserQuestion: { color: '#f59e0b', bg: 'rgba(245, 158, 11, 0.08)', icon: 'wrench' },
        };

        // SVG Icons
        const ICONS = {
            user: '<svg viewBox="0 0 24 24" fill="#3b82f6"><path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/></svg>',
            assistant: '<svg viewBox="0 0 24 24" fill="#a78bfa"><path d="M20 9V7c0-1.1-.9-2-2-2h-3c0-1.66-1.34-3-3-3S9 3.34 9 5H6c-1.1 0-2 .9-2 2v2c-1.66 0-3 1.34-3 3s1.34 3 3 3v4c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2v-4c1.66 0 3-1.34 3-3s-1.34-3-3-3zM7.5 11.5c0-.83.67-1.5 1.5-1.5s1.5.67 1.5 1.5S9.83 13 9 13s-1.5-.67-1.5-1.5zM16 17H8v-2h8v2zm-1-4c-.83 0-1.5-.67-1.5-1.5S14.17 10 15 10s1.5.67 1.5 1.5S15.83 13 15 13z"/></svg>',
            slash: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M7 2h10l-6 20H1L7 2z"/></svg>',
            wrench: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M22.7 19l-9.1-9.1c.9-2.3.4-5-1.5-6.9-2-2-5-2.4-7.4-1.3L9 6 6 9 1.6 4.7C.4 7.1.9 10.1 2.9 12.1c1.9 1.9 4.6 2.4 6.9 1.5l9.1 9.1c.4.4 1 .4 1.4 0l2.3-2.3c.5-.4.5-1.1.1-1.4z"/></svg>'
        };

        // Format timestamp
        function formatTime(iso) {
            if (!iso) return '';
            const date = new Date(iso);
            return date.toTimeString().split(' ')[0];
        }

        // Escape HTML (keep emojis - Twemoji will render them)
        function escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }

        // Universal message renderer with smart truncation
        function renderMessage(msg) {
            const roleClass = `msg-${msg.role}`;
            const icon = ICONS[msg.role];
            const time = formatTime(msg.timestamp);
            const lines = msg.text.split('\n');
            const lineCount = lines.length;

            // Truncate long messages (GitHub style)
            let contentHtml;
            if (lineCount > 20) {
                const firstLines = lines.slice(0, 10).join('\n');
                const lastLines = lines.slice(-5).join('\n');
                const hiddenCount = lineCount - 15;
                const id = 'msg-' + Math.random().toString(36).substr(2, 9);

                const middleLines = lines.slice(10, -5).join('\n');
                contentHtml = `
                    <div class="msg-content">${escapeHtml(firstLines)}<div class="msg-expand-btn" onclick="this.nextElementSibling.style.display='inline'; this.style.display='none';">
                            <span class="msg-expand-icon">
                                <span>▲</span>
                                <span>▼</span>
                            </span>
                            <span>Expand ${hiddenCount} lines</span>
                            <span></span>
                        </div><span id="${id}" style="display: none;">
${escapeHtml(middleLines)}
</span>${escapeHtml(lastLines)}
                    </div>
                `;
            } else {
                contentHtml = `<div class="msg-content">${escapeHtml(msg.text)}</div>`;
            }

            return `
                <div class="msg ${roleClass}">
                    <div class="msg-header">
                        <span class="msg-role">
                            ${icon}
                            ${msg.role.charAt(0).toUpperCase() + msg.role.slice(1)}
                        </span>
                        <span class="msg-time">${time}</span>
                    </div>
                    ${contentHtml}
                </div>
            `;
        }

        // Universal tool renderer
        function renderTool(tool) {
            const config = TOOL_CONFIG[tool.tool_name] || { color: '#6b7280', bg: 'rgba(107, 114, 128, 0.08)', icon: 'wrench' };
            const roleIcon = ICONS[tool.role];
            const toolIcon = ICONS[config.icon];
            const time = formatTime(tool.timestamp);
            const hasResult = tool.result && tool.result.length > 0;

            return `
                <div class="tool" style="background: ${config.bg}; border-color: ${config.color};">
                    <div class="tool-header" onclick="this.parentElement.classList.toggle('open')">
                        <div class="tool-left">
                            <span class="role-badge">
                                ${roleIcon}
                                ${tool.role.charAt(0).toUpperCase() + tool.role.slice(1)}
                            </span>
                            <span style="color: ${config.color};">
                                ${toolIcon}
                            </span>
                            <span class="tool-type" style="color: ${config.color};">${tool.tool_name}:</span>
                            <span class="tool-desc">${escapeHtml(tool.display || '')}</span>
                            ${tool.is_error ? '<span style="color: #dc2626; margin-left: 8px;">❌</span>' : ''}
                        </div>
                        <div class="tool-expand"></div>
                    </div>
                    <div class="tool-content">
                        <div class="tool-section">
                            <div class="tool-label">Input:</div>
                            <pre class="tool-code"><code>${escapeHtml(tool.input || '')}</code></pre>
                        </div>
                        <div class="tool-section">
                            <div class="tool-label">Result:</div>
                            ${hasResult ?
                                `<pre class="tool-code"><code>${escapeHtml(tool.result)}</code></pre>` :
                                '<div style="color: var(--text-dim);">No output</div>'
                            }
                        </div>
                    </div>
                </div>
            `;
        }

        // Render header
        function renderHeader() {
            const s = data.session;
            document.getElementById('session-id').textContent = s.short_id;
            document.getElementById('branch').textContent = s.branch;
            document.getElementById('started-at').textContent = s.started_at;
            document.getElementById('header-stats').textContent =
                `${s.stats.total_messages} msgs · ${s.stats.input_tokens}+${s.stats.output_tokens} tokens`;
        }

        // Render timeline
        function renderTimeline() {
            const timeline = document.getElementById('timeline');
            timeline.innerHTML = data.elements.map(el => {
                if (el.type === 'message') {
                    return renderMessage(el);
                } else if (el.type === 'tool') {
                    return renderTool(el);
                }
                return '';
            }).join('');
        }

        // Render stats
        function renderStats() {
            const s = data.session.stats;
            document.getElementById('stats-grid').innerHTML = `
                <div class="stat">
                    <div class="stat-value">${s.total_messages}</div>
                    <div class="stat-label">Total Messages</div>
                </div>
                <div class="stat">
                    <div class="stat-value">${s.user_messages}</div>
                    <div class="stat-label">User</div>
                </div>
                <div class="stat">
                    <div class="stat-value">${s.assistant_messages}</div>
                    <div class="stat-label">Assistant</div>
                </div>
                <div class="stat">
                    <div class="stat-value">${(s.input_tokens + s.output_tokens).toLocaleString()}</div>
                    <div class="stat-label">Tokens</div>
                </div>
                <div class="stat">
                    <div class="stat-value">${s.cache_tokens.toLocaleString()}</div>
                    <div class="stat-label">Cached</div>
                </div>
            `;
        }

        // Keyboard shortcuts
        document.addEventListener('keydown', (e) => {
            if (e.key === 'e' || e.key === 'E') {
                const allTools = document.querySelectorAll('.tool');
                const anyOpen = Array.from(allTools).some(t => t.classList.contains('open'));
                allTools.forEach(t => anyOpen ? t.classList.remove('open') : t.classList.add('open'));
            }
        });

        // Initialize on load
        document.addEventListener('DOMContentLoaded', () => {
            renderHeader();
            renderTimeline();
            renderStats();

            // Parse all emojis with Twemoji for color rendering
            if (typeof twemoji !== 'undefined') {
                twemoji.parse(document.body, {
                    folder: 'svg',
                    ext: '.svg'
                });
            }
        });
    </script>
</body>
</html>
HTML_END
