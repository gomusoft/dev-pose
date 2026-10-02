#!/usr/bin/env bash
# ci-audit.sh — advisory audit of a repo's GitHub Actions setup.
#
# Reports duplicate runs, trigger anti-patterns, minutes hygiene, preview
# hygiene and recent run durations as Markdown on stdout.
#
# Usage:
#   tools/ci-audit/ci-audit.sh [--runs N] [--ref REF | --remote] [--strict] <repo-path>
#
#   --runs N    runs sampled per workflow from `gh run list` (default 50)
#   --ref REF   read workflow files from a git ref (e.g. origin/main) instead
#               of the working tree — use when the checkout is on a feature branch
#   --remote    read workflow files from the default branch on GitHub (gh api);
#               most accurate when the local clone is stale
#   --strict    exit 1 when any check is ❌ (default: always exit 0, advisory)
#
# Dependencies: bash, git, gh (authenticated), python3 (stdlib only).
# Read-only: never pushes, edits, or changes anything on GitHub or in the repo.

set -euo pipefail

RUNS=50
REF=""
REMOTE=0
STRICT=0
REPO_PATH=""

usage() { sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --runs) RUNS="${2:?--runs needs a number}"; shift 2 ;;
    --ref) REF="${2:?--ref needs a git ref}"; shift 2 ;;
    --remote) REMOTE=1; shift ;;
    --strict) STRICT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) REPO_PATH="$1"; shift ;;
  esac
done

[ -n "$REPO_PATH" ] || { usage >&2; exit 2; }
[ -d "$REPO_PATH" ] || { echo "not a directory: $REPO_PATH" >&2; exit 2; }
case "$RUNS" in ''|*[!0-9]*) echo "--runs must be a positive integer" >&2; exit 2 ;; esac
for bin in git gh python3; do
  command -v "$bin" >/dev/null || { echo "missing dependency: $bin" >&2; exit 2; }
done

REPO_PATH="$(cd "$REPO_PATH" && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/ci-audit.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/wf"
NOTES="$WORK/notes.txt"
: > "$NOTES"

NWO="$(cd "$REPO_PATH" && gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
DEFAULT_BRANCH=""
if [ -n "$NWO" ]; then
  DEFAULT_BRANCH="$(gh repo view "$NWO" --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || true)"
else
  echo "gh could not resolve a GitHub repo for $REPO_PATH — run-history checks skipped." >> "$NOTES"
fi

# ---- 1. Workflow files ------------------------------------------------------
SOURCE=""
GREP_PATTERN='set-cleanup-policies|cleanup-polic|cleanupPolic|keepCount|"keep_count"|mostRecentVersions'
GREP_OUT="$WORK/grep.txt"
: > "$GREP_OUT"

if [ "$REMOTE" = 1 ]; then
  [ -n "$NWO" ] && [ -n "$DEFAULT_BRANCH" ] || { echo "--remote needs a GitHub repo gh can see" >&2; exit 2; }
  SOURCE="GitHub $NWO@$DEFAULT_BRANCH (--remote)"
  gh api "repos/$NWO/contents/.github/workflows?ref=$DEFAULT_BRANCH" \
    -q '.[] | select(.type=="file") | .name' 2>/dev/null |
    grep -E '\.ya?ml$' | while read -r f; do
      gh api -H "Accept: application/vnd.github.raw" \
        "repos/$NWO/contents/.github/workflows/$f?ref=$DEFAULT_BRANCH" > "$WORK/wf/$f"
    done || true
  # Cleanup-policy references: fetch a bounded set of likely files and grep them.
  gh api "repos/$NWO/git/trees/$DEFAULT_BRANCH?recursive=1" \
    -q '.tree[] | select(.type=="blob" and .size < 200000) | .path' 2>/dev/null |
    grep -v -E '(^|/)(node_modules|vendor|dist|build)/' |
    grep -iE '(cleanup|artifact|registry|retention|deploy|infra|terraform|\.tf$|gcp|cloud-?run)' |
    head -40 | while read -r p; do
      if gh api -H "Accept: application/vnd.github.raw" "repos/$NWO/contents/$p?ref=$DEFAULT_BRANCH" 2>/dev/null |
        grep -qE "$GREP_PATTERN"; then echo "$p" >> "$GREP_OUT"; fi
    done || true
elif [ -n "$REF" ]; then
  git -C "$REPO_PATH" rev-parse --verify --quiet "$REF^{commit}" >/dev/null ||
    { echo "unknown ref: $REF" >&2; exit 2; }
  SOURCE="git ref $REF ($(git -C "$REPO_PATH" rev-parse --short "$REF"))"
  git -C "$REPO_PATH" ls-tree --name-only "$REF" .github/workflows/ 2>/dev/null |
    grep -E '\.ya?ml$' | while read -r p; do
      git -C "$REPO_PATH" show "$REF:$p" > "$WORK/wf/$(basename "$p")"
    done || true
  git -C "$REPO_PATH" grep -lE "$GREP_PATTERN" "$REF" -- . ':!node_modules' 2>/dev/null |
    sed "s|^$REF:||" >> "$GREP_OUT" || true
