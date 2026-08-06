# HOW-TO — write Jira comments

> Applies to every Jira comment written on Gregor's behalf, on any ticket, in any project.

## The rule: always lead with a TL;DR

Every Jira comment **must** open with a TL;DR section — **1–2 lines**, at the very top,
before any other content. Treat it like an email subject line or an executive summary.

**Why:** nobody reads the full comment. The only person who ever will is someone
investigating the same issue again months later. Everyone else — the assignee scanning
notifications, a manager checking status, a colleague pulled in mid-thread — reads the
first two lines and nothing else. If the important information isn't there, it doesn't
reach them.

## What goes in it

The 1–2 most important facts for *someone else*, not for the author:

- Is it fixed, in progress, or blocked?
- What is the impact or the action someone needs to take?
- The single number, date, or name that matters most.

Put the detail — root cause, timeline, validation output, follow-ups — **below** the
TL;DR, under headings, for the future investigator.

## Format

```
TL;DR — <status>. <the one thing that matters most.>

---

## <detailed sections follow>
```

Keep it plain prose. No bullet list inside the TL;DR itself — it should read as one or
two sentences.

## Example

> **TL;DR** — Resolved. Linkerd CA rotated on fra1-polydocs, production restored and
> validated; next cert expiry is **2027-08-06** (webhook certs, not the issuer) and there
> is no auto-renewal.

Everything that follows — the root cause, the blast radius, the validation evidence, the
six follow-ups — is for whoever reopens this in a year.

## Related

- `HOW-TO-report-ci-issues.md` — the equivalent reporting format for CI/PR/deploy failures.
