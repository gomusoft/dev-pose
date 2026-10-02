# Discord Automation Setup

Goal: manage Discord for any project (categories, channels, renames, webhooks) with **one bot**, without doing it by hand, from either a local Claude session or Claude Remote.

This document is the step-by-step plan. It complements the [`discord-project-management`](../.claude/skills/discord-project-management/SKILL.md) skill, which defines *what* the structure is. This defines *how it gets applied*.

> Placeholder convention: names below (`Acme Shop` / `as`) are mock. Never write real project names, server IDs, or tokens into this repository.

---

## 1. Design at a glance

```
 Claude (local or Remote)
        │
        ├── local session ──► tools/discord CLI ──► token from macOS Keychain ─┐
        │                                                                      ├─► Discord API
        └── Claude Remote ──► gh workflow run discord-setup ──► Actions ───────┘
                                   (token is a GitHub secret; Claude never sees it)
```

- **One Discord bot** is invited to every server (shared or dedicated).
- **One idempotent script** does the work, with `--dry-run`. Both paths run the same script.
- **Per-project config** (name, mode, code) lives in the target repo or a private place, not here.

### Decisions

| Decision | Choice | Why |
|---|---|---|
| Credential | Bot token, not a personal user token | User tokens ("self-bots") violate Discord ToS and carry all your permissions |
| Local secret storage | macOS Keychain (or gitignored `.env`) | Never leaves your machine |
| Remote secret storage | GitHub Actions secret | Only workflows can read it; Claude can trigger but not see it |
| Not recommended | Token in Claude's cloud env vars | Anything Claude runs could read it |

---

## 2. Your steps (one-time, manual)

### Step 1: Create the bot

1. Open the [Discord Developer Portal](https://discord.com/developers/applications) and click **New Application**. Name it e.g. `DevPose Manager`.
2. Go to **Bot**. Click **Reset Token** and copy it somewhere temporary. You will store it in Step 3.
3. Leave **Privileged Gateway Intents** all **off**. REST calls need none.
4. Turn **Public Bot** off so nobody else can invite it.

### Step 2: Invite the bot to a server

1. Go to **OAuth2 → URL Generator**.
2. Scopes: `bot`.
3. Bot permissions (only these, **not Administrator**):
   - Manage Channels
   - Manage Webhooks
   - View Channels
   - Send Messages
4. Open the generated URL and add the bot to your server. Repeat for each dedicated server later.
5. In the server, make sure the bot's role is above any role it must manage, and has access to the target Category.

### Step 3: Store the token

Local (macOS Keychain):

```bash
security add-generic-password -a "$USER" -s discord-bot-token -w
# paste the token at the prompt
```

Read it back in scripts with:

```bash
security find-generic-password -a "$USER" -s discord-bot-token -w
```

GitHub (for the Remote path). Use a **private** repo for the workflow if possible:

```bash
gh secret set DISCORD_BOT_TOKEN --repo <owner>/<repo>
```

Never commit the token. `.env` must be gitignored.

### Step 4: Collect IDs

1. In Discord: **User Settings → Advanced → Developer Mode** on.
2. Right-click the server icon → **Copy Server ID** (the *guild ID*).
3. Keep it with the project's private config, not in this repo.

### Step 5: Let the workflow write webhook secrets into target repos

The script creates webhooks for `ai-updates` and `ai-alerts` and stores each URL as a secret in the project's repo.

1. Create a **fine-grained PAT** (or a GitHub App) limited to the target repos with **Secrets: Read and write**.
2. Store it:

```bash
gh secret set TARGET_REPO_PAT --repo <owner>/<repo>
```

### Step 6: Restrict who can run it

- Keep the workflow `workflow_dispatch` only.
- Put it behind a GitHub **Environment** with you as required reviewer, if you want an approval gate.
- Webhook URLs are secrets: the workflow masks them in logs.

---

## 3. What gets built (Claude's steps, in PRs)

| Phase | Deliverable |
|---|---|
| 1 | `tools/discord/`: core script. Create or verify Category and the five channels, rename, topics, `--dry-run` diff. Idempotent. |
| 2 | Webhook creation for `ai-updates` / `ai-alerts`, URL written to the target repo with `gh secret set`. |
| 3 | `.github/workflows/discord-setup.yml` (`workflow_dispatch`, inputs: project config, mode, dry-run). |
| 4 | Update the `discord-project-management` skill to call the CLI (local) or `gh workflow run` (Remote), and to default to dry-run first. |
| 5 | Pilot on one local project directory, then roll out to others. |

### Project config (lives in the target repo, e.g. `.discord/project.json`)

```json
{
  "project": "Acme Shop",
  "mode": "shared",
  "code": "as",
  "guildId": "<server id>",
  "webhooks": ["ai-updates", "ai-alerts"]
}
```

`mode` is `shared` (prefixed channel names) or `dedicated` (plain names), per the skill.

---

## 4. Usage once built

```bash
# local: preview, then apply
tools/discord/run --config .discord/project.json --dry-run
tools/discord/run --config .discord/project.json

# Remote: Claude triggers the workflow
gh workflow run discord-setup -f config=<path-or-inline> -f dry_run=true
```

---

## 5. Safety checklist

- [ ] Bot is private (Public Bot off) and has no Administrator permission
- [ ] Token only in Keychain and the GitHub secret, never in git
- [ ] Real project names, IDs, and webhook URLs are not in this repo
- [ ] Workflow is dispatch-only, optionally behind an Environment approval
- [ ] First run on any project is `--dry-run`
- [ ] Rotate the bot token if it is ever pasted somewhere it should not be

## 6. Open questions

1. Will this repo stay public? If yes, host the workflow in a private repo.
2. Which local project is the pilot, and is it in the shared server or a dedicated one?
3. PAT or GitHub App for writing webhook secrets to target repos?