else
  BR="$(git -C "$REPO_PATH" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
  SOURCE="working tree ($BR @ $(git -C "$REPO_PATH" rev-parse --short HEAD 2>/dev/null || echo '?'))"
  if [ -d "$REPO_PATH/.github/workflows" ]; then
    find "$REPO_PATH/.github/workflows" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) \
      -exec cp {} "$WORK/wf/" \;
  fi
  git -C "$REPO_PATH" grep -lE "$GREP_PATTERN" -- . ':!node_modules' 2>/dev/null >> "$GREP_OUT" || true
  if [ -n "$DEFAULT_BRANCH" ] && [ "$BR" != "$DEFAULT_BRANCH" ]; then
    echo "Workflows were read from branch \`$BR\`, not the default branch \`$DEFAULT_BRANCH\`. Re-run with \`--remote\` (or \`--ref origin/$DEFAULT_BRANCH\`) to audit what actually runs." >> "$NOTES"
  fi
fi

# ---- 2. Run history ---------------------------------------------------------
RUNS_JSON="$WORK/runs.json"
echo '[]' > "$RUNS_JSON"
if [ -n "$NWO" ]; then
  if WF_LIST="$(gh workflow list -R "$NWO" --all --limit 100 --json id,name,path 2>/dev/null)"; then
    printf '%s' "$WF_LIST" | python3 -c 'import json,sys
for w in json.load(sys.stdin): print(w["id"])' | while read -r id; do
      gh run list -R "$NWO" -w "$id" -L "$RUNS" \
        --json databaseId,headSha,event,workflowName,status,conclusion,createdAt,startedAt,updatedAt,headBranch \
        2>/dev/null > "$WORK/runs-$id.json" || echo '[]' > "$WORK/runs-$id.json"
    done
    python3 - "$WORK" <<'PY'
import glob, json, os, sys
work = sys.argv[1]
out = []
for f in glob.glob(os.path.join(work, "runs-*.json")):
    try:
        out += json.load(open(f))
    except ValueError:
        pass
json.dump(out, open(os.path.join(work, "runs.json"), "w"))
PY
  else
    echo "\`gh workflow list\` failed (auth or access?) — run-history checks skipped." >> "$NOTES"
  fi
fi

# ---- 3. Analyse and report -------------------------------------------------
set +e
python3 - "$WORK" "${NWO:-unknown}" "$SOURCE" "$RUNS" <<'PY'
import json, os, re, sys
from collections import Counter, defaultdict
from datetime import datetime

work, nwo, source, nruns = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])

# ---------------------------------------------------------------------------
# Minimal YAML reader (no PyYAML). Handles what GitHub workflows use:
# block maps/lists, "- key: v" list items, flow [..] and {..}, quoted
# scalars, block scalars (| >), comments. Everything scalar stays a string.
# Not supported: anchors/aliases, multi-document, complex keys.
# ---------------------------------------------------------------------------
def strip_comment(s):
    q = None
    for i, c in enumerate(s):
        if q:
            if c == q:
                q = None
        elif c in "'\"":
            q = c
        elif c == "#" and (i == 0 or s[i - 1] in " \t"):
            return s[:i].rstrip()
    return s.rstrip()

def split_flow(s):
    parts, depth, q, cur = [], 0, None, ""
    for c in s:
        if q:
            cur += c
            if c == q:
                q = None
            continue
        if c in "'\"":
            q = c
        elif c in "[{":
            depth += 1
        elif c in "]}":
            depth -= 1
        elif c == "," and depth == 0:
            parts.append(cur.strip())
            cur = ""
            continue
        cur += c
    if cur.strip():
        parts.append(cur.strip())
    return parts

def find_colon(s):
    q, depth = None, 0
    for i, c in enumerate(s):
        if q:
            if c == q:
                q = None
        elif c in "'\"":
            q = c
        elif c in "[{":
            depth += 1
        elif c in "]}":
            depth -= 1
        elif c == ":" and depth == 0 and (i + 1 == len(s) or s[i + 1] in " \t"):
            return i
    return -1

def scalar(s):
    s = s.strip()
    if s.startswith("[") and s.endswith("]"):
        return [scalar(p) for p in split_flow(s[1:-1])]
    if s.startswith("{") and s.endswith("}"):
        d = {}
        for p in split_flow(s[1:-1]):
            k = find_colon(p)
            if k < 0:
                d[unq(p)] = None
            else:
                d[unq(p[:k])] = scalar(p[k + 1:])
        return d
    if s in ("", "~", "null"):
        return None
    return unq(s)

