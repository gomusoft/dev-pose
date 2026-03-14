#!/usr/bin/env bash
# Usage: ./tools/ai-review.sh [--staged | --branch <base>]
# Description: AI-powered code review using Claude. Reviews your staged changes
#              or a full branch diff before you push.
# Dependencies: git, claude (Claude Code CLI)

set -euo pipefail

# ─── Check dependencies ───────────────────────────────────────────────────────
if ! command -v claude &>/dev/null; then
  echo "Error: Claude Code is not installed."
  echo "Install with: npm install -g @anthropic-ai/claude-code"
  exit 1
fi

# ─── Parse arguments ──────────────────────────────────────────────────────────
MODE="staged"
BASE_BRANCH="origin/main"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --staged)
      MODE="staged"
      shift
      ;;
    --branch)
      MODE="branch"
      BASE_BRANCH="${2:-origin/main}"
      shift 2
      ;;
    -h|--help)
      echo "Usage: ./tools/ai-review.sh [--staged | --branch <base>]"
      echo ""
      echo "Options:"
      echo "  --staged           Review currently staged changes (default)"
      echo "  --branch <base>    Review all changes from <base> to HEAD"
      echo "                     Default base: origin/main"
      echo ""
      echo "Examples:"
      echo "  ./tools/ai-review.sh --staged"
      echo "  ./tools/ai-review.sh --branch origin/main"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# ─── Get the diff ─────────────────────────────────────────────────────────────
if [[ "$MODE" == "staged" ]]; then
  DIFF=$(git diff --staged)
  if [[ -z "$DIFF" ]]; then
    echo "No staged changes found. Stage some files first with: git add -p"
    exit 1
  fi
  CONTEXT="staged changes"
else
  DIFF=$(git diff "${BASE_BRANCH}...HEAD")
  if [[ -z "$DIFF" ]]; then
    echo "No changes found between HEAD and ${BASE_BRANCH}."
    exit 1
  fi
  CONTEXT="changes from ${BASE_BRANCH} to HEAD"
fi

# ─── Run AI review ────────────────────────────────────────────────────────────
echo ""
echo "Running AI code review on ${CONTEXT}..."
echo "────────────────────────────────────────────────"
echo ""

echo "$DIFF" | claude -p "
You are a senior software engineer reviewing a code diff.

Review the following ${CONTEXT} for:
1. Bugs or logic errors
2. Security issues (exposed secrets, injection risks, unvalidated input)
3. Missing edge cases or error handling
4. Readability or maintainability issues
5. Anything that looks clearly wrong or risky

Format your response as:
- **Issues** (numbered list, with severity: critical / warning / suggestion)
- **Looks good** (things done well)
- **Overall assessment** (1-2 sentences)

Be specific. If something is fine, say so briefly and move on.

---
DIFF:
$(cat)
"

echo ""
echo "────────────────────────────────────────────────"
echo "Review complete. Fix any critical issues before committing."
echo ""
