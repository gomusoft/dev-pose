#!/usr/bin/env python3
"""Plan and apply the standard Discord project structure.

Reads the server, compares each project with the five-channel standard from the
discord-project-management skill, prints a diff, and applies it only with --yes.
Standard library only. The bot token is never printed.

    discord_sync.py plan  --config projects.json [--project cw]
    discord_sync.py apply --config projects.json [--project cw] --yes
"""
import argparse
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

API = "https://discord.com/api/v10"
STANDARD = ["talk", "design-and-specs", "playground", "ai-updates", "ai-alerts"]
# Unambiguous legacy names (including a common typo) -> standard channel.
# Anything else must be mapped explicitly in the project's "map" config.
ALIASES = {
    "talk": "talk", "discussion": "talk",
    "design-and-specs": "design-and-specs", "design": "design-and-specs",
    "playground": "playground", "playgroud": "playground",
    "ai-updates": "ai-updates",
    "ai-alerts": "ai-alerts",
}
TEXT, CATEGORY = 0, 4


def get_token():
    token = os.environ.get("DISCORD_BOT_TOKEN")
    if token:
        return token
    service = os.environ.get("DISCORD_KEYCHAIN_SERVICE", "devpose-manager-discord-bot-token")
    try:
        out = subprocess.run(
            ["security", "find-generic-password", "-a", os.environ.get("USER", ""), "-s", service, "-w"],
            capture_output=True, text=True, check=True)
    except (OSError, subprocess.CalledProcessError):
        sys.exit(f"No token: set DISCORD_BOT_TOKEN or add Keychain item '{service}'.")
    return out.stdout.strip()


def call(token, method, path, body=None, reason=None):
    """One Discord REST call with simple 429 retry. Returns parsed JSON."""
    for _ in range(5):
        req = urllib.request.Request(
            API + path, method=method,
            data=json.dumps(body).encode() if body is not None else None,
            headers={"Authorization": f"Bot {token}", "Content-Type": "application/json",
                     "User-Agent": "DiscordBot (devpose-discord-sync, 1)"})
        if reason:
            req.add_header("X-Audit-Log-Reason", reason)
        try:
            with urllib.request.urlopen(req) as r:
                raw = r.read()
                return json.loads(raw) if raw else None
        except urllib.error.HTTPError as e:
            payload = e.read().decode()
            if e.code == 429:
                time.sleep(float(json.loads(payload).get("retry_after", 1)) + 0.1)
                continue
            sys.exit(f"Discord {e.code} on {method} {path}: {payload}")
    sys.exit(f"Gave up after repeated rate limits on {method} {path}")


def channel_name(prefix, standard):
    return f"{prefix}{standard}"


def plan_project(project, channels):
    """Pure function: returns (ops, notes). ops are dicts; nothing is sent."""
    ops, notes = [], []
    code = project.get("code")
    prefix = f"{code}-" if project.get("mode", "shared") == "shared" else ""
    if project.get("mode", "shared") == "shared" and not code:
        raise ValueError(f"{project['name']}: shared mode needs a project code")
    extra = {k: v for k, v in project.get("map", {}).items()}
    for v in extra.values():
        if v not in STANDARD:
            raise ValueError(f"{project['name']}: map target '{v}' is not a standard channel")

    cats = [c for c in channels if c["type"] == CATEGORY and c["name"] == project["category"]]
    if len(cats) > 1:
        raise ValueError(f"{project['name']}: category name '{project['category']}' is ambiguous")
    if not cats:
        if not project.get("create_category"):
            raise ValueError(f"{project['name']}: category '{project['category']}' not found")
        cat_ref = {"new_category": project["name"]}
        ops.append({"op": "create_category", "name": project["name"]})
        children = []
    else:
        cat = cats[0]
        cat_ref = {"parent_id": cat["id"]}
        if cat["name"] != project["name"]:
            ops.append({"op": "rename_category", "id": cat["id"], "from": cat["name"], "to": project["name"]})
        children = [c for c in channels if c.get("parent_id") == cat["id"] and c["type"] == TEXT]

    claimed = set()
    for std in STANDARD:
        want = channel_name(prefix, std)
        exact = next((c for c in children if c["name"] == want), None)
        if exact:
            claimed.add(exact["id"])
            continue
        legacy = next((c for c in children if c["id"] not in claimed
                       and (extra.get(c["name"]) or ALIASES.get(c["name"])) == std), None)
        if legacy:
            claimed.add(legacy["id"])
            ops.append({"op": "rename_channel", "id": legacy["id"], "from": legacy["name"], "to": want})
        else:
            ops.append({"op": "create_channel", "name": want, **cat_ref})
    for c in children:
        if c["id"] not in claimed:
            notes.append(f"left alone (no mapping): #{c['name']}")
    # Warn when a target name already exists in another category (the ambiguity we remove).
    targets = {o["to"] if o["op"] == "rename_channel" else o["name"] for o in ops if o["op"].endswith("channel")}
    for c in channels:
        if c["type"] == TEXT and c["name"] in targets and c.get("parent_id") not in {x.get("id") for x in cats}:
            notes.append(f"name collision: #{c['name']} already exists in another category")
    return ops, notes


def describe(op):
    if op["op"] == "rename_category":
        return f"rename category  '{op['from']}' -> '{op['to']}'"
    if op["op"] == "rename_channel":
        return f"rename channel   #{op['from']} -> #{op['to']}"
    if op["op"] == "create_category":
        return f"create category  '{op['name']}'"
    return f"create channel   #{op['name']}"


def run(args):
    cfg = json.load(open(args.config))
    token = get_token()
    guild = cfg["guild_id"]
    projects = [p for p in cfg["projects"] if not args.project or p.get("code") == args.project]
    if not projects:
        sys.exit("No matching project in config.")
    all_ops = []
    for p in projects:
        channels = call(token, "GET", f"/guilds/{guild}/channels")
        ops, notes = plan_project(p, channels)
        print(f"\n== {p['name']} ({p.get('code', 'no prefix')}) ==")
        for o in ops:
            print("  " + describe(o))
        for n in notes:
            print("  note: " + n)
        if not ops:
            print("  already conforms")
        all_ops.append((p, ops))
        if args.cmd == "apply" and args.yes:
            apply_ops(token, guild, p, ops)
    total = sum(len(o) for _, o in all_ops)
    if args.cmd == "plan":
        print(f"\n{total} change(s) planned. Nothing was changed. Re-run with 'apply --yes' to execute.")
    elif not args.yes:
        sys.exit("Refusing to apply without --yes.")
    else:
        print(f"\n{total} change(s) applied.")


def apply_ops(token, guild, project, ops):
    reason = f"devpose-discord-sync: {project['name']}"
    new_cat_id = None
    for o in ops:
        if o["op"] == "rename_category" or o["op"] == "rename_channel":
            call(token, "PATCH", f"/channels/{o['id']}", {"name": o["to"]}, reason)
        elif o["op"] == "create_category":
            new_cat_id = call(token, "POST", f"/guilds/{guild}/channels",
                              {"name": o["name"], "type": CATEGORY}, reason)["id"]
        else:
            parent = o.get("parent_id") or new_cat_id
            call(token, "POST", f"/guilds/{guild}/channels",
                 {"name": o["name"], "type": TEXT, "parent_id": parent}, reason)
        print("  done: " + describe(o))


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("cmd", choices=["plan", "apply"])
    ap.add_argument("--config", required=True)
    ap.add_argument("--project", help="only this project code")
    ap.add_argument("--yes", action="store_true", help="required for apply")
    run(ap.parse_args())
