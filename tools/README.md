# Tools

Collection of scripts and utilities to speed up common development tasks.

---

## Available Tools

| Script | Description |
|--------|-------------|
| [`setup.sh`](setup.sh) | One-time local environment setup |
| [`ai-commit.sh`](ai-commit.sh) | Generate a conventional commit message using Claude |
| [`ai-review.sh`](ai-review.sh) | AI-powered code review before pushing |
| [`ai-pr-description.sh`](ai-pr-description.sh) | Generate a GitHub PR description from your branch |

---

## Quick Start

```bash
# Make all scripts executable
chmod +x tools/*.sh

# Set up your environment
./tools/setup.sh
```

---

## AI Tools

The `ai-*.sh` scripts require [Claude Code](https://docs.anthropic.com/claude-code) to be installed:

```bash
npm install -g @anthropic-ai/claude-code
```

### Typical workflow with AI tools

```bash
# 1. Make your changes

# 2. Stage them
git add -p

# 3. AI review before committing
./tools/ai-review.sh --staged

# 4. Generate and commit with AI message
./tools/ai-commit.sh

# 5. Before opening a PR, generate the description
./tools/ai-pr-description.sh
```

---

## Adding a New Tool

1. Create your script in `tools/`
2. Add a usage comment block at the top (see existing scripts for format)
3. Make it executable: `chmod +x tools/your-script.sh`
4. Add it to the table above
5. Test with `shellcheck tools/your-script.sh`
