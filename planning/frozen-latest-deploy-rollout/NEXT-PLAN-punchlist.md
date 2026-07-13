# Frozen/Latest Rollout — Punch List for the Next Plan

Source: full ground-truth re-derivation on 2026-07-13 (`overview.html`, `how-it-works.html`, and the two follow-up mechanism checks — frozen-overlay minimalism, region-file support). This is scope input for the next plan, not the plan itself.

---

## 1. Resolve the operator-celery / fulltext-celery frozen placeholder

Both were meant to onboard together under DOCB-13528. Neither reached `main`; both are live in the cluster anyway via unmerged branches. They need different endings, not one fix:

- **fulltext-celery**: live, healthy, correctly queue-isolated (`--queues=frozen-fulltext-live,...`) in EU dev-frozen/stage-frozen + US sandbox-frozen. The fix works. → merge `docb-13528-fulltext-celery-frozen-reenable` (commit `c114e5af`) to `main`, un-exclude it in `registry.yaml`, update DOCB-13528's stale "scaled to 0" comment to reflect the fix is live.
- **operator-celery**: live in the same 3 namespaces but with **no queue isolation** — consuming the same `doc-operator-tasks` queue as regular `dev`/`latest`, i.e. live cross-channel task-bleed risk. The app itself doesn't support a parameterized queue name (`start_celery.sh` hardcodes it) — this needs an app-level fix in `DocBits_Operator`, not just a values-file change. → decide: fix properly (app change + merge `docb-13528-operator-celery-frozen-onboard`), or scale operator-celery to 0 in the 3 live namespaces until it's safe, then un-exclude in `registry.yaml` once actually isolated.
- Either way: reconcile `registry.yaml`'s declared exclusions with whatever the final decision is, so the file stops lying about what's actually running.

## 2. Re-audit every ticket closed "Won't Do" — one subagent per ticket

These were bulk-closed 2026-07-10 while several describe risks independently confirmed still live. Don't batch this — each ticket makes a distinct technical claim that needs its own live-cluster/code/deployment check, then a per-ticket verdict (confirm-close / reopen / comment-only).

| Ticket | Claim to verify | Known signal already |
|---|---|---|
| DOCB-13530 | ConfigMap-naming mismatch audit | Never actually done, closed anyway |
| DOCB-13531 | US-region data in EU auth ConfigMap | Bug not actually fixed |
| DOCB-13532 / 13540 | Unmanaged-clone Helm-ownership mechanism | Fate genuinely undecided elsewhere; doc2-api now shows a *new* instance of this same class |
| DOCB-13533 / 13541 | operator/fulltext-celery queue isolation | Contradicts live state directly — see item 1 above, highest priority |
| DOCB-13534 | Beats channel readiness (api-beats/fulltext-beat/docnet-beats) | Ticket admits it was never tracked, closes anyway |
| DOCB-13535 / 13543 | doc2-api unmanaged bespoke pipeline | Contradicts live state directly — doc2-api serving live frozen traffic out-of-band right now |
| DOCB-13536 / 13539 | Legacy-service stage-frozen verification (OCR/Extraction/BarCode/PO-Matching/Auto-Accounting/DocFlow) | Verification gap for the sandbox-frozen wave is real, unaudited |

Plan shape: one investigation subagent per ticket (or per closely-linked pair), each checking the specific live/code claim, reporting a verdict with evidence — same pattern as this session's Step 04/recheck agents. Synthesize into a single go/no-go list at the end; still no autonomous Jira writes without sign-off.

## 3. Validate every still-open ticket's status against ground truth

Not just the Won't-Do set — the epic's In Progress / Business Analysis tickets haven't been checked against real code/cluster state either, only against each other's Jira status. Step-by-step:

1. Pull current Jira status + description for each of: DOCB-13489 (+13495, 13496, 13527), DOCB-13491 (+13499, 13500, 13501), DOCB-13492 (+13503, 13504, 13505 — note 13504 already flagged as overlapping the closed clone-ownership tickets), DOCB-13508/13509 (+ subtasks, Business Analysis).
2. Cross-check each against live cluster/PR/code state, same method as item 2.
3. Flag any mismatch (ticket says in-progress but code shows done, or vice versa).
4. Produce a tackle order — likely: finish anything genuinely still open, close anything actually done, and surface anything that's silently stalled.

## Carried over from the overview (not new, just don't drop these)

- doc2-api's two mismatched Helm `release-namespace` annotations (EU stage-frozen says `stage`, US dev-frozen says `dev`) + fully-unmanaged `api-celery` everywhere it runs.
- DevOps#383 (further-channel promotion automation) and #384 (demo/prod-frozen scaffolding) — both still open, unmerged.
- `auto-accounting-service`'s entry in `deploy-branches.yaml` still says `add-frozen: false` on `main` despite being fully onboarded and live — trigger-config file just never got re-synced.
- `DocBits_Fulltext_AI` — confirmed real (not a typo), distinct from `DocBits_FullText`, still unidentified/unexplained. Needs someone to just ask what it is.
- `sandbox-frozen` unmanaged Helm clones — already owned by the sibling plan (`plans/2026-07-10-sandbox-frozen-provisioning.html`), just don't let it get lost.
