---
name: finishing-a-development-branch
description: Use when implementation is complete, all tests pass, and you need to decide how to integrate the work - guides completion of development work by presenting structured options for merge, PR, or cleanup
---

# Finishing a Development Branch

## Overview

Guide completion of development work by presenting clear options and handling chosen workflow.

**Core principle:** Verify tests → Present options → Execute choice → Clean up.

**Announce at start:** "I'm using the finishing-a-development-branch skill to complete this work."

## The Process

### Step 1: Verify Tests

**Before presenting options, verify tests pass:**

```bash
# Run project's test suite
npm test / cargo test / pytest / go test ./...
```

**If tests fail:**
```
Tests failing (<N> failures). Must fix before completing:

[Show failures]

Cannot proceed with merge/PR until tests pass.
```

Stop. Don't proceed to Step 2.

**If tests pass:** Continue to Step 2.

### Step 2: Determine Base Branch

```bash
# Try common base branches
git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null
```

Or ask: "This branch split from main - is that correct?"

### Step 3: Present Options

Use the `AskUserQuestion` tool to present exactly these 4 options as a single-select question:

- **Merge locally** — Merge back to `<base-branch>` on this machine
- **Create Pull Request** — Push branch and open a PR for review
- **Keep as-is** — Leave the branch, handle it later
- **Discard** — Delete the branch and all work

Keep descriptions concise.

### Step 4: Execute Choice

#### Option 1: Merge Locally

```bash
# Switch to base branch
git checkout <base-branch>

# Pull latest
git pull

# Merge feature branch
git merge <feature-branch>

# Verify tests on merged result
<test command>

# If tests pass
git branch -d <feature-branch>
```

Then: Cleanup worktree (Step 5)

#### Option 2: Push and Create PR

```bash
# Push branch
git push -u origin <feature-branch>

# Create PR
gh pr create --title "<title>" --body "$(cat <<'EOF'
## Summary
<2-3 bullets of what changed>

## Test Plan
- [ ] <verification steps>
EOF
)"
```

Then: Cleanup worktree (Step 5)

#### Option 3: Keep As-Is

Report: "Keeping branch <name>. Worktree preserved at <path>."

**Don't cleanup worktree.**

#### Option 4: Discard

**Confirm first:**
```
This will permanently delete:
- Branch <name>
- All commits: <commit-list>
- Worktree at <path>

Type 'discard' to confirm.
```

Wait for exact confirmation.

If confirmed:
```bash
git checkout <base-branch>
git branch -D <feature-branch>
```

Then: Cleanup worktree (Step 5)

### Step 5: Cleanup Worktree

**For Options 1, 2, 4:**

**CRITICAL SAFETY CHECK - Must happen BEFORE removing worktree:**

```bash
# Detect if we're currently in a worktree
current_dir=$(pwd)
worktree_path=$(git worktree list | grep $(git branch --show-current) | awk '{print $1}')

# If we're IN the worktree we want to remove, MUST switch out first
if [ "$current_dir" = "$worktree_path" ] || [[ "$current_dir" == "$worktree_path"/* ]]; then
  echo "Currently in worktree - switching to main repository first"

  # Get main repository path (first worktree in list)
  main_repo=$(git worktree list | head -1 | awk '{print $1}')

  # Switch to main repo
  cd "$main_repo"

  # CRITICAL: Tell user session needs to be restarted in main repo
  echo "⚠️  IMPORTANT: You need to restart Claude Code in the main repository."
  echo "Main repo path: $main_repo"
  echo "After restarting, I can remove the worktree at: $worktree_path"
  exit 0
fi

# Only reach here if we're NOT in the worktree
# Safe to remove now
git worktree remove <worktree-path>
```

**For Option 3:** Keep worktree.

**Why this matters:**
- Removing a worktree while Claude Code is running inside it **crashes the session**
- The filesystem disappears underneath the running process
- MUST switch to main repository FIRST, then remove in a new session

## Quick Reference

| Option | Merge | Push | Keep Worktree | Cleanup Branch |
|--------|-------|------|---------------|----------------|
| 1. Merge locally | ✓ | - | - | ✓ |
| 2. Create PR | - | ✓ | ✓ | - |
| 3. Keep as-is | - | - | ✓ | - |
| 4. Discard | - | - | - | ✓ (force) |

## Common Mistakes

**Skipping test verification**
- **Problem:** Merge broken code, create failing PR
- **Fix:** Always verify tests before offering options

**Open-ended questions**
- **Problem:** "What should I do next?" → ambiguous
- **Fix:** Present exactly 4 structured options

**Automatic worktree cleanup**
- **Problem:** Remove worktree when might need it (Option 2, 3)
- **Fix:** Only cleanup for Options 1 and 4

**Removing worktree while inside it**
- **Problem:** Deletes filesystem under running Claude Code → session crashes
- **Fix:** Check if in worktree, switch to main repo first, tell user to restart

**No confirmation for discard**
- **Problem:** Accidentally delete work
- **Fix:** Require typed "discard" confirmation

## Red Flags

**Never:**
- Proceed with failing tests
- Merge without verifying tests on result
- Delete work without confirmation
- Force-push without explicit request
- **Remove a worktree while Claude Code is running inside it** ← CRASHES SESSION

**Always:**
- Verify tests before offering options
- Present exactly 4 options
- Get typed confirmation for Option 4
- Clean up worktree for Options 1 & 4 only
- **Check if in worktree BEFORE removing it** ← CRITICAL SAFETY
- If in worktree: switch out first, tell user to restart Claude Code

## Integration

**Called by:**
- **subagent-driven-development** (Step 7) - After all tasks complete
- **executing-plans** (Step 5) - After all batches complete
- **headless-runner** - After all background batches complete

**Pairs with:**
- **using-git-worktrees** - Cleans up worktree created by that skill
