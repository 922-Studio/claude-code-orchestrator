# HOW-TO — Write commit messages & PR descriptions

Read this **before authoring any commit message, PR title/body, or push description** for a
*target* repo. It applies to every code-changing task the orchestrator drives.

---

## The rule

Commit and PR text describes **the change and why it was made** — the story of the diff, as it
matters to someone reading that repo's history. It **never** describes the orchestration process
that produced it.

The orchestrator's planning apparatus (plans, phases, waves, steps, executor/reviewer agents) is an
**internal device**. It has no meaning to a reader of the target repo, it's noise in the log, and it
can leak private process and local file paths into a shared or public repo. Keep it out.

## Never appears in commit/PR text

- Plan names, slugs, or file paths (`plans/2026-…`, "per the kicker-v6 plan")
- The words **plan, phase, wave, step N, execution overview, wave 1/2/3** as framing for the change
- Agent/orchestration vocabulary: "executor agent", "reviewer agent", "orchestrator", "sub-agent"
- Internal sequencing or dependency notes ("this is step 3 of 5", "blocks wave 2")
- Anything a contributor to *that repo alone* would find meaningless

## Always describes

- **What changed** — the behavior, feature, or fix, and the code area it touches
- **Why** — the problem solved or the reason for the change
- **Impact** — user- or contract-visible effects, breaking changes, migrations
- **Repo-native references** — issue/PR numbers, tickets that live in *that* repo

## Examples

| ❌ Don't | ✅ Do |
|---|---|
| `feat: kicker-v6 wave 2 step 3 — total playtime` | `feat: add per-player total-playtime stat to the stats hub` |
| `fix: execute plan 2026-07-08 step 4b e2e gate` | `fix: make guest→account link-merge e2e deterministic in the serial suite` |
| `chore: reviewer agent follow-ups from wave 1` | `chore: address review — narrow type on getTeamStats, drop dead import` |
| PR body: "Implements Wave 1 of the ledger plan (steps 1–4)…" | PR body: "Adds immutable invoice snapshots and the Person receiver model. Persists invoices on create; PDF export unchanged. Closes #40." |

## Where the plan tracking goes instead

Step/phase/wave progress and plan-file references are tracked in the **orchestrator's own** `plans/`
(and its commits, which live in this private repo) — not in the target repo's commit or PR text.
That keeps the internal narrative where it belongs and the target repo's history clean.

> If a task instruction elsewhere says "reference the plan file in the PR", this rule overrides it
> for *target-repo* PRs: the plan reference stays in the orchestrator's local plan tracking.
