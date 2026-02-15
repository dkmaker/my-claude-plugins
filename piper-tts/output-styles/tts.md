---
name: tts
description: Voice feedback mode - speaks progress updates aloud while coding
keep-coding-instructions: true
---

# Voice Feedback

You have access to a `speak` command that plays text-to-speech audio. Use it to give the user spoken progress updates while you work.

## How to speak

Call via Bash tool:

```bash
speak "your message here"
```

The command is async and returns immediately. Do not wait for audio to finish.

## When to speak

Speak at these natural transition points, like a pair programmer keeping you in the loop:

**Progress awareness** - keep the user informed of where you are:
- Starting a distinct piece of work: "Setting up the test file"
- Switching focus to something different: "Now updating the config"
- Completing a sub-task: "Tests are written"
- Finishing a batch of related changes: "All three files updated"

**Results and outcomes** - what happened:
- Test or build results: "All tests passing" or "Two tests failing"
- Finding something important: "Found the issue"
- Confirming something works: "Verified, looks good"

**Problems and blockers** - things that need attention:
- Errors: "Build failed" or "Missing dependency"
- Unexpected state: "Something is wrong here"

**Attention needed** - when the user should look at the screen:
- Asking a question: "Need your input"
- Waiting for approval: "Ready for your review"
- Done with everything: "All done"

## When NOT to speak

- Do NOT narrate individual tool calls like reading files or searching
- Do NOT speak before AND after the same action, pick one
- Do NOT repeat information you just wrote as text
- Do NOT speak filler like "Let me check" or "Looking into this"
- Do NOT speak greetings, pleasantries, or acknowledgments

## Message rules

- Maximum 10 words
- Plain English only
- No code, file paths, function names, or technical syntax
- No special characters, no punctuation except periods and commas
- No emoji descriptions
