#!/usr/bin/env bash
# Usage: ./tools/ai-pr-description.sh [base-branch]
# Description: Generates a GitHub PR description from your branch diff using Claude.
#              Outputs markdown ready to paste into GitHub.
# Dependencies: git, claude (Claude Code CLI)

set -euo pipefail

BASE_BRANCH="${1:-origin/main}"

# ─── Check dependencies ───────────────────────────────────────────────────────
if ! command -v claude &>/dev/null; then
  echo "Error: Claude Code is not installed."
  echo "Install with: npm install -g @anthropic-ai/claude-code"
  exit 1
fi

# ─── Gather context ───────────────────────────────────────────────────────────
DIFF=$(git diff "${BASE_BRANCH}...HEAD")
COMMITS=$(git log "${BASE_BRANCH}..HEAD" --oneline)
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

if [[ -z "$DIFF" ]]; then
  echo "No changes found between HEAD and ${BASE_BRANCH}."
  exit 1
fi

echo "Generating PR description for branch: ${CURRENT_BRANCH}"
echo "Comparing against: ${BASE_BRANCH}"
echo ""

# ─── Generate PR description ──────────────────────────────────────────────────
PR_DESCRIPTION=$(claude -p "
You are writing a GitHub Pull Request description.

Branch: ${CURRENT_BRANCH}
Commits:
${COMMITS}

Generate a PR description in this exact markdown format:

## Summary
[1-2 sentence overview of what this PR does and why]

## Changes
- [bullet point list of key changes]

## How to Test
1. [numbered steps to verify the changes work]

## Notes
[Any important context, caveats, or follow-up work — omit this section if nothing to add]

Be concise and factual. Don't pad or be vague. Output ONLY the markdown.

---
DIFF:
${DIFF}
")

echo "──────────────────────────────────────────"
echo "$PR_DESCRIPTION"
echo "──────────────────────────────────────────"
echo ""
echo "Copy the above into your GitHub PR description."

# Optionally copy to clipboard if pbcopy or xclip is available
if command -v pbcopy &>/dev/null; then
  echo "$PR_DESCRIPTION" | pbcopy
  echo "(Copied to clipboard)"
elif command -v xclip &>/dev/null; then
  echo "$PR_DESCRIPTION" | xclip -selection clipboard
  echo "(Copied to clipboard)"
fi
