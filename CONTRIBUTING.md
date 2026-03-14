# Contributing to DevPose

Thanks for taking the time to contribute! This guide covers everything you need to get started.

---

## Quick Start

1. **Fork** the repository
2. **Clone** your fork: `git clone https://github.com/<your-username>/dev-pose.git`
3. **Branch** off `main`: `git checkout -b feat/your-feature-name`
4. **Make changes**, following our [coding standards](guidelines/coding-standards.md)
5. **Commit** using our [git workflow](guidelines/git-workflow.md)
6. **Push** and open a Pull Request

---

## What to Contribute

| Type | Where | Examples |
|------|--------|---------|
| New tool/script | `tools/` | Setup scripts, automation helpers |
| Guidelines update | `guidelines/` | Coding standards, new best practices |
| Documentation | `docs/` | Onboarding guides, FAQs, how-tos |
| Bug fix | Anywhere | Fix broken scripts, update outdated docs |

---

## Standards

- Follow [coding-standards.md](guidelines/coding-standards.md)
- Shell scripts must be POSIX-compatible where possible
- All new tools need a usage comment block at the top
- Docs use Markdown; keep lines under 120 characters

## Pull Request Checklist

- [ ] Self-reviewed your changes
- [ ] Added/updated relevant documentation
- [ ] Scripts are executable (`chmod +x`) and tested locally
- [ ] No secrets or credentials committed

---

## Need Help?

Open an issue with the `question` label, or check [docs/onboarding.md](docs/onboarding.md).