def unq(s):
    s = s.strip()
    if len(s) >= 2 and s[0] == s[-1] and s[0] in "'\"":
        return s[1:-1]
    return s

class Y:
    def __init__(self, text):
        self.lines = text.expandtabs(2).splitlines()
        self.i = 0

    def peek(self):
        while self.i < len(self.lines):
            raw = self.lines[self.i]
            if raw.strip() in ("---",) or not strip_comment(raw).strip():
                self.i += 1
                continue
            return len(raw) - len(raw.lstrip(" ")), strip_comment(raw).strip()
        return None

    def block(self, ind):
        p = self.peek()
        if p is None or p[0] < ind:
            return None
        if p[1] == "-" or p[1].startswith("- "):
            return self.seq(p[0])
        return self.map(p[0])

    def value(self, rest, ind):
        rest = rest.strip()
        if rest == "":
            p = self.peek()
            if p and (p[0] > ind or (p[0] == ind and (p[1] == "-" or p[1].startswith("- ")))):
                return self.block(p[0])
            return None
        if re.match(r"^[|>][+-]?\d*$", rest):
            buf = []
            while self.i < len(self.lines):
                raw = self.lines[self.i]
                if raw.strip() and len(raw) - len(raw.lstrip(" ")) <= ind:
                    break
                buf.append(raw.strip())
                self.i += 1
            return "\n".join(buf).strip()
        if rest[0] in "[{":
            # flow collection possibly spanning lines
            want = {"[": "]", "{": "}"}[rest[0]]
            while rest.count(rest[0]) > rest.count(want) and self.i < len(self.lines):
                rest += " " + strip_comment(self.lines[self.i]).strip()
                self.i += 1
            return scalar(rest)
        # plain/quoted scalar with possible continuation lines
        while self.i < len(self.lines):
            raw = self.lines[self.i]
            if not raw.strip():
                self.i += 1
                continue
            if len(raw) - len(raw.lstrip(" ")) > ind:
                rest += " " + strip_comment(raw).strip()
                self.i += 1
            else:
                break
        return scalar(rest)

    def map(self, ind):
        d = {}
        while True:
            p = self.peek()
            if p is None or p[0] != ind or p[1] == "-" or p[1].startswith("- "):
                break
            line = p[1]
            self.i += 1
            k = find_colon(line)
            if k < 0:
                continue  # not a mapping line; ignore
            d[unq(line[:k])] = self.value(line[k + 1:], ind)
        return d

    def seq(self, ind):
        out = []
        while True:
            p = self.peek()
            if p is None or p[0] != ind or not (p[1] == "-" or p[1].startswith("- ")):
                break
            raw = self.lines[self.i]
            body = raw[ind + 1:]
            sub = len(body) - len(body.lstrip(" "))
            content = strip_comment(body).strip()
            if content == "":
                self.i += 1
                out.append(self.block(ind + 1))
            elif find_colon(content) > 0 and content[0] not in "[{'\"" or (
                    content[0] in "'\"" and find_colon(content) > 0):
                # "- key: value" → map whose keys sit at ind+1+sub
                self.lines[self.i] = " " * (ind + 1 + sub) + body.lstrip(" ")
                out.append(self.map(ind + 1 + sub))
            else:
                self.i += 1
                out.append(self.value(content, ind))
        return out

def load(text):
    try:
        r = Y(text).block(0)
        return r if isinstance(r, dict) else {}
    except Exception as e:  # never let a parse error kill the audit
        return {"__error__": str(e)}

# ---------------------------------------------------------------------------
# Load workflows
# ---------------------------------------------------------------------------
wfdir = os.path.join(work, "wf")
workflows = []
for fn in sorted(os.listdir(wfdir)):
    text = open(os.path.join(wfdir, fn), encoding="utf-8", errors="replace").read()
    doc = load(text)
    on = doc.get("on", doc.get("true"))
    if isinstance(on, str):
        on = {on: None}
    elif isinstance(on, list):
        on = {str(e): None for e in on}
    elif not isinstance(on, dict):
        on = {}
    jobs = doc.get("jobs") if isinstance(doc.get("jobs"), dict) else {}
    workflows.append(dict(file=fn, name=doc.get("name") or fn, doc=doc, on=on,
                          jobs=jobs, text=text, error=doc.get("__error__")))

runs = json.load(open(os.path.join(work, "runs.json")))
notes = [l.strip() for l in open(os.path.join(work, "notes.txt")) if l.strip()]
grep_hits = sorted({l.strip() for l in open(os.path.join(work, "grep.txt")) if l.strip()})

