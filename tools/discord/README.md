# tools/discord

Plans and applies the standard project structure from the
[`discord-project-management`](../../.claude/skills/discord-project-management/SKILL.md) skill.
Python 3 standard library only.

```bash
# read-only: print the diff, change nothing
python3 tools/discord/discord_sync.py plan  --config ~/.config/devpose/discord-projects.json
# execute exactly what plan shows (refuses without --yes)
python3 tools/discord/discord_sync.py apply --config ~/.config/devpose/discord-projects.json --yes
# one project only
python3 tools/discord/discord_sync.py plan  --config ... --project cw
python3 -m unittest discover tools/discord
```

- **Token:** `DISCORD_BOT_TOKEN`, or the Keychain item named by `DISCORD_KEYCHAIN_SERVICE`
  (default `devpose-manager-discord-bot-token`). Never printed.
- **Config:** see `projects.example.json`. Keep the real one **outside this repo** (it has real project names).
  `category` is the current category name; the category is renamed to `name`. `map` assigns
  non-obvious legacy channels to a standard one. `create_category` creates a missing category.
- **Behavior:** idempotent. Renames legacy channels (`design`, `discussion`, `playgroud`, ...) to
  `<code>-<standard>`, creates missing ones, never deletes, and lists unmapped channels untouched.
  Renames keep message history. Every change carries an audit-log reason.
