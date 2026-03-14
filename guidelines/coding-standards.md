# Coding Standards

Consistency beats perfection. These standards exist so the team spends less time debating style and more time building.

---

## Universal Rules (All Languages)

- **Readability first**: Code is read 10× more than it's written
- **One responsibility per function/module**
- **Names should explain intent**: `getUserById()` not `get()`
- **Avoid magic numbers**: use named constants
- **Delete dead code** — don't comment it out
- **No committed secrets**: use `.env` files and `.gitignore`

---

## Naming Conventions

| Context | Convention | Example |
|---------|-----------|---------|
| Variables/functions | `camelCase` | `getUserData` |
| Classes/types | `PascalCase` | `UserService` |
| Constants | `UPPER_SNAKE_CASE` | `MAX_RETRIES` |
| Files (most languages) | `kebab-case` | `user-service.ts` |
| Shell scripts | `snake_case` | `setup_ssl.sh` |
| Database columns | `snake_case` | `created_at` |
| Git branches | `kebab-case` with prefix | `feat/user-auth` |

---

## Git Commit Messages

Follow the **Conventional Commits** format:

```
<type>(<scope>): <short summary>

[optional body]
[optional footer]
```

**Types:**
- `feat` — new feature
- `fix` — bug fix
- `docs` — documentation only
- `refactor` — code restructure, no behavior change
- `test` — adding or updating tests
- `chore` — tooling, dependencies, config

**Examples:**
```
feat(auth): add JWT refresh token support
fix(api): handle null response from user endpoint
docs(onboarding): add Docker setup instructions
```

> **AI Tip**: Use `git diff --staged | claude -p "Write a conventional commit message for these changes"` to auto-generate commit messages.

---

## Shell Scripts

- Always include a usage header:
  ```bash
  #!/usr/bin/env bash
  # Usage: ./script-name.sh [options]
  # Description: What this script does
  # Dependencies: list any required tools
  ```
- Use `set -euo pipefail` at the top for safe execution
- Quote all variables: `"$var"` not `$var`
- Use `local` for function-scoped variables
- Test with `shellcheck` before committing

---

## File Organization

- Keep files under **300 lines**; split if larger
- Group related files in directories — flat is fine for small tools
- Every directory should have a `README.md` explaining its contents

---

## Documentation

- Public functions/APIs need a short comment explaining their purpose
- Don't document *what* the code does — document *why* if it's not obvious
- Keep `README.md` up to date when changing behavior

---

## AI-Assisted Coding

AI tools (Claude, Copilot, etc.) are encouraged. When using them:

- **Review everything AI generates** — you're responsible for the code
- Don't commit AI-generated code you don't understand
- Use AI for: boilerplate, refactoring, test cases, documentation drafts
- See [docs/ai-workflow.md](../docs/ai-workflow.md) for team AI practices
