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

## Write it for someone who knows nothing about the task

This is the part that's easy to get wrong. The TL;DR is **not** a condensed version of
your technical findings — it's a plain-language status line for a reader who has no
context on the work at all and never will.

- **High level only.** What happened, what state it's in now, what (if anything) anyone
  has to do. No cert chains, no resource names, no command output, no jargon.
- **Say it the way you'd say it out loud** to a colleague walking past your desk.
- Include at most one concrete date or number, and only if it's genuinely the thing
  people need to remember.

Good — a reader with zero context understands it:

> **TL;DR** — New certificate created and rolled out to all affected services, tested
> live and validated. Everything is working again. Closing the ticket. The next renewal
> is due August 2027 and won't happen automatically.

Too technical — this is a summary *of the details*, not a summary *for people*:

> ~~**TL;DR** — Issuer rotated; leaf certs chain to the new root and fail verification
> against the old root; webhook serving certs expire 2027-08-06 ahead of the issuer.~~

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

## Quick test before you post

Read only the TL;DR and ask: *would a colleague who has never heard of this task
understand what happened and whether anything is needed from them?*

If they'd need to read further to get the gist, it's still written for you — rewrite it
higher-level. Everything below the TL;DR is for whoever reopens the ticket in a year;
the TL;DR itself is for everyone who never will.

## Related

- `HOW-TO-report-ci-issues.md` — the equivalent reporting format for CI/PR/deploy failures.
