# playwright-cli

Browser automation using the `playwright-cli` command-line tool.

## Features

- **Web navigation**: Open browsers, navigate pages, go back/forward
- **Form interaction**: Fill forms, click buttons, select dropdowns
- **Testing**: Take screenshots, generate PDFs, record videos
- **Data extraction**: Eval JavaScript, extract content from pages
- **Session management**: Multiple browser sessions, tabs, persistent profiles
- **Storage state**: Save/load cookies, localStorage, sessionStorage
- **Network mocking**: Route requests, mock responses
- **DevTools**: Console logs, network monitoring, tracing

## Installation

```bash
/plugin install playwright-cli@my-claude-plugins
```

## Prerequisites

The `playwright-cli` tool must be installed. Install it with:

```bash
npm install -g playwright-cli
playwright-cli install-browser
```

## Usage

The skill activates automatically when you ask Claude to:
- Navigate to a website
- Fill out a form
- Take a screenshot
- Test a web page
- Extract data from a website
- Interact with web elements

### Quick Example

```
"Go to https://example.com and take a screenshot"
```

Claude will use the playwright-cli skill to:
1. Open a browser
2. Navigate to the URL
3. Take a screenshot
4. Show you the result

## Manual Invocation

```
/playwright-cli
```

## Skill Restrictions

- **Allowed tools**: Only `Bash` with `playwright-cli:*` commands
- This ensures the skill uses the CLI tool correctly and safely

## Reference Documentation

The skill includes comprehensive reference guides for:
- Request mocking
- Running Playwright code
- Session management
- Storage state management
- Test generation
- Tracing
- Video recording

These are automatically available to Claude when using the skill.

## Examples

### Form Submission
```
"Fill out the contact form at example.com/contact with email test@example.com"
```

### Multi-tab Workflow
```
"Open example.com in one tab and example.com/other in another, then compare them"
```

### Data Extraction
```
"Go to example.com/products and extract all product names and prices"
```

## Configuration

The skill supports multiple browsers (Chromium, Firefox, WebKit, Edge), persistent profiles, and browser extensions. See the SKILL.md for full configuration options.

## License

MIT
