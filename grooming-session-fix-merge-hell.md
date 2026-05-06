# Grooming session — fix merge hell

> **Objective (repeat this throughout the session):**
> "We are fixing 3–4 hour merges and broken code after merge — by integrating earlier, smaller, knowing which branch belongs in which environment, and with Claude catching what humans miss."

---

## ⏱️ 0–5 min — Ground it in your team's reality

Don't open with Git theory. Open with what your team lived.

- Merges taking 3–4 hours
- Functions that worked before the merge — broken after
- "Pull main daily" was tried. It didn't fix it.

Then land the diagnosis before going anywhere else:

> **"This is not a Git command problem. It's a workflow problem."**

---

## 🔍 5–20 min — Three root causes

Don't just say "merge conflicts happen." Show *why yours are so painful.*

### Root cause 1 — `git pull` gives false safety

When someone on a feature branch runs `git pull origin main`, Git brings down the latest main — but the branch is still diverging every day they work. Nobody's aware of each other's changes until PR time.

```bash
# This feels safe. It isn't.
git pull origin main   # ← you're still diverging all day
```

**The problem:** "I'm up to date" feels true. It isn't. You're up to date *at that moment* — then you immediately start falling behind again.

---

### Root cause 2 — Late integration stacks conflicts

```
Day 1:  Branch A ──────────────────────────────> PR (4 days of diff)
Day 1:  Branch B ──────────────────────────────> PR (4 days of diff)
                                                        ↑
                                               merge war starts here
```

Everyone works in isolation. Integration happens at the end. 4 days of divergence = merge war. Nobody meant to create a 4-day diff. It just accumulated.

> **"Big merge pain = integration happened too late"**

---

### Root cause 3 — Git merges text. Devs must merge logic.

Git sees lines. It has no idea what your function does. A merge can complete with zero conflicts — and still produce broken behavior, because two logically incompatible changes were combined.

> **"Merge succeeded" ≠ "code works." That's why the old function breaks.**

---

## ⚙️ 20–35 min — New workflow (non-negotiable)

### Daily habit — rebase, don't just pull

```bash
git fetch origin
git rebase origin/main   # replays your commits on top of latest main
# then: run code, verify behavior
```

**Why rebase instead of merge?** Rebase replays your commits on top of the latest main — giving you a clean linear history and surfacing conflicts *one commit at a time*, not one giant pile at PR time.

---

### Before opening a PR

- Branch is rebased on current main
- Code runs locally end-to-end
- Clear PR description — what changed *and why*, not just which files

---

### PR rules

- Max 1–2 days of work per PR. If it's bigger, break it up.
- Reviewer checks **logic**, not just syntax. "Looks good" is not a review.
- No blind approvals. If you don't understand it, say so.

---

### Merge responsibility

> **"Whoever merges owns the result."**

This means: understand both sides of every conflict you resolve. Verify behavior after the merge lands. If you're not sure what a conflict means — ask, or ask Claude.

---

## 🧪 35–50 min — Live demo

Run this in the terminal during the session. Two scenarios, same setup, completely different outcome.

---

### Scenario A — the bad path (what your team has been doing)

**Setup:**

```bash
git checkout main
git checkout -b feature/payments   # Dev A
# open a second terminal
git checkout main
git checkout -b feature/auth       # Dev B
```

**Day 1–4:** Both devs modify the same function in `utils.js`

Dev A — payments branch:
```js
function processUser(user) {
  // added payment fields
  user.paymentId = uuid();
  user.balance = 0;
  return user;
}
```

Dev B — auth branch:
```js
function processUser(user) {
  // added auth fields
  user.token = generateToken();
  user.role = 'viewer';
  return user;
}
```

**Day 4: Dev A merges first. Dev B opens PR.**

```bash
git checkout main
git merge feature/payments   # ✓ clean merge
git merge feature/auth       # CONFLICT in utils.js
```

What happens next:
- 3-hour conflict session begins. Both devs sit down together.
- Conflict resolved — merge succeeds. "Looks clean."
- Login stops working. `user.token` is undefined.

**Why:** Git merged the text. Nobody merged the logic. The payments branch version of `processUser` won — and it never sets a token.

---

