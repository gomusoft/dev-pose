# CI Guidelines

The rules every repo's GitHub Actions setup should follow. The `ci-audit` skill
(`.claude/skills/ci-audit/SKILL.md`) checks most of them automatically with
`tools/ci-audit/ci-audit.sh` and has the YAML for each fix.

> Examples use mock names (`acme-shop`, `acme-nonprod`). Real project names stay in each project's own repo.

---

## 1. The rules

### 1.1 Save Actions minutes

Private repos have a monthly minutes budget. Every run has to earn its cost.

- **One run per commit per workflow.** `push` only on the branches PRs merge into (`main`, plus `dev`/`staging` in promotion setups); every other branch is checked through its `pull_request` run. Never `push: branches: ['**']` together with `pull_request`.
- **Cancel superseded runs.** PR workflows use `concurrency` keyed by PR number with `cancel-in-progress: true`.
- **Docs-only changes skip heavy work.** `paths-ignore` for non-required workflows; a cheap `changes` job plus `if:` on the heavy job for required checks, so the check still reports green.
- **Cache dependencies and browsers.** `setup-node` with `cache:`, Playwright browsers in `actions/cache`.
- **Timeouts on every job** — about 2× the normal duration. The default (360 minutes) turns one hung job into a month's budget.

### 1.2 Fail fast

- Cheapest, most-often-failing gates first: format / generated-file sync → lint → typecheck → unit tests → build → browser install → e2e.
- A red step stops the job; don't add `continue-on-error` to quality gates.
- Upload artifacts (screenshots, reports) with `if: failure()` or `if: always()` so a failure is diagnosable without a re-run.

### 1.3 Previews

- Host PR previews on **Cloud Run** in the **non-prod** project: one tagged, no-traffic revision per PR (`pr-<n>`), `min-instances 0`.
- **7-day TTL.** Label each preview with `expires=<date>`; a scheduled sweep removes expired ones, and the `pull_request: closed` handler removes the PR's preview immediately. Both — the sweep catches what the close event misses.
- **Hard cap of 2 images** in Artifact Registry (owner decision 2026-10-03): a cleanup policy that keeps the 2 newest versions and deletes every other one, committed to the repo as JSON so it is reviewable.
- **Previews never touch production data or production credentials.** Fake/seed data only; the preview's deploy identity has no role in the production project.

### 1.4 Deploys

- Deploy concurrency includes `github.event_name` whenever one workflow handles both `push` and `pull_request: closed`, so a merge deploy and a preview cleanup never cancel each other.
- **Never cancel a release** (`staging`/`production`): `cancel-in-progress: false`. A queued rollout is fine; a half-finished one is not.
- Keyless auth (Workload Identity Federation); separate identities for non-prod and prod.
- Production deploys run in a GitHub `environment` with required reviewers.

### 1.5 Every push needs owner approval

- Agents never push (branches, force-push, tags) without the owner's explicit yes **for that push**. Approval never carries over to the next push.
- When work is push-ready, the agent proposes the push with a brief: branch and target, commit subjects, what changed, why it's ready (CI state, what was run), what's not covered, anything irreversible or outward-facing.
- Workflow changes include the `ci-audit` result for the branch in that brief.
- Cloud changes (cleanup policies, deleting revisions/images) and new third-party actions follow the same rule: propose the exact change, show the dry run or security check, wait for approval.

---

## 2. Known patterns

Seen in real repos; each has a check in `ci-audit.sh`.

| Pattern | Symptom | Fix |
|---|---|---|
| `push: branches: ['**']` + `pull_request` in different concurrency groups | Every PR commit runs CI twice (~2× minutes) | `push: branches: [main]` + `pull_request` (SKILL §4.1) |
| `push` on `dev`/`staging` + cascade / promotion PRs (`dev → staging`) | The promotion PR re-checks a sha that already ran on push (a few % of runs) | Usually accept; optionally skip PR runs whose head is a pushed branch |
| Deploy concurrency without the event name, workflow also handles `pull_request: closed` | Merge deploy cancelled by the closed-PR cleanup; merge looks green, URL never moves | `group: deploy-${{ github.event_name }}-${{ github.ref }}` (SKILL §4.3) |
| Release deploy with `cancel-in-progress: true` | A newer push kills a production rollout half-way | `cancel-in-progress: false` |
| Heavy CI with no docs-only skip | A README edit costs a full build + e2e | Changes gate that still reports green (SKILL §4.4) |
| Playwright installed every run | ~150 MB download per run | Cache `~/.cache/ms-playwright` by version (SKILL §4.6) |
| Preview with a TTL sweep but no close handler (or the reverse) | Merged PRs' previews linger up to the TTL, or forever | Both: `closed` handler + scheduled sweep (SKILL §4.7) |
| Images pushed to Artifact Registry with no cleanup policy | Storage grows with every PR commit | Keep-2 / 30-day policy (SKILL §4.7) |

**Good references to copy from:** a preview workflow with `paths-ignore` for docs, an `expires` label and `TTL_DAYS: 7`; deploy workflows with the event in the concurrency key and releases that never cancel; a single `preview-cleanup` workflow that runs on PR close, branch delete and a schedule.

---

## 3. Checking a repo

```bash
tools/ci-audit/ci-audit.sh --remote <path-to-repo>
```

Then follow `.claude/skills/ci-audit/SKILL.md` §3 (read the report) and §5 (verify the fix against run history).