OK, WARN, BAD = "✅", "⚠️", "❌"
results = []  # (section, status, title, detail, fix)
def add(section, status, title, detail="", fix=""):
    results.append((section, status, title, detail, fix))

def as_list(v):
    if v is None:
        return []
    return v if isinstance(v, list) else [v]

def cfg(wf, ev):
    c = wf["on"].get(ev)
    return c if isinstance(c, dict) else {}

def has(wf, ev):
    return ev in wf["on"]

def all_steps(wf):
    for jn, j in wf["jobs"].items():
        if isinstance(j, dict):
            for s in as_list(j.get("steps")):
                if isinstance(s, dict):
                    yield jn, s

def concurrency_of(wf):
    """Workflow-level concurrency, else the job-level ones."""
    c = wf["doc"].get("concurrency")
    groups = []
    if c is not None:
        groups.append(c)
    else:
        for j in wf["jobs"].values():
            if isinstance(j, dict) and j.get("concurrency") is not None:
                groups.append(j["concurrency"])
    out = []
    for g in groups:
        if isinstance(g, dict):
            out.append((str(g.get("group", "")), str(g.get("cancel-in-progress", "false")).lower()))
        else:
            out.append((str(g), "false"))
    return out

DEPLOY_RE = re.compile(r"gcloud\s+run\s+deploy|firebase\s+deploy|vercel\s+(deploy|--prod)|"
                       r"wrangler\s+(deploy|publish)|kubectl\s+apply|helm\s+upgrade|"
                       r"netlify\s+deploy|eas\s+(build|submit|update)|fly\s+deploy|"
                       r"deploy-cloudrun|aws\s+s3\s+sync", re.I)
HEAVY_RE = re.compile(r"\b(npm|pnpm|yarn|bun)\s+(ci|install|i\b|run\s+(build|test)|test|build)|"
                      r"docker\s+build|playwright|gradle|mvn\s|cargo\s+(build|test)|"
                      r"go\s+(build|test)|pytest|flutter\s+(build|test)|xcodebuild|expo\s+export", re.I)
RELEASE_BRANCHES = {"main", "master", "staging", "production", "prod", "release"}

def is_deploy(wf):
    return bool(DEPLOY_RE.search(wf["text"])) or bool(
        re.search(r"deploy|release|publish|preview", wf["file"] + " " + str(wf["name"]), re.I)
        and re.search(r"deploy|docker\s+push|gcloud", wf["text"], re.I))

def pr_types(wf):
    c = cfg(wf, "pull_request")
    t = as_list(c.get("types"))
    return t or ["opened", "synchronize", "reopened"]

def is_preview(wf):
    return is_deploy(wf) and (has(wf, "pull_request") or has(wf, "pull_request_target"))

def is_release(wf):
    if not is_deploy(wf):
        return False
    if re.search(r"release|prod", wf["file"] + " " + str(wf["name"]), re.I):
        return True
    if re.search(r"environment:\s*['\"]?(production|prod)\b", wf["text"]):
        return True
    br = [str(b) for b in as_list(cfg(wf, "push").get("branches"))]
    if br and set(br) <= RELEASE_BRANCHES and not has(wf, "pull_request"):
        return True
    return bool(as_list(cfg(wf, "push").get("tags"))) or has(wf, "release")

def is_heavy(wf):
    return bool(HEAVY_RE.search(wf["text"]))

def wf_label(wf):
    return f"`{wf['file']}`"

# ---------------------------------------------------------------------------
# Section: trigger anti-patterns
# ---------------------------------------------------------------------------
S_TRIG = "Trigger anti-patterns"
FIX_PUSH = """```yaml
on:
  push:
    branches: [main]      # only the branch(es) PRs merge into
  pull_request:           # every other branch is verified via its PR
```"""
FIX_CONC = """```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true
```"""
FIX_DEPLOY_CONC = """```yaml
concurrency:
  # event in the key: a push deploy and a `pull_request: closed` cleanup never cancel each other
  group: ${{ github.workflow }}-${{ github.event_name }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true
```"""
FIX_RELEASE = """```yaml
concurrency:
  group: deploy-release-${{ github.ref }}
  cancel-in-progress: false   # queue, never kill a rollout half-way
```"""