### Scenario B — the right path (what we're enforcing from now on)

**Same setup. Same two changes. Different outcome.**

**Day 1:** Both devs branch off main. Each runs `git fetch && git rebase origin/main` at the start of every day.

**Day 2:** Dev A merges payments PR. Dev B runs daily rebase — sees a small conflict immediately. It's 4 lines, not 200. Resolved in 5 minutes. Dev B verifies locally and continues working.

**Day 3:** Dev B opens PR. GitHub Actions triggers Claude Code automatically.

**Claude Code posts this comment on the PR:**

> **PR review — feature/auth**
>
> **Summary:** Adds `token` and `role` fields to `processUser()`.
>
> **Logic check:** `processUser` in main now also sets `paymentId` and `balance` (from the payments PR merged yesterday). This PR does not touch those fields — they will be preserved. No breaking change detected.
>
> **Edge case flagged:** If `generateToken()` throws, `user.role` is never set. Recommend wrapping in try/catch or asserting token success before setting role.
>
> **Suggested test:** Verify that a user processed through both payment and auth flows has all 4 fields populated.

**Merge takes 3 minutes. No 3-hour session. No broken login.**

---

## 🤖 GitHub Actions setup — Claude Code in the loop

### Step 1 — Install

Fastest path: open Claude Code in terminal and run:

```bash
/install-github-app
```

This installs the GitHub app, configures secrets, and creates a starter workflow automatically.

