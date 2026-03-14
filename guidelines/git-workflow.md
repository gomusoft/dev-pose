# Git Workflow

Our workflow is based on **GitHub Flow** — simple, branch-based, and designed for continuous delivery.

---

## Branch Strategy

```
main
 └── feat/user-auth          ← feature branch
 └── fix/login-null-crash    ← bug fix
 └── docs/update-readme      ← documentation
 └── chore/upgrade-deps      ← maintenance
```

| Branch prefix | Purpose |
|--------------|---------|
| `feat/` | New features |
| `fix/` | Bug fixes |
| `docs/` | Documentation changes |
| `refactor/` | Code restructuring |
| `chore/` | Tooling, deps, CI |
| `test/` | Adding/fixing tests |

**Rules:**
- Never commit directly to `main`
- Branch names use `kebab-case`
- Delete branches after merging

---

## Daily Workflow

```bash
# 1. Start from an up-to-date main
git checkout main && git pull

# 2. Create your branch
git checkout -b feat/your-feature

# 3. Work, stage, commit in small increments
git add -p                          # stage hunks interactively
git commit -m "feat(scope): message"

# 4. Keep your branch updated
git fetch origin
git rebase origin/main              # prefer rebase over merge

# 5. Push and open PR
git push -u origin feat/your-feature
```

---

## Commit Best Practices

- **Commit early, commit often** — small commits are easier to review and revert
- Each commit should leave the repo in a working state
- Use `git add -p` to stage only relevant changes per commit
- Write the commit message in **imperative mood**: "Add X" not "Added X"

> **AI Tip — Generate commit messages:**
> ```bash
> git diff --staged | claude -p "Write a conventional commit message"
> ```
> Or with Claude Code: stage your files, then run `/commit`

---

## Pull Requests

### Before opening a PR:
1. Self-review your diff: `git diff origin/main...HEAD`
2. Rebase on latest main to avoid merge conflicts
3. Make sure CI passes locally (run linter, tests)

### PR size guideline:
- **< 200 lines** — ideal, fast to review
- **200–400 lines** — acceptable with clear description
- **> 400 lines** — consider splitting

### PR description template:
Use our [PR template](.github/PULL_REQUEST_TEMPLATE.md) — it auto-fills when you open a PR.

> **AI Tip — Generate PR descriptions:**
> ```bash
> git log origin/main..HEAD --oneline | claude -p "Write a concise PR description with summary and test plan"
> ```

---

## Code Review

- Review within **1 business day**
- Use GitHub's suggestion feature for one-line fixes
- **Approve** when satisfied — don't leave it in limbo
- Use labels: `needs-review`, `changes-requested`, `approved`

> **AI Tip — Speed up code review:**
> Paste a diff into Claude: _"Review this code for bugs, security issues, and improvements"_

---

## Merging

- Use **Squash and Merge** for feature branches (clean history on main)
- Use **Merge Commit** for release branches (preserve history)
- Delete the branch after merging

---

## Hotfix Process

```bash
git checkout main && git pull
git checkout -b fix/critical-bug-description
# fix → commit → PR → fast review → merge
```

Hotfixes bypass normal review timelines but still require at least one approval.
