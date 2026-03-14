# Onboarding Guide

Welcome to Gomusoft! This guide gets you productive on day one.

---

## Day 1 Checklist

- [ ] Clone [dev-pose](https://github.com/gomusoft/dev-pose): `git clone https://github.com/gomusoft/dev-pose.git`
- [ ] Run `tools/setup.sh` to configure your local dev environment
- [ ] Read [code-of-conduct.md](../guidelines/code-of-conduct.md)
- [ ] Read [coding-standards.md](../guidelines/coding-standards.md)
- [ ] Read [git-workflow.md](../guidelines/git-workflow.md)
- [ ] Set up your editor (see [Editor Setup](#editor-setup) below)
- [ ] Get access to required services (ask your team lead)
- [ ] Make your first small contribution — fix a typo, update a doc, add a tool

---

## Editor Setup

### VS Code (recommended)

Install these extensions:
- **EditorConfig** — enforces consistent formatting
- **GitLens** — enhanced git history and blame
- **GitHub Copilot** or **Claude for VS Code** — AI pair programmer
- **ShellCheck** — shell script linting
- **Markdown All in One** — markdown preview and shortcuts

Recommended settings (`settings.json`):
```json
{
  "editor.formatOnSave": true,
  "editor.rulers": [120],
  "files.trimTrailingWhitespace": true,
  "files.insertFinalNewline": true
}
```

### Other editors
- **JetBrains IDEs**: Install the Claude AI or Copilot plugin
- **Neovim**: Use `nvim-lspconfig` + `avante.nvim` for AI

---

## Git Setup

```bash
# Identity
git config --global user.name "Your Name"
git config --global user.email "you@gomusoft.com"

# Better defaults
git config --global pull.rebase true        # rebase by default
git config --global rebase.autoStash true   # stash before rebase
git config --global push.autoSetupRemote true

# Useful aliases
git config --global alias.lg "log --oneline --graph --decorate --all"
git config --global alias.st "status -sb"
git config --global alias.undo "reset --soft HEAD~1"
```

---

## Understanding Our Stack

| Layer | What we use | Where to learn |
|-------|------------|----------------|
| Version control | Git + GitHub | [git-workflow.md](../guidelines/git-workflow.md) |
| Scripting | Bash (POSIX where possible) | [coding-standards.md](../guidelines/coding-standards.md) |
| AI tools | Claude Code, GitHub Copilot | [ai-workflow.md](ai-workflow.md) |
| CI/CD | GitHub Actions | `.github/workflows/` |

---

## First Contribution

1. Pick up an issue labeled `good-first-issue` on GitHub
2. Create a branch: `git checkout -b feat/your-task`
3. Make changes, commit using [conventional commits](../guidelines/coding-standards.md#git-commit-messages)
4. Push and open a PR using the template
5. Request a review from your team lead

---

## FAQs

**Q: I don't understand some existing code — what do I do?**
Paste it into Claude and ask: _"Explain what this code does and why it might be written this way."_ Then ask your team to confirm.

**Q: Which branch do I work on?**
Always branch off `main`. Never commit directly to `main`.

**Q: My PR has been open for more than 2 days without review — what do I do?**
Ping the reviewer on Slack/chat, or re-request review on GitHub.

**Q: I broke something on my local environment — help?**
Run `tools/setup.sh` again. If that doesn't help, open an issue with the `question` label.

**Q: Where do I ask questions?**
- Quick questions → team chat
- Something others should know about → create an issue or add to docs
