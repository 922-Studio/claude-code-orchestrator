# SETUP — Local docs MCP server (Grounded Docs)

**id:** `docs-mcp` · **type:** Docker container + Claude Code MCP server · **platform:** any (needs `docker`, `curl`, `python3`)

## What it does
Gives Claude **version-pinned documentation retrieval** for the DocBits stack from a fully local
index — the job Context7 does, without the metering. Docs are scraped once into a local SQLite +
vector index; `search_docs` then answers library questions from the real docs instead of from model
memory, which is what stops invented API signatures.

Runs in **Unified Mode**: one container serves the MCP endpoint, the scrape worker, and a web
dashboard on the same port.

**Why self-hosted instead of Context7:** Context7's free tier is 1 000 API calls/month plus a
~60/hour rate limit (cut from ~6 000/month in January 2026); Pro is $10/seat/month for 5 000. Doc
lookups happen constantly while coding, and the hourly cap is the one that actually bites mid-session.
This has no limits, no key, and no queries leaving the machine. The trade-off is real: you index the
libraries yourself, and the server only knows what you gave it.

## Where it lives
| Path | Purpose |
|---|---|
| `setup/docs-mcp/install.sh` | Idempotent install/reconcile: pull image, run container, register MCP server |
| `setup/docs-mcp/libraries.tsv` | **The source of truth** for which docs are indexed — URL plus the `scrape` CLI flags (budget, depth, exclusions) passed verbatim |
| `setup/docs-mcp/index-libraries.sh` | (Re)build the index via the CLI: stop server → scrape each library → restart server (restarts even on failure) |
| `setup/docs-mcp/mcpcall.sh` | Call any tool on the server from the shell (`search_docs`, `list_jobs`, …) |
| container `docs-mcp` | The server; data in the `docs-mcp-data` / `docs-mcp-config` Docker volumes |
| `~/.claude.json` | Holds the `docs` MCP server registration (user scope) |

## Install
```bash
bash setup/docs-mcp/install.sh --index     # container + MCP registration + full index
bash setup/docs-mcp/install.sh             # container + registration only
```
Indexing the full `libraries.tsv` takes roughly 15–30 minutes and is network-bound, and the server is
down while it runs (the crawler needs exclusive access to the store; the script restarts it either
way). Restart Claude Code afterwards — MCP servers are only picked up at session start.

Index a single library after editing its row:
```bash
bash setup/docs-mcp/index-libraries.sh helm
```

## Verify
```bash
docker ps --filter name=docs-mcp --format '{{.Status}}'        # expect: Up …
curl -s -o /dev/null -w '%{http_code}\n' localhost:6280        # expect: 200
setup/docs-mcp/mcpcall.sh list_libraries '{}'                  # expect: the libraries.tsv list
setup/docs-mcp/mcpcall.sh search_docs '{"library":"fastapi","query":"dependency overrides in tests","limit":2}'
```
In a Claude Code session the tools appear as `mcp__docs__search_docs`, `mcp__docs__list_libraries`, etc.

The last check is the one that matters: **a hit list is not a correct hit list.** If results come
back from a changelog or release-notes page instead of the topic page, the index is bad — see
*Scrape budget* below.

Also check the **page counts** `index-libraries.sh` prints. A large doc site that yields single
digits scraped "successfully" but indexed nothing usable; the script flags anything under
`MIN_PAGES` (default 5) and exits non-zero, because a bare exit code here means nothing.

