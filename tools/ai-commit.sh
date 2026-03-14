#!/usr/bin/env bash
# Usage: ./tools/ai-commit.sh
# Description: Generates a conventional commit message from staged changes using Claude,
#              then prompts you to confirm before committing.
# Dependencies: git, claude (Claude Code CLI)

set -euo pipefail

# ─── Check dependencies ───────────────────────────────────────────────────────
if ! command -v claude &>/dev/null; then
  echo "Error: Claude Code is not installed."
  echo "Install with: npm install -g @anthropic-ai/claude-code"
  exit 1
fi

# ─── Check for staged changes ─────────────────────────────────────────────────
DIFF=$(git diff --staged)
if [[ -z "$DIFF" ]]; then
  echo "No staged changes found. Stage some files first with: git add -p"
  exit 1
fi

# ─── Generate commit message ──────────────────────────────────────────────────
echo "Generating commit message..."
echo ""

COMMIT_MSG=$(echo "$DIFF" | claude -p "
Generate a git commit message for the following staged diff.

Rules:
- Use Conventional Commits format: <type>(<scope>): <short summary>
- Types: feat, fix, docs, refactor, test, chore
- Keep the summary under 72 characters
- Use imperative mood (\"add\" not \"added\")
- Add a blank line + body paragraph only if the change is complex
- Output ONLY the commit message, nothing else

DIFF:
$(cat)
")

echo "Suggested commit message:"
echo "──────────────────────────────────────────"
echo "$COMMIT_MSG"
echo "──────────────────────────────────────────"
echo ""

# ─── Confirm and commit ───────────────────────────────────────────────────────
read -r -p "Use this message? [Y/n/e(dit)] " CHOICE
CHOICE="${CHOICE:-Y}"

case "$CHOICE" in
  [Yy]*)
    git commit -m "$COMMIT_MSG"
    echo ""
    echo "Committed!"
    ;;
  [Ee]*)
    # Open the message in the default editor
    TMPFILE=$(mktemp)
    echo "$COMMIT_MSG" > "$TMPFILE"
    "${EDITOR:-nano}" "$TMPFILE"
    EDITED_MSG=$(cat "$TMPFILE")
    rm -f "$TMPFILE"
    git commit -m "$EDITED_MSG"
    echo ""
    echo "Committed with edited message!"
    ;;
  *)
    echo "Commit cancelled."
    exit 0
    ;;
esac
