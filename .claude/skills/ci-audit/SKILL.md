---
name: ci-audit
description: Check, verify and fix a project's GitHub Actions build/CI. Use when setting up or reviewing CI, when "CI runs twice" on a PR, when Actions minutes look too high, when a deploy or preview workflow misbehaves (cancelled deploys, previews that never go away, Artifact Registry growing), and before proposing a push that touches `.github/workflows/`. Runs the read-only `tools/ci-audit/ci-audit.sh` audit, explains how to read it, gives the standard fixes as YAML, and ends with a verification step against real run history.
---

# CI Audit

Use this skill to answer three questions about any repo's CI, with evidence:

1. **Is it doing the work once?** (no duplicate runs, no runs that cancel each other)
2. **Is it cheap?** (fail fast, caches, timeouts, docs-only changes skip heavy work)
3. **Does it clean up after itself?** (PR previews expire, images don't pile up)

House rules behind every recommendation: `docs/ci-guidelines.md`.

> **Placeholder convention:** examples use mock names (`acme-shop`, project `acme-nonprod`). Never write a real project name, GCP project ID or service-account email into this repository.

---

## 1. When to use

- Setting up CI for a new repo, or reviewing an existing `.github/workflows/`.
- Someone says "every PR runs CI twice", "Actions minutes are running out", "the deploy got cancelled", "old previews are still up".
- **Before proposing a push** that changes a workflow file — run the audit on the branch (`--ref` or working tree) and include the result in the push brief.
- Periodically (e.g. monthly) across all active repos.

## 2. Run the audit

The script is read-only: it reads workflow files and `gh run list` history and never changes anything locally or on GitHub. It needs `git`, an authenticated `gh`, and `python3` (stdlib only — no PyYAML).

```bash
# from a dev-pose checkout
tools/ci-audit/ci-audit.sh --remote ~/work/acme-shop          # what actually runs (default branch on GitHub)
tools/ci-audit/ci-audit.sh ~/work/acme-shop                   # the working tree (your branch, incl. uncommitted edits)
tools/ci-audit/ci-audit.sh --ref origin/main ~/work/acme-shop # a specific ref, without checking it out
tools/ci-audit/ci-audit.sh --runs 100 --remote ~/work/acme-shop
tools/ci-audit/ci-audit.sh --strict ~/work/acme-shop          # exit 1 if any ❌ (for scripts)
```

Pick the source deliberately:

| Question | Use |
|---|---|
| "What is wrong with CI right now?" | `--remote` |
| "Does my fix on this branch work?" | working tree (no flag) |
| "Compare against another branch" | `--ref <ref>` |

The run-history sections always come from GitHub (the last `--runs` runs per workflow, default 50), whichever source the YAML came from.

## 3. Read the report

Each line is ✅ fine, ⚠️ worth a look, ❌ costing minutes or correctness now. Every ⚠️/❌ that has a standard fix includes a collapsed **Suggested fix**.

| Section | What it tells you | Notes |
|---|---|---|
| **Duplicate runs** | Commits (`headSha`) that ran more than once in one workflow, grouped by event pair (`pull_request+push`, `pull_request+pull_request`, …), with the last date it happened | Evidence, not theory. A `pull_request+push` pair means the double-trigger anti-pattern. History can predate a fix — check "Last duplicate". Same-sha `pull_request` repeats on a workflow with `types: [edited]` / `closed` are expected. |
| **Trigger anti-patterns** | `push` on every branch + `pull_request`; PR workflows without concurrency or with a static group; deploy workflows whose concurrency key lacks `github.event_name` while also handling `pull_request: closed`; release deploys that `cancel-in-progress` | Classification of "deploy" / "release" is a regex heuristic. |
| **Minutes hygiene** | Jobs without `timeout-minutes`; heavy workflows with no docs-only skip; `setup-node` without `cache`; Playwright browsers downloaded every run | "Heavy" = install/build/test/docker steps (heuristic). |
| **Preview hygiene** | PR preview workflows: is there a close handler AND a scheduled TTL sweep, what TTL was found, is an Artifact Registry cleanup policy referenced | The AR policy usually lives in GCP, not the repo — "verify manually" means run the `gcloud` command shown. |
| **Recent minutes** | Per-workflow run count, average and total minutes, failed/cancelled counts | Wall-clock run time. Billed minutes are per job and rounded up, so usually higher. |

Always confirm a finding in the YAML before editing — the parser is small and the classifications are heuristics.

## 4. Standard fixes

### 4.1 One run per commit: push only where PRs merge

The classic double run: `push: branches: ['**']` plus `pull_request`. The push run and the PR run land in different concurrency groups, so neither cancels the other and every PR pays twice.

```yaml
on:
  push:
    branches: [main]        # the branch(es) PRs merge into — verifies the merge result
  pull_request:             # every other branch is verified through its PR
```

Repos with `dev → staging → main` promotion: `push: branches: [dev, staging, main]` is fine, but a promotion/cascade PR whose head is `dev` re-checks a sha that already ran on push. That overlap is usually a few percent — accept it, or skip the PR run when the head branch is itself a pushed branch (only if the push run is a required check, otherwise you lose the gate).

### 4.2 Concurrency keyed by PR

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true
```

A new commit on a PR cancels the superseded run. `github.ref` alone also works for PRs (`refs/pull/<n>/merge`), but never use a static group with `cancel-in-progress: true` — PRs would cancel each other.

### 4.3 Deploy workflows: event in the key, never cancel a release

```yaml
# preview / prototype deploy that handles push AND pull_request: closed
concurrency:
  group: deploy-preview-${{ github.event_name }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true      # within one stream, newer supersedes older

# staging / production release
concurrency:
  group: deploy-release-${{ github.ref }}
  cancel-in-progress: false     # queue; a half-finished rollout is worse than a late one
```

Without the event name, a merge's `push` deploy and the `pull_request: closed` cleanup of the same branch share a group and the second cancels the first — the merge looks green but the URL never moved.

### 4.4 Docs-only changes skip heavy work — without breaking required checks

If the workflow is **not** a required status check, a paths filter is enough:

```yaml
on:
  pull_request:
    paths-ignore: ["**/*.md", "docs/**"]
```

If it **is** required, a skipped *workflow* leaves the check "Expected — waiting" forever and blocks merge. Skip the *job* instead: a job skipped by `if:` reports success.

```yaml
jobs:
  changes:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    outputs:
      code: ${{ steps.diff.outputs.code }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - id: diff
        env:
          BASE: ${{ github.event.pull_request.base.sha || github.event.before }}
        run: |
          if [ -z "$BASE" ] || [ "$BASE" = "0000000000000000000000000000000000000000" ] ||
             git diff --name-only "$BASE" HEAD | grep -qvE '(\.md$|^docs/)'; then
            echo "code=true" >> "$GITHUB_OUTPUT"
          else
            echo "code=false" >> "$GITHUB_OUTPUT"
          fi

  verify:                      # the required check
    needs: changes
    if: needs.changes.outputs.code == 'true'
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps: [...]
```

This uses plain `git` on purpose — no third-party action to vet.

### 4.5 Fail fast: cheap → expensive, timeouts everywhere

Order steps so the cheapest gates that catch the most breakage run first:

1. install (cached) → 2. format / generated-file sync → 3. lint → 4. typecheck → 5. unit tests → 6. build → 7. browser install → 8. e2e

Every job gets `timeout-minutes` at roughly 2× its normal duration (the default is 360). Split into parallel jobs only when the wall-clock saving is worth paying the per-job setup and rounding twice.

### 4.6 Caching

```yaml
- uses: actions/setup-node@v4
  with:
    node-version-file: .nvmrc
    cache: npm                 # or pnpm (after pnpm/action-setup) / yarn

# Playwright browsers (~150 MB) keyed by the installed version
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
  run: npx playwright install-deps chromium   # OS packages are not cached
```

### 4.7 Cloud Run per-PR previews with TTL

One preview service in the **non-prod** project, one tagged no-traffic revision per PR, an `expires` label, delete on close, and a daily sweep for anything the close event missed. Previews use fake/seed data only — never production data or production credentials.

```yaml
name: Deploy preview
on:
  pull_request:
    types: [opened, synchronize, reopened, closed]
    paths-ignore: ["**/*.md", "docs/**"]
  schedule:
    - cron: "0 3 * * *"          # daily TTL sweep

concurrency:
  group: preview-${{ github.event_name }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true

permissions:
  contents: read
  id-token: write                # Workload Identity Federation, no SA keys
  pull-requests: write

env:
  PROJECT: acme-nonprod
  REGION: asia-southeast1
  SERVICE: acme-preview
  TTL_DAYS: 7

jobs:
  deploy:
    if: github.event_name == 'pull_request' && github.event.action != 'closed'
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      # checkout, google-github-actions/auth (WIF), setup-gcloud, docker build + push ...
      - run: |
          EXPIRES=$(date -u -d "+${TTL_DAYS} days" +%F)
          gcloud run deploy "$SERVICE" --image "$IMAGE" \
            --project "$PROJECT" --region "$REGION" \
            --tag "pr-${{ github.event.number }}" --no-traffic \
            --min-instances 0 --max-instances 1 \
            --labels "env=preview,expires=${EXPIRES}" --quiet

  cleanup:
    if: github.event.action == 'closed'
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      # auth + setup-gcloud ...
      - run: |
          gcloud run services update-traffic "$SERVICE" \
            --project "$PROJECT" --region "$REGION" \
            --remove-tags "pr-${{ github.event.number }}" --quiet || true

  sweep:
    if: github.event_name == 'schedule'
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      # auth + setup-gcloud ...
      # For each tagged revision whose `expires` label is before today: remove the tag,
      # then delete revisions that serve no traffic and carry no tag.
      - run: scripts/preview-sweep.sh --project "$PROJECT" --region "$REGION" --service "$SERVICE"
```

Artifact Registry cleanup policy for the preview repository — keep the 2 newest images, delete anything older than 30 days (`ar-cleanup-policy.json`):

```json
[
  {
    "name": "keep-2-newest",
    "action": { "type": "Keep" },
    "mostRecentVersions": { "keepCount": 2 }
  },
  {
    "name": "delete-older-than-30d",
    "action": { "type": "Delete" },
    "condition": { "tagState": "ANY", "olderThan": "30d" }
  }
]
```

```bash
# dry run first (the default), read the result, then apply — a cloud change: owner approval required
gcloud artifacts repositories set-cleanup-policies acme-preview \
  --project=acme-nonprod --location=asia-southeast1 --policy=ar-cleanup-policy.json --dry-run
gcloud artifacts repositories list-cleanup-policies acme-preview \
  --project=acme-nonprod --location=asia-southeast1
```

`Keep` wins over `Delete`, so the 2 newest always survive. Images younger than 30 days are kept regardless — for a hard cap of 2, shorten `olderThan`. Put production images in a separate repository with its own (longer) policy so rollbacks stay possible, and commit the policy JSON to the repo so the audit can see it.

## 5. Verify the fix

A fix is not done until the run history agrees.

1. Re-run the audit on the branch (working tree): the ❌ should be gone.
2. After the change is pushed (owner-approved) and a PR is open, push one more commit and check that commit ran **exactly once per workflow**:

   ```bash
   SHA=$(git rev-parse HEAD)
   gh run list --commit "$SHA" --json workflowName,event,status,conclusion \
     -q '.[] | "\(.workflowName)\t\(.event)\t\(.status)\t\(.conclusion)"'
   ```

   One line per workflow, event `pull_request`. Two lines for the same workflow (`push` + `pull_request`) means the fix is not live yet — the workflow that runs for a PR is the one on the PR branch, so check you are looking at the right commit.
3. After merge, check the merge commit on `main` ran once, on `push`.
4. Re-run `ci-audit.sh --remote` a week later: "Duplicate runs" should show no new pairs after the fix date ("Last duplicate").

## 6. Guardrails

- The audit is read-only. Fixing is a normal code change: branch, commit, and **ask the owner before every push** with the usual push brief (branch, commits, what changed, CI state, what's not covered, anything outward-facing).
- No new third-party actions or tools without the owner's approval and a security check (pin by SHA, check the maintainer).
- Anything in GCP (cleanup policies, deleting revisions or images) is a cloud change: propose the exact command, run the dry run, and wait for approval.
- Never point a preview at production data or production credentials.