## Fix
| Symptom | Cause | Fix |
|---|---|---|
| Container restart-loops, exit code 0 | `--protocol auto` picks stdio without a TTY, hits EOF, exits | Must run with `server --protocol http --host 0.0.0.0`; `install.sh` does this |
| `mcpcall.sh: sh[@]: unbound variable` | bash 3.2 (macOS) treats an empty array as unbound under `set -u` | Already guarded with `${sh[@]+"${sh[@]}"}`; don't remove it |
| Tools missing in session | MCP servers load at session start only | Restart Claude Code |
| `list_libraries` shows a library but search finds nothing | rows appear when a job **starts**, not when it finishes | Check `mcpcall.sh list_jobs '{}'` — wait for `completed`, don't trust the library list |
| `list_jobs` returns nothing at all | the server prunes finished jobs, so the list is transient | Not an error — verify with `list_libraries` + a real search instead |
| Search returns changelog/release-notes pages | scrape budget eaten by low-value pages | Add exclusions + raise `--max-pages` in `libraries.tsv`, re-run `index-libraries.sh <lib>` |
| Exclusions in `libraries.tsv` appear to have no effect | you indexed through the MCP `scrape_docs` tool, which accepts only url/library/version/maxPages/maxDepth/scope/followRedirects/preserveHashes and **silently drops** exclude/include patterns | Index only via `index-libraries.sh` (CLI path). Never call `scrape_docs` by hand for a library that needs exclusions |
| Every search result appears twice | a mirrored version tree (`/v3/`, `/latest/`, `/stable/`) got indexed alongside the canonical one | Exclude the mirror, re-index that library |
| A library indexes "successfully" with 1–2 pages | **cross-host redirect** — the `subpages` boundary is computed from the URL you supplied, so after a redirect to another host nothing is in scope (`docs.pydantic.dev/latest/` → `pydantic.dev/docs/validation/…`) | Point at the redirect target and add `--scope hostname --include-pattern '**/<section>/**'` |
| Same symptom, but the URL doesn't redirect | **client-rendered site** — in the default `fetch` mode the crawler finds no links in the HTML at all (playwright.dev) | Add `--scrape-mode playwright` |
| Docs gone stale after a dependency bump | index is a snapshot | `mcpcall.sh refresh_version '{"library":"<lib>"}'` or re-run `index-libraries.sh <lib>` |

## Scrape budget — the thing that decides quality
`maxPages` is a hard cap and the crawler spends it in link order, so **big low-value trees starve the
pages you want**. Three offenders, all three hit while setting this up:

- **Changelogs / release-notes.** FastAPI's `/release-notes/` is one enormous page that mentions
  every feature once; it out-competed `advanced/testing-dependencies/` for the query
  *"override dependency in tests"* until it was excluded.
- **Translated doc trees.** FastAPI publishes ~20 languages under `/es/`, `/zh/`, `/pt/` … all inside
  the default `subpages` scope, quietly eating most of the budget.
- **Mirrored version trees.** `helm.sh/docs/` and `helm.sh/docs/v3/` serve identical content, so half
  the budget bought nothing *and* every search returned each page twice, crowding out distinct hits.
  Check for a `/vN/` (or `/latest/`, `/stable/`) mirror before indexing.

All three are excluded per-library in `libraries.tsv`. Apply the same when adding a library, and
always finish by running a real query against it rather than trusting that the job said `completed`.
Duplicate URLs in a result list are the tell-tale sign of a mirror you missed.

**Exclusions only work through the CLI.** The MCP `scrape_docs` tool has no exclude/include
parameter and drops unknown arguments without complaint, so an index built through it looks
successful while containing everything you meant to leave out. That is why `libraries.tsv` holds
literal CLI flags and `index-libraries.sh` shells out to `docs-mcp-server scrape` instead of calling
the tool. Raising `--max-pages` can mask the problem — it buries the noise under enough real pages to
make searches look fixed — which is exactly how this went unnoticed at first.

## Notes
- **Embeddings.** The image ships a local ONNX embedding model, so semantic search works with no key
  and no external calls. Setting `OPENAI_API_KEY` (or an Ollama/Gemini/Azure provider) would swap in
  a stronger model — deliberately not done here, since limit-free and local is the whole point.
- **Adding a library:** append a row to `libraries.tsv`, then `./index-libraries.sh <name>`. Keep the
  file as the source of truth — don't scrape ad-hoc, or the next machine gets a different index.
- **Companion setup:** the `exa` plugin covers open-web research (20 000 requests/month free) where
  this covers pinned library docs. Exa's hosted MCP needs an OAuth login on first use.
- Upstream: <https://github.com/arabold/docs-mcp-server> (MIT).