push_all = set()  # workflow names whose YAML still has the push-all + PR pattern
for wf in workflows:
    if wf["error"]:
        add(S_TRIG, WARN, f"{wf_label(wf)} could not be parsed", wf["error"])
        continue
    pr = has(wf, "pull_request") or has(wf, "pull_request_target")
    if has(wf, "push") and pr:
        push = cfg(wf, "push")
        br = [str(b) for b in as_list(push.get("branches"))]
        tags_only = not br and not push.get("branches-ignore") and push.get("tags") is not None
        if tags_only:
            pass
        elif not br or any(b in ("**", "*") for b in br) or push.get("branches-ignore") is not None:
            push_all.add(str(wf["name"]))
            add(S_TRIG, BAD, f"{wf_label(wf)}: `push` on all branches + `pull_request`",
                "Every commit on a PR branch runs twice (push run + PR run, different concurrency groups).",
                FIX_PUSH)
        else:
            extra = [b for b in br if b not in ("main", "master")]
            if extra:
                add(S_TRIG, WARN, f"{wf_label(wf)}: `push` on {', '.join(br)} + `pull_request`",
                    f"A PR whose head is {', '.join(extra)} (e.g. a branch-promotion/cascade PR) re-checks a sha "
                    "that already ran on push. Usually small; see the duplicate-runs section for the real rate.")
            else:
                add(S_TRIG, OK, f"{wf_label(wf)}: push limited to {', '.join(br)}")
    if pr and set(pr_types(wf)) <= {"closed"}:
        pass  # cleanup-only PR trigger: queuing in one static group is fine
    elif pr:
        conc = concurrency_of(wf)
        if not conc:
            add(S_TRIG, BAD if is_heavy(wf) else WARN,
                f"{wf_label(wf)}: PR workflow without `concurrency`",
                "Superseded commits on a PR keep running to completion.", FIX_CONC)
        else:
            for g, cancel in conc:
                keyed = re.search(r"pull_request\.number|event\.number|github\.ref\b|head_ref|github\.ref_name", g)
                if keyed:
                    add(S_TRIG, OK, f"{wf_label(wf)}: concurrency keyed per PR/ref (`{g}`)")
                elif cancel == "true":
                    add(S_TRIG, BAD, f"{wf_label(wf)}: static concurrency group `{g}` with cancel-in-progress",
                        "All PRs share one group, so one PR's run cancels another's.", FIX_CONC)
                else:
                    add(S_TRIG, WARN, f"{wf_label(wf)}: concurrency group `{g}` not keyed by PR",
                        "All PRs queue behind each other.", FIX_CONC)
    if DEPLOY_RE.search(wf["text"]) and has(wf, "pull_request") and "closed" in pr_types(wf):
        other = [e for e in wf["on"] if e in ("push", "workflow_dispatch", "release")]
        for g, cancel in concurrency_of(wf):
            if "event_name" not in g and other:
                add(S_TRIG, BAD if cancel == "true" else WARN,
                    f"{wf_label(wf)}: deploy concurrency `{g}` lacks the event name",
                    f"Handles `pull_request: closed` and {', '.join(other)} in one group — a merge's "
                    "push deploy and the closed-PR cleanup can cancel each other.", FIX_DEPLOY_CONC)
            elif "event_name" in g:
                add(S_TRIG, OK, f"{wf_label(wf)}: deploy concurrency includes the event name")
    if is_release(wf):
        cancels = [g for g, c in concurrency_of(wf) if c == "true"]
        if cancels:
            add(S_TRIG, BAD, f"{wf_label(wf)}: release deploy with `cancel-in-progress: true`",
                "A newer push kills a rollout half-way. Queue releases instead.", FIX_RELEASE)
        else:
            add(S_TRIG, OK, f"{wf_label(wf)}: release deploys are never cancelled")

# ---------------------------------------------------------------------------
# Section: minutes hygiene
# ---------------------------------------------------------------------------
S_MIN = "Minutes hygiene"
FIX_TIMEOUT = """```yaml
jobs:
  verify:
    runs-on: ubuntu-latest
    timeout-minutes: 15   # ~2x the normal duration; default is 360
```"""
FIX_PATHS = """```yaml
# Simple: skip the workflow for docs-only changes (NOT for required checks — a skipped
# workflow leaves a required check "pending" forever).
on:
  pull_request:
    paths-ignore: ["**/*.md", "docs/**"]
# Required check? Use a cheap `changes` job and skip the heavy job instead; a job
# skipped via `if:` reports success to branch protection. See SKILL.md.
```"""
FIX_NODE_CACHE = """```yaml
- uses: actions/setup-node@v4
  with:
    node-version-file: .nvmrc
    cache: npm            # or pnpm / yarn
```"""
FIX_PW = """```yaml
- id: pw
  run: echo "v=$(npx playwright --version | awk '{print $2}')" >> "$GITHUB_OUTPUT"
- id: pw-cache
  uses: actions/cache@v4
  with:
    path: ~/.cache/ms-playwright
    key: playwright-${{ runner.os }}-${{ steps.pw.outputs.v }}
- if: steps.pw-cache.outputs.cache-hit != 'true'
  run: npx playwright install --with-deps chromium
- if: steps.pw-cache.outputs.cache-hit == 'true'
  run: npx playwright install-deps chromium
```"""

