# AI Workflow Guide

Practical ways your team can use AI tools day-to-day. These are real workflows, not theory.

---

## Tools We Use

| Tool | Best For | Access |
|------|---------|--------|
| **Claude Code** (`claude`) | Terminal-based coding, refactoring, multi-file edits | Install via `npm i -g @anthropic-ai/claude-code` |
| **Claude.ai** | Long conversations, document analysis, planning | Browser |
| **GitHub Copilot** | Inline suggestions as you type | VS Code / JetBrains extension |

---

## Daily AI Workflows

### 1. Writing Commit Messages

Instead of writing commit messages from scratch:

```bash
# Stage your changes first
git add -p

# Then generate a commit message
git diff --staged | claude -p "Write a conventional commit message for these changes. Be concise."
```

Or with Claude Code's built-in command:
```bash
claude commit   # automatically stages and generates message
```

---

### 2. Writing PR Descriptions

```bash
# Get a complete PR description from your branch diff
git log origin/main..HEAD --oneline -10 | claude -p "
Write a GitHub PR description with:
- A 1-line summary
- A bullet-point 'What changed' section
- A 'How to test' checklist
Keep it concise."
```

---

### 3. Code Review Assistance

Before submitting your own PR, do an AI self-review:

```bash
git diff origin/main..HEAD | claude -p "
Review this diff for:
1. Bugs or logic errors
2. Security issues (SQL injection, secrets, unvalidated input)
3. Missing edge cases
4. Readability improvements
Be specific about line numbers where possible."
```

---

### 4. Understanding Unfamiliar Code

```bash
# Explain a file
cat src/some-service.ts | claude -p "Explain what this code does, its main responsibilities, and any notable patterns used."

# Or open interactively
claude
> /read src/some-service.ts
> What does this do and how does it integrate with the rest of the system?
```

---

### 5. Writing Tests

```bash
cat src/utils/date-helpers.ts | claude -p "
Write unit tests for these functions using Jest.
Cover: happy paths, edge cases, and error cases.
Output only the test file content."
```

---

### 6. Debugging

When you hit an error, paste the full stack trace + relevant code:

```bash
claude -p "
I'm getting this error: [paste error]

Here's the relevant code: [paste code]

What's causing this and how do I fix it?"
```

Or interactively in Claude Code:
```bash
claude
> I'm seeing this error in production: [paste error]
> /read src/broken-file.ts
> Why is this failing and what's the fix?
```

---

### 7. Refactoring

```bash
cat src/legacy-file.js | claude -p "
Refactor this code to:
- Be more readable
- Remove duplication
- Follow modern JS patterns
Keep the same behavior. Show me the refactored version."
```

---

### 8. Writing Documentation

```bash
cat tools/my-script.sh | claude -p "
Write a README section for this script including:
- What it does
- Prerequisites
- Usage with examples
- Any important flags or options"
```

---

### 9. Generating Boilerplate

Use Claude to bootstrap new tools/scripts:

```bash
claude -p "
Write a bash script that:
- Accepts a domain name as argument
- Checks if an SSL certificate is expiring within 30 days
- Prints a warning if it is
Include proper error handling and a usage comment block."
```

---

## Claude Code Tips

Claude Code runs in your terminal and has full context of your codebase.

```bash
# Install
npm install -g @anthropic-ai/claude-code

# Start interactive session
claude

# Run a one-shot command
claude -p "your prompt"

# Useful slash commands inside Claude Code
/read <file>          # read a file into context
/commit               # auto-generate and commit changes
/review               # review staged changes
/clear                # clear context
```

**Key advantage**: Claude Code can read your entire project, run commands, and make multi-file edits — far more powerful than copy-pasting into a chat window.

---

## Guidelines for AI Use

1. **You are responsible for AI-generated code** — review it before committing
2. **Don't share secrets** — never paste `.env` files, credentials, or PII into AI chats
3. **AI is a pair programmer, not a replacement** — use it to go faster, not to skip thinking
4. **Fix AI mistakes immediately** — if AI generated something wrong and you committed it, own the fix
5. **Document AI-assisted decisions** — if AI suggested an approach that's non-obvious, add a comment

---

## When AI Helps Most

| Task | AI Value | Notes |
|------|---------|-------|
| Boilerplate / scaffolding | ⭐⭐⭐⭐⭐ | Massive time saver |
| Writing tests | ⭐⭐⭐⭐⭐ | Especially edge cases |
| Commit/PR messages | ⭐⭐⭐⭐⭐ | Quick and consistent |
| Explaining unfamiliar code | ⭐⭐⭐⭐⭐ | Great for onboarding |
| Debugging | ⭐⭐⭐⭐ | Good starting point |
| Code review | ⭐⭐⭐⭐ | Catches obvious issues |
| Architecture decisions | ⭐⭐⭐ | Use as input, not gospel |
| Security-critical code | ⭐⭐ | Always expert-review |
