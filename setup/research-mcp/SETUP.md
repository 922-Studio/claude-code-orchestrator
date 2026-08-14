# SETUP — Web research MCP (Exa)

**id:** `research-mcp` · **type:** Claude Code plugin (hosted MCP server) · **platform:** any

## What it does
Gives Claude **semantic web search, content extraction, and multi-step research** instead of the
built-in `WebSearch`, whose two limits hurt for this ecosystem: it is **US-only** and returns titles
plus short snippets rather than page content.

Exa's search is neural — it retrieves pages that are conceptually related to a query, not only
keyword matches — and it can return page contents in the same call. Companion setup: `docs-mcp`
covers pinned library documentation locally; this one covers the open web.

## Why Exa and not Tavily / Firecrawl / Context7
Chosen on free-tier headroom, because research bursts are spiky and a hard cap mid-investigation is
worse than a slightly weaker engine (figures as of August 2026):

| Service | Free tier | Notes |
|---|---|---|
| **Exa** | **20 000 requests/month** | ~20× the others; $7 per 1 000 beyond |
| Tavily | 1 000 credits/month | advanced search = 2 credits, one Research call = 4–250 → effectively far less |
| Context7 | 1 000 calls/month + ~60/hour | docs only; the hourly cap is what bites mid-session → replaced by `docs-mcp` |

AgentRank (March 2026) scores Tavily marginally above Exa on capability; the free-tier gap decided it.

## Where it lives
| Path | Purpose |
|---|---|
| `~/.claude/plugins/installed_plugins.json` | records `exa@claude-plugins-official` (user scope) |
| plugin's `.claude-plugin/plugin.json` | declares the hosted MCP server `https://mcp.exa.ai/mcp` |
| Exa account | holds the OAuth grant / API key and the usage counter |

Nothing to store in this repo — the plugin is fetched from the official marketplace, so the setup is
the install command plus the authentication step.

## Install
```bash
# the official marketplace is normally already registered
claude plugin marketplace add anthropics/claude-plugins-official
claude plugin install exa@claude-plugins-official
```
Then **restart Claude Code** (plugins and MCP servers load at session start) and authenticate:
`/mcp` → select `exa` → follow the browser OAuth flow.

## Verify
```bash
claude plugin list | grep exa                       # expect: exa … (user)
```
```
/mcp                                                # expect: exa … connected
```
An unauthenticated server answers `401 {"error":{"message":"Authentication required. Use OAuth or
provide an API key."}}` — that is the expected state before the OAuth step, not a broken install.

## Fix
| Symptom | Cause | Fix |
|---|---|---|
| `exa` tools missing in session | plugins load at session start | restart Claude Code |
| Every call fails with 401 | OAuth grant missing or expired | `/mcp` → `exa` → re-authenticate |
| Searches suddenly fail late in a month | monthly quota exhausted | check usage at <https://dashboard.exa.ai>; the built-in `WebSearch` still works as a fallback |

## Notes
- The plugin ships **no API key** — it points at Exa's hosted MCP and authenticates interactively.
  That means a headless/cron session cannot use it unless a key is configured explicitly; scheduled
  jobs should fall back to the built-in `WebSearch`.
- `WebSearch`/`WebFetch` stay available and cost nothing extra; Exa is the upgrade for research
  breadth, not a replacement for a one-URL fetch.
- **Deliberately not installed:** the community `deep-research` plugin. Its pipeline concept is sound
  (Haiku scouts → Sonnet verifiers → Opus synthesizer) but the code is third-party, unproven
  (0 stars, last push May 2026), and it builds on the built-in `WebSearch`, inheriting the US-only
  limitation. The `Workflow` tool already provides deterministic multi-agent fan-out.