for wf in workflows:
    if wf["error"]:
        continue
    missing = []
    for jn, j in wf["jobs"].items():
        if not isinstance(j, dict) or j.get("uses"):
            continue  # reusable-workflow call: timeout not allowed here
        if j.get("timeout-minutes") is None:
            missing.append(jn)
    if missing:
        add(S_MIN, BAD if is_heavy(wf) else WARN,
            f"{wf_label(wf)}: job(s) without `timeout-minutes`: {', '.join(missing)}",
            "A hung job burns up to 360 minutes.", FIX_TIMEOUT)
    elif wf["jobs"]:
        add(S_MIN, OK, f"{wf_label(wf)}: every job has `timeout-minutes`")

    if is_heavy(wf) and (has(wf, "push") or has(wf, "pull_request")):
        filtered = any(cfg(wf, e).get(k) is not None for e in ("push", "pull_request")
                       for k in ("paths", "paths-ignore"))
        gate = re.search(r"dorny/paths-filter|tj-actions/changed-files|git diff --name-only|"
                         r"^\s{2}changes:", wf["text"], re.M)
        if filtered or gate:
            add(S_MIN, OK, f"{wf_label(wf)}: docs-only changes skip heavy work "
                f"({'paths filter' if filtered else 'changes gate'})")
        else:
            add(S_MIN, WARN, f"{wf_label(wf)}: heavy workflow with no docs-only skip",
                "A README typo pays for the full pipeline. (Heuristic: 'heavy' = install/build/test/docker steps.)",
                FIX_PATHS)

    node_steps = [(jn, s) for jn, s in all_steps(wf) if "actions/setup-node" in str(s.get("uses", ""))]
    has_cache_step = "actions/cache" in wf["text"]
    no_cache = [jn for jn, s in node_steps
                if not (isinstance(s.get("with"), dict) and s["with"].get("cache"))]
    if no_cache and not has_cache_step:
        add(S_MIN, WARN, f"{wf_label(wf)}: `setup-node` without `cache` (job: {', '.join(sorted(set(no_cache)))})",
            "Dependencies download from scratch every run.", FIX_NODE_CACHE)
    elif node_steps:
        add(S_MIN, OK, f"{wf_label(wf)}: setup-node caches dependencies")

    if re.search(r"playwright\s+install", wf["text"]):
        if re.search(r"ms-playwright", wf["text"]):
            add(S_MIN, OK, f"{wf_label(wf)}: Playwright browsers cached")
        else:
            add(S_MIN, WARN, f"{wf_label(wf)}: Playwright browsers downloaded every run (no cache)",
                "~150 MB browser download + install each run.", FIX_PW)

# ---------------------------------------------------------------------------
# Section: preview hygiene
# ---------------------------------------------------------------------------
S_PREV = "Preview hygiene"
FIX_TTL = """```yaml
# in the preview workflow
on:
  pull_request:
    types: [opened, synchronize, reopened, closed]
  schedule:
    - cron: "0 3 * * *"        # daily sweep: remove previews older than 7 days
jobs:
  cleanup:
    if: github.event.action == 'closed'
    # gcloud run services update-traffic SERVICE --remove-tags pr-${{ github.event.number }}
```"""
FIX_AR = """```bash
# hard cap: keep the 2 newest images, delete the rest (see SKILL.md for the JSON)
gcloud artifacts repositories set-cleanup-policies REPO \\
  --project=PROJECT --location=REGION --policy=ar-cleanup-policy.json --dry-run
# read the dry-run result, get owner approval, then re-run with --no-dry-run
```"""

previews = [wf for wf in workflows if not wf["error"] and is_preview(wf)]
if not previews:
    add(S_PREV, OK, "No PR preview/deploy workflow found — section not applicable")
