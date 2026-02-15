# Superpowers Integration into my-claude-plugins

## Integration Summary

**Date**: 2026-02-15
**Original Version**: 4.3.0
**Original Author**: Jesse Vincent (@obra)
**Integration Method**: Vendored fork (Option 1)

## What Was Integrated

### ✅ Claude Code Components Included

- **14 Skills** (complete workflow system):
  - `brainstorming` - Socratic design refinement
  - `test-driven-development` - RED-GREEN-REFACTOR cycle
  - `systematic-debugging` - 4-phase root cause process
  - `writing-plans` - Detailed implementation plans
  - `executing-plans` - Batch execution with checkpoints
  - `subagent-driven-development` - Fast iteration with two-stage review
  - `requesting-code-review` - Pre-review checklist
  - `receiving-code-review` - Responding to feedback
  - `using-git-worktrees` - Parallel development branches
  - `finishing-a-development-branch` - Merge/PR decision workflow
  - `dispatching-parallel-agents` - Concurrent subagent workflows
  - `verification-before-completion` - Ensure fixes are verified
  - `writing-skills` - Create new skills following best practices
  - `using-superpowers` - Introduction to the skills system

- **1 Agent**:
  - `code-reviewer` - Automated code review agent

- **Hooks**:
  - SessionStart hook that injects `using-superpowers` skill content into context
  - Ensures Claude knows about and uses the skills system

- **Documentation**:
  - README.md - Original documentation
  - RELEASE-NOTES.md - Version history and changes
  - LICENSE - MIT license
  - README.fork.md - Fork-specific information (NEW)
  - INTEGRATION.md - This file (NEW)

### ❌ Files Removed (Non-Claude Code)

- `docs/` - Codex and OpenCode specific documentation
- `commands/` - Legacy command files (superseded by skills/)
- `lib/` - skills-core.js (Codex/OpenCode JavaScript library)
- `hooks/run-hook.cmd` - Windows polyglot wrapper (not needed in Claude Code 2.1+)
- `tests/` - Test suites for other platforms
- `.git/` - Git metadata
- `.github/` - GitHub Actions workflows
- `.codex/` - Codex installation files
- `.opencode/` - OpenCode installation files
- `.gitignore` - Not needed in vendored fork
- `.gitattributes` - Not needed in vendored fork
- `.claude-plugin/marketplace.json` - Obsolete (plugin is in parent marketplace)

## Installation for Users

### From my-claude-plugins Marketplace

```bash
# If you had it from obra's marketplace, uninstall first:
/plugin uninstall superpowers@superpowers-marketplace

# Install from my-claude-plugins:
/plugin install superpowers@my-claude-plugins
```

### Skills Namespace

All skills are namespaced as `superpowers:<skill-name>`:
- `/superpowers:brainstorming` or just trigger automatically
- Skills auto-activate based on task context (no manual invocation needed)

## Attribution

This is a fork of Jesse Vincent's excellent Superpowers plugin:
- **Original Repository**: https://github.com/obra/superpowers
- **Original Marketplace**: https://github.com/obra/superpowers-marketplace
- **Author**: Jesse Vincent (@obra)
- **License**: MIT
- **Sponsorship**: https://github.com/sponsors/obra

Please consider sponsoring Jesse's work if Superpowers has been valuable to you.

## Why Forked

1. **Control over updates** - Update on our schedule, not automatic
2. **Customization ability** - Can modify skills for specific workflows
3. **Integration** - Seamless integration with my-claude-plugins ecosystem
4. **Stability** - Tested versions before deployment

## Maintenance

### Checking for Upstream Updates

```bash
# Check latest release
curl -s https://api.github.com/repos/obra/superpowers/releases/latest | jq -r '.tag_name'

# Or visit
open https://github.com/obra/superpowers/releases
```

### Updating from Upstream

1. Download latest release from https://github.com/obra/superpowers
2. Review RELEASE-NOTES.md for breaking changes
3. Extract Claude Code relevant files:
   - `.claude-plugin/plugin.json`
   - `skills/`
   - `agents/`
   - `hooks/`
   - `README.md`, `RELEASE-NOTES.md`, `LICENSE`
4. Merge carefully, preserving local customizations
5. Update version in both `plugin.json` and `marketplace.json`
6. Test thoroughly
7. Commit and push

## File Structure

```
superpowers/
├── .claude-plugin/
│   └── plugin.json                    # Plugin metadata with fork info
├── LICENSE                            # MIT license (original)
├── README.md                          # Original documentation
├── README.fork.md                     # Fork-specific info
├── RELEASE-NOTES.md                   # Version history
├── INTEGRATION.md                     # This file
├── agents/
│   └── code-reviewer.md              # Code review agent
├── hooks/
│   ├── hooks.json                    # SessionStart hook config
│   └── session-start.sh              # Hook script (executable)
└── skills/                           # 14 skills (see above)
    ├── brainstorming/
    ├── dispatching-parallel-agents/
    ├── executing-plans/
    ├── finishing-a-development-branch/
    ├── receiving-code-review/
    ├── requesting-code-review/
    ├── subagent-driven-development/
    ├── systematic-debugging/
    ├── test-driven-development/
    ├── using-git-worktrees/
    ├── using-superpowers/
    ├── verification-before-completion/
    ├── writing-plans/
    └── writing-skills/
```

## Local Customizations

Track any modifications here:

- **2026-02-15**: Initial fork at v4.3.0
  - Removed Codex/OpenCode specific files (.codex/, .opencode/, docs/, commands/, lib/)
  - Removed git/build artifacts (.gitignore, .gitattributes, .claude-plugin/marketplace.json)
  - Claude Code only configuration
  - Added fork documentation (README.fork.md, INTEGRATION.md)

## Support

- **Original issues**: https://github.com/obra/superpowers/issues
- **Fork issues**: File in my-claude-plugins repository
- **Original author**: jesse@fsck.com

## Philosophy

The Superpowers system is built on:
- **Test-Driven Development** - Write tests first, always
- **Systematic over ad-hoc** - Process over guessing
- **Complexity reduction** - Simplicity as primary goal
- **Evidence over claims** - Verify before declaring success

These principles remain unchanged in this fork.
