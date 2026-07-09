# HOW-TO — Report CI / PR / build issues that need Gregor's attention

When any automated step (CI run, PR check, merge, deploy) fails or gets blocked and needs
Gregor's attention or a decision, report it so he can jump straight to the evidence — never
just a prose description.

## Required format, per issue

- **Direct link(s)** to the exact place to check: the failing Actions run URL, the repo/PR URL,
  and the commit SHA (short) if relevant. Never make him navigate — link the run, not just the repo.
- **What failed** — the specific job/step name.
- **Reason** — the actual error line from the log (not a paraphrase), one line if possible.
- **Whether it's related to the change in flight** — pre-existing/unrelated failures (env, infra,
  flaky CI) should be called out as such, distinct from failures caused by the diff being shipped.

## Example

> **DocFlow PR #1669** — https://github.com/FELLOWPRO/DocBits_DocFlow/pull/1669
> Failing job: `Build and Package` — https://github.com/FELLOWPRO/DocBits_DocFlow/actions/runs/29006428109/job/86078986379
> Reason: `install: cannot create regular file '/usr/local/bin/trivy': Permission denied`
> Pre-existing — same failure already present on `dev` before this PR (unrelated to the diff).

## Why

Prose summaries without links force a manual hunt through the repo/Actions UI. A direct link lets
Gregor triage in one click and decide fix-now vs. defer, without re-deriving what already broke.