else:
    closers = [wf for wf in workflows if has(wf, "pull_request") and "closed" in pr_types(wf)
               and re.search(r"remove-tags|delete|cleanup|clean-up|teardown|prune", wf["text"], re.I)]
    closers += [wf for wf in workflows if has(wf, "delete")
                and re.search(r"remove-tags|delete|cleanup|prune", wf["text"], re.I)]
    sweeps = [wf for wf in workflows if has(wf, "schedule")
              and re.search(r"prune|expire|expiry|cleanup|clean-up|ttl|sweep|older", wf["text"], re.I)]
    ttl = []
    for wf in workflows:
        for m in re.finditer(r"([A-Z_]*(?:TTL|MAX_AGE|EXPIR)[A-Z_]*|ttl[-_]?days|--hours|--days|--max-age(?:-days)?)[\"']?\s*[:=]?\s*[\"']?(\d+)",
                             wf["text"], re.I):
            ttl.append(f"{m.group(1)} {m.group(2)} in `{wf['file']}`")
    names = ", ".join(wf_label(w) for w in previews)
    c_names = ", ".join(sorted({wf_label(w) for w in closers}))
    s_names = ", ".join(sorted({wf_label(w) for w in sweeps}))
    ttl_s = ("TTL seen: " + "; ".join(sorted(set(ttl))[:4])) if ttl else "No explicit TTL value found."
    if closers and sweeps:
        add(S_PREV, OK, f"Preview cleanup: close handler ({c_names}) + scheduled sweep ({s_names})", ttl_s)
    elif closers or sweeps:
        which = f"close handler only ({c_names})" if closers else f"scheduled sweep only ({s_names})"
        add(S_PREV, WARN, f"Preview cleanup: {which}",
            f"Previews for {names}. Owner rule: delete on close AND a 7-day TTL sweep. {ttl_s}", FIX_TTL)
    else:
        add(S_PREV, BAD, f"No preview cleanup for {names}",
            "Neither a `pull_request: closed` handler nor a scheduled sweep — previews live forever.", FIX_TTL)

    pushes_ar = any(re.search(r"-docker\.pkg\.dev", wf["text"]) for wf in workflows)
    if pushes_ar:
        if grep_hits:
            add(S_PREV, OK, "Artifact Registry cleanup policy referenced in: " + ", ".join(f"`{h}`" for h in grep_hits[:5]),
                "Confirm it is applied: `gcloud artifacts repositories list-cleanup-policies REPO --location=REGION`.")
        else:
            add(S_PREV, WARN, "Artifact Registry cleanup policy: verify manually",
                "Images are pushed to *-docker.pkg.dev but no cleanup policy is referenced in the repo. "
                "Check `gcloud artifacts repositories list-cleanup-policies REPO --location=REGION --project=PROJECT`.",
                FIX_AR)

# ---------------------------------------------------------------------------
# Section: duplicate runs + minutes (from run history)
# ---------------------------------------------------------------------------
S_DUP = "Duplicate runs"
S_TIME = "Recent minutes"
CODE_EVENTS = {"push", "pull_request", "pull_request_target", "merge_group"}

def ts(s):
    return datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ") if s else None

by_wf = defaultdict(list)
for r in runs:
    by_wf[r.get("workflowName") or "?"].append(r)

if not runs:
    add(S_DUP, WARN, "No run history available", "; ".join(notes) or "gh returned no runs.")
