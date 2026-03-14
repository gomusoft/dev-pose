# DevPose

DevPose is your all-in-one repository for empowering developers with essential tools, best practices, and helpful guidelines. Inspired by the **Log Pose** from *One Piece*, DevPose serves as your guide on the journey to your development goals — navigating you toward the Grand Line of consistent, high-quality software.

---

## Table of Contents

1. [What's in Here](#whats-in-here)
2. [Quick Start](#quick-start)
3. [Tools](#tools)
4. [Guidelines](#guidelines)
5. [Documentation](#documentation)
6. [AI Workflow](#ai-workflow)
7. [Contributing](#contributing)
8. [License](#license)

---

## What's in Here

```
DevPose/
├── tools/               # Scripts to speed up common dev tasks
│   ├── setup.sh         # One-time local environment setup
│   ├── ai-commit.sh     # AI-generated conventional commit messages
│   ├── ai-review.sh     # AI code review before pushing
│   └── ai-pr-description.sh  # AI-generated PR descriptions
│
├── guidelines/          # Team standards and practices
│   ├── code-of-conduct.md
│   ├── coding-standards.md
│   └── git-workflow.md
│
├── docs/                # Reference documentation
│   ├── onboarding.md    # Start here if you're new
│   └── ai-workflow.md   # How we use AI day-to-day
│
├── .github/
│   ├── workflows/ci.yml          # CI: shell lint, markdown lint, link check
│   ├── PULL_REQUEST_TEMPLATE.md  # Auto-filled PR template
│   └── ISSUE_TEMPLATE/           # Bug, feature, and question templates
│
├── CONTRIBUTING.md
└── LICENSE
```

---

## Quick Start

```bash
# 1. Clone
git clone https://github.com/gomusoft/dev-pose.git
cd dev-pose

# 2. Set up your environment
./tools/setup.sh

# 3. Read the essentials
# - guidelines/git-workflow.md
# - guidelines/coding-standards.md
# - docs/ai-workflow.md
```

---

## Tools

Scripts that make your daily workflow faster. See [tools/README.md](tools/README.md) for full details.

| Script | What it does |
|--------|-------------|
| `tools/setup.sh` | Configures git, checks dependencies, verifies AI tools |
| `tools/ai-commit.sh` | Generates a conventional commit message from staged changes |
| `tools/ai-review.sh` | AI reviews your diff for bugs, security issues, and improvements |
| `tools/ai-pr-description.sh` | Generates a ready-to-paste GitHub PR description |

```bash
# Make scripts executable
chmod +x tools/*.sh

# Example: AI-assisted commit workflow
git add -p
./tools/ai-review.sh --staged     # review before committing
./tools/ai-commit.sh              # generate and commit
./tools/ai-pr-description.sh      # generate PR description
```

---

## Guidelines

| Document | Summary |
|----------|---------|
| [Code of Conduct](guidelines/code-of-conduct.md) | How we treat each other, including in code reviews |
| [Coding Standards](guidelines/coding-standards.md) | Naming conventions, commit format, documentation rules |
| [Git Workflow](guidelines/git-workflow.md) | Branch strategy, PR process, merging |

---

## Documentation

| Document | Summary |
|----------|---------|
| [Onboarding Guide](docs/onboarding.md) | Day 1 checklist, editor setup, first contribution |
| [AI Workflow Guide](docs/ai-workflow.md) | Practical AI tips for commits, reviews, debugging, and more |

---

## AI Workflow

We actively use AI tools to move faster. Key workflows:

```bash
# Generate commit messages
git diff --staged | claude -p "Write a conventional commit message"

# AI code review before pushing
./tools/ai-review.sh --staged

# Generate PR descriptions
./tools/ai-pr-description.sh

# Explain unfamiliar code
cat src/some-file.ts | claude -p "Explain what this does"
```

Full guide: [docs/ai-workflow.md](docs/ai-workflow.md)

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full guide.

Short version:
1. Fork → branch off `main` → make changes → PR
2. Follow [coding-standards.md](guidelines/coding-standards.md)
3. Keep PRs small (< 400 lines)
4. Respond to review comments within 1 business day

---

## License

MIT License — see [LICENSE](LICENSE).
