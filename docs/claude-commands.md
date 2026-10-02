# Claude Code slash commands

Shared slash commands for Claude Code live in `.claude/commands/`. They work automatically in any session opened in this repo.

## `/spawn-sessions`

Spawns a team of Claude sessions to work through an Asana backlog (or a goal) with the current session as dispatcher/lead PM. It covers:
- clarifying the order first
- Asana short IDs and markers (🔄 ✅ 🙋)
- session titles (🏗️ 🙋 😪 ✅)
- the team protocol (`CLAIM` / `DONE` / `NEXT?` / `LIMIT` / `ACK`)
- epic-based dev teams and the PR budget (one PR per epic plus a roll-up PR)
- owner-comment polling and usage-limit resumes
- a single owner inbox

Usage:

```
/spawn-sessions <Asana project URL or goal> [deadline] [teams=N]
```

## Use it in every repo (global)

Copy it into your user-level commands folder:

```bash
mkdir -p ~/.claude/commands
cp .claude/commands/spawn-sessions.md ~/.claude/commands/
```

Re-run the copy after pulling updates to this file.