else:
    any_dup = False
    for name in sorted(by_wf):
        rs = [r for r in by_wf[name] if r.get("event") in CODE_EVENTS]
        if not rs:
            continue
        per_sha, when = defaultdict(list), defaultdict(str)
        for r in rs:
            per_sha[r["headSha"]].append(r["event"])
            when[r["headSha"]] = max(when[r["headSha"]], r.get("createdAt") or "")
        dups = {sha: evs for sha, evs in per_sha.items() if len(evs) > 1}
        if not dups:
            continue
        any_dup = True
        pairs = Counter("+".join(sorted(evs)) for evs in dups.values())
        extra = sum(len(evs) - 1 for evs in dups.values())
        share = extra / len(rs)
        pair_s = ", ".join(f"{k} ×{v}" for k, v in pairs.most_common())
        mixed = any("push" in k and "pull_request" in k for k in pairs)
        only_pr = all(set(k.split("+")) == {"pull_request"} for k in pairs)
        last = max(when[sha] for sha in dups)[:10]
        detail = (f"{len(dups)} of {len(per_sha)} commits ran more than once; {extra} extra of {len(rs)} runs "
                  f"({share:.0%}). Event pairs: {pair_s}. Last duplicate: {last}.")
        wfm = next((w for w in workflows if str(w["name"]) == name), None)
        noisy = [t for t in (pr_types(wfm) if wfm else []) if t in ("edited", "labeled", "unlabeled", "closed")]
        if only_pr and noisy:
            add(S_DUP, OK, f"`{name}`: repeated pull_request runs on one sha (expected)",
                detail + f" The workflow triggers on `{', '.join(noisy)}`, which re-runs on the same sha by design.")
        elif only_pr:
            detail += (" Same-sha pull_request repeats are usually re-runs, `edited`/`closed`/`labeled` events, "
                       "or the same commit in two PRs — check the workflow's `types:`.")
            add(S_DUP, WARN if share >= 0.1 else OK, f"`{name}`: repeated pull_request runs on one sha", detail)
        elif mixed and wfm and name not in push_all:
            pbr = [str(b) for b in as_list(cfg(wfm, "push").get("branches"))] if wfm else []
            extra_br = [b for b in pbr if b not in ("main", "master")]
            why = (f" Consistent with `push` on {', '.join(extra_br)} + `pull_request`: a promotion/cascade PR "
                   "re-checks a sha already checked on push." if extra_br else
                   " The audited YAML no longer has the push-all pattern, so these may predate a fix — "
                   "confirm the next PR shows exactly one run per commit.")
            add(S_DUP, WARN, f"`{name}`: commits ran on both push and pull_request", detail + why)
        elif mixed:
            add(S_DUP, BAD if share >= 0.1 else WARN, f"`{name}`: commits run on both push and pull_request",
                detail, FIX_PUSH if share >= 0.1 else "")
        else:
            add(S_DUP, WARN, f"`{name}`: duplicate runs", detail)
    if not any_dup:
        add(S_DUP, OK, f"No commit ran twice in the same workflow (sampled ≤{nruns} runs/workflow)")

    known = {str(w["name"]) for w in workflows}
    unseen = sorted(n for n in by_wf if n not in known and n != "?")
    if unseen and workflows:
        notes.append("Run history includes workflows not in the audited files: " + ", ".join(f"`{n}`" for n in unseen)
                     + " (renamed, deleted or dynamic" + ("" if "--remote" in source else "; or the audited tree is stale — try `--remote`") + ").")

    rows, tot_all, n_all = [], 0.0, 0
    for name in sorted(by_wf):
        ds = []
        for r in by_wf[name]:
            a, b = ts(r.get("startedAt")), ts(r.get("updatedAt"))
            if r.get("status") == "completed" and a and b and b >= a:
                ds.append((b - a).total_seconds() / 60)
        if not ds:
            continue
        rs = by_wf[name]
        first = min(r["createdAt"] for r in rs)[:10]
        last = max(r["createdAt"] for r in rs)[:10]
        failed = sum(1 for r in rs if r.get("conclusion") == "failure")
        cancelled = sum(1 for r in rs if r.get("conclusion") == "cancelled")
        rows.append((sum(ds), name, len(ds), sum(ds) / len(ds), first, last, failed, cancelled))
        tot_all += sum(ds)
        n_all += len(ds)
    rows.sort(reverse=True)
    table = ["| Workflow | Runs | Avg min | Total min | Failed | Cancelled | Window |",
             "|---|---:|---:|---:|---:|---:|---|"]
    for tot, name, n, avg, first, last, failed, cancelled in rows:
        table.append(f"| {name} | {n} | {avg:.1f} | {tot:.0f} | {failed} | {cancelled} | {first} → {last} |")
    if n_all:
        table.append(f"| **All** | {n_all} | {tot_all / n_all:.1f} | {tot_all:.0f} | | | |")
    add(S_TIME, OK if n_all else WARN, f"{n_all} completed runs, {tot_all:.0f} wall-clock minutes total",
        "\n".join(table) + "\n\n_Heuristic: wall-clock run time (start → last update). Billed minutes are "
        "per job, rounded up per job, and summed across parallel jobs — usually higher._")

# ---------------------------------------------------------------------------
# Render
# ---------------------------------------------------------------------------
order = [S_DUP, S_TRIG, S_MIN, S_PREV, S_TIME]
count = Counter(s for _, s, *_ in results)
print(f"# CI audit — {nwo}\n")
print(f"- Workflows: {source} — {len(workflows)} file(s)")
print(f"- Run sample: up to {nruns} runs per workflow, {len(runs)} runs total")
print(f"- Result: {count[BAD]} ❌, {count[WARN]} ⚠️, {count[OK]} ✅ (advisory)")
for n in notes:
    print(f"- Note: {n}")
print("\n_YAML is read with a small built-in parser and the deploy/heavy/release classifications are "
      "regex heuristics — confirm a finding in the file before changing it._")
for sec in order:
    items = [r for r in results if r[0] == sec]
    if not items:
        continue
    print(f"\n## {sec}\n")
    rank = {BAD: 0, WARN: 1, OK: 2}
    for _, st, title, detail, fix in sorted(items, key=lambda r: rank[r[1]]):
        print(f"- {st} {title}")
        if detail:
            if "\n" in detail:
                print("\n" + detail + "\n")
            else:
                print(f"  - {detail}")
        if fix and st != OK:
            print("\n  <details><summary>Suggested fix</summary>\n")
            print("\n".join("  " + l if l else "" for l in fix.splitlines()))
            print("\n  </details>\n")

sys.exit(3 if count[BAD] else 0)
PY
rc=$?
set -e

if [ "$STRICT" = 1 ] && [ "$rc" = 3 ]; then exit 1; fi
if [ "$rc" != 0 ] && [ "$rc" != 3 ]; then
  echo "ci-audit: analysis failed (python exit $rc)" >&2
  exit "$rc"
fi
exit 0