Manual path: install [github.com/apps/claude](https://github.com/apps/claude), then add `ANTHROPIC_API_KEY` to repository secrets under Settings → Secrets and variables → Actions.

---

### Workflow 1 — automatic PR review on every open

```yaml
# .github/workflows/claude-pr-review.yml
name: Claude PR review
on:
  pull_request:
    types: [opened, synchronize]

permissions:
  contents: read
  pull-requests: write

jobs:
  review:
    runs-on: ubuntu-latest
    steps:
      - uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          direct_prompt: |
            Review this PR diff. Check for:
            - logic conflicts with recent main changes
            - functions modified that could affect other features
            - edge cases and missing error handling
            Post findings as a PR comment. Be specific.
```

---

### Workflow 2 — @claude on demand in comments

```yaml
# .github/workflows/claude-interactive.yml
name: Claude interactive
on:
  issue_comment:
    types: [created]
  pull_request_review_comment:
    types: [created]

permissions:
  contents: read
  pull-requests: write

jobs:
  claude:
    runs-on: ubuntu-latest
    steps:
      - uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          # no prompt needed — responds to @claude mentions in comments
```

Any dev can now tag `@claude` in a PR comment during a conflict:

> `@claude here's the conflict in processUser(). Dev A added paymentId and balance. Dev B added token and role. We resolved by keeping all 4 fields — is the merge result safe?`

---

### CLAUDE.md — give it context about your team

Create a `CLAUDE.md` file in the repo root. Claude reads it automatically in every CI run.

```markdown
## CI/CD context

When reviewing PRs:
- Never approve blind — always check logic, not just syntax
- Flag any function modified that is shared across features
- If two branches touched the same function, explain both versions
- Suggest tests for any new logic added

## Merge checklist

After merge, verify: auth flow, payment flow, and user creation
all still work end-to-end.
```

---

### What Claude Code can do in this workflow

| Use case | How to trigger |
|---|---|
| Automatic PR review on every open | Workflow 1 fires on `pull_request` event |
| Explain both sides of a conflict | Comment `@claude` + paste the conflict block |
| Generate tests for new changes | Comment `@claude generate unit tests for this diff` |
| Triage a CI failure | Comment `@claude the CI is failing, here are the logs` |

> **Rule:** AI suggests. You are accountable. A broken merge you didn't understand is still your broken merge.

---

## 🌍 50–55 min — Environment rules (new topic)

Right now there's no clear rule for which branch deploys to which environment. That means devs are guessing — and guessing wrong causes incidents that have nothing to do with code quality.

### The problem

When nobody agrees on "which branch goes where," you get:

- A dev tests on local, it works — deploys to dev, it breaks
- Someone deploys a feature branch directly to dev, overwriting someone else's work
- Nobody knows what's actually running in dev right now
- Hotfixes get applied to the wrong place

> **"If you don't know which branch is in which environment, you can't trust any environment."**

---

### The rule — branch to environment map

Start simple. You have two environments. Lock this down first before adding more.

| Environment | Branch | Who deploys | When |
|---|---|---|---|
| **Local** | your feature branch | you | any time, your machine only |
| **Dev** | `main` | CI/CD only (never manual) | automatically on every merge to `main` |

**What this means in practice:**

- `main` is the only branch that ever touches dev
- Feature branches live on local until they pass PR review and merge
- Nobody manually deploys anything to dev — if you need to test something in dev, it goes through a PR first
- If dev is broken, `main` is broken — that's a team problem, not a "my branch" problem

---

### The rule for future environments (when you add them)

Document this now so the pattern is set before you need it.

| Environment | Branch | Purpose |
|---|---|---|
| Local | feature branch | dev sandbox, only your machine |
| Dev | `main` | integrated, always up to date |
| SIT | `release/*` or `staging` | QA testing, stable builds only |
| UAT | `release/*` | client / business sign-off |
| Prod | `main` (tagged) | live, tagged releases only |

The pattern: **each environment has exactly one source branch. No exceptions.**

---

### What breaks when there's no rule

Run through this scenario with the team:

1. Dev A deploys `feature/payments` to dev to test
2. Dev B deploys `feature/auth` to dev to test
3. Dev A's deployment overwrites Dev B's
4. Dev B says "my feature is broken in dev" — but actually it's just gone
5. Both devs spend an hour debugging something that isn't a code bug

This is not a rare edge case. This is what happens every time two people treat dev as their personal sandbox.

---

### GitHub Actions — auto-deploy to dev on merge to main

Add this workflow so dev is always exactly what's in `main` — no manual deploys, no guessing.

```yaml
# .github/workflows/deploy-dev.yml
name: Deploy to dev
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Deploy to dev
        run: |
          # replace with your actual deploy command
          echo "Deploying to dev environment..."
          # e.g. kubectl apply, docker push, eb deploy, etc.

      - uses: anthropics/claude-code-action@v1
        if: failure()
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          direct_prompt: |
            The deploy to dev just failed after merging to main.
            Read the deploy logs and explain what went wrong.
            Post a clear summary as a comment on the latest commit.
```

Claude Code fires automatically if the deploy fails — reads the logs, posts a plain-language explanation on the commit. No more "deploy failed, figure it out yourself."

---

### Checklist addition — environment

Add these to your PR template:

- [ ] I tested this on **local** only — not dev
- [ ] This PR targets `main` (not a direct deploy branch)
- [ ] I am not manually deploying this branch to any shared environment

---

## 📋 55–58 min — The checklist

Post this on the team wiki. Add it to your PR template description.

### Dev — daily

- [ ] `git fetch && git rebase origin/main`
- [ ] Run code after rebase, verify behavior
- [ ] Keep changes small (max 1–2 days of work)

### Before opening a PR

- [ ] Branch rebased on current main
- [ ] Works locally end-to-end
- [ ] Clear PR description (what changed and why)
- [ ] Tested on **local only** — not deployed to dev manually

### Before merging

- [ ] Read Claude's review comment
- [ ] Understand every conflict you resolved
- [ ] Verify behavior after merge lands

---

## 🚫 58–60 min — Set expectations honestly

- Conflicts won't disappear
- But they will be **smaller, faster, and understandable**
- If a merge still takes hours → the process wasn't followed, not the process doesn't work

### Enforce it structurally (optional but powerful)

Process that's optional gets skipped under pressure. Process that's enforced becomes habit.

- Protect `main` — no direct pushes
- Require branch to be up-to-date before merge is allowed
- Block merge until Claude review posts (add it as a required status check)
- Add a basic CI smoke test on every PR — even a single test that runs changes behavior

---

## Bottom line

> Shift the team from **late, painful, big-bang integration** → **continuous, small, boring integration** — with a clear rule for every environment so nobody is guessing what's running where.

Claude Code in GitHub Actions is the enforcement layer on top — it catches the logic conflicts that a successful merge still misses, explains deploy failures in plain language, and does all of it before anyone has to sit in a room together for 3 hours.
