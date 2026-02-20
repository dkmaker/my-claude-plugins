# Debug Research

## Strategy

1. **Error messages**: Search the exact error message or key phrases
2. **Stack traces**: Extract the root cause line and search for it
3. **Runtime issues**: Describe the symptom (deadlock, memory leak, crash)
4. **GitHub issues**: Search for known bugs in the relevant project

## Commands

```bash
# Reason through a debugging problem (recommended)
websearch -m reason "why does X happen when Y"

# Search GitHub issues for known bugs
websearch -p github -m issues "error message or symptom"

# Language-specific profiles
websearch -p nodejs "node error message"
websearch -p python "python traceback explanation"

# Find code examples showing the fix
websearch -p github -m code "fix for specific pattern"
```

## Guidelines

- Use `-m reason` for debugging — chain-of-thought analysis
- Use `-p github -m issues` to find if others hit the same bug
- Include language/framework name in queries
- Quote exact error messages for best results
- Add `--gh-state open` or `--gh-repo owner/repo` to narrow GitHub results
