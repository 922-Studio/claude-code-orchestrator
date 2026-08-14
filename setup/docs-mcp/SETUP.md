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
| `setup/docs-mcp/libraries.tsv` | **The source of truth** for which docs are indexed, with per-library scrape budget + exclusions |
| `setup/docs-mcp/index-libraries.sh` | Enqueue scrape jobs from `libraries.tsv`, wait for the queue, report failures |
| `setup/docs-mcp/mcpcall.sh` | Call any tool on the server from the shell (`search_docs`, `list_jobs`, …) |
| container `docs-mcp` | The server; data in the `docs-mcp-data` / `docs-mcp-config` Docker volumes |
| `~/.claude.json` | Holds the `docs` MCP server registration (user scope) |

## Install
```bash
bash setup/docs-mcp/install.sh --index     # container + MCP registration + full index
bash setup/docs-mcp/install.sh             # container + registration only
```
Indexing the full `libraries.tsv` takes roughly 15–30 minutes and is network-bound. Restart Claude
Code afterwards — MCP servers are only picked up at session start.

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

## Fix
| Symptom | Cause | Fix |
|---|---|---|
| Container restart-loops, exit code 0 | `--protocol auto` picks stdio without a TTY, hits EOF, exits | Must run with `server --protocol http --host 0.0.0.0`; `install.sh` does this |
| `mcpcall.sh: sh[@]: unbound variable` | bash 3.2 (macOS) treats an empty array as unbound under `set -u` | Already guarded with `${sh[@]+"${sh[@]}"}`; don't remove it |
| Tools missing in session | MCP servers load at session start only | Restart Claude Code |
| `list_libraries` shows a library but search finds nothing | rows appear when a job **starts**, not when it finishes | Check `mcpcall.sh list_jobs '{}'` — wait for `completed`, don't trust the library list |
| Search returns changelog/release-notes pages | scrape budget eaten by low-value pages | Add exclusions + raise `maxPages` in `libraries.tsv`, re-run `index-libraries.sh <lib>` |
| Docs gone stale after a dependency bump | index is a snapshot | `mcpcall.sh refresh_version '{"library":"<lib>"}'` or re-run `index-libraries.sh <lib>` |

## Scrape budget — the thing that decides quality
`maxPages` is a hard cap and the crawler spends it in link order, so **big low-value trees starve the
pages you want**. Two offenders, both hit on the first attempt here:

- **Changelogs / release-notes.** FastAPI's `/release-notes/` is one enormous page that mentions
  every feature once; it out-competed `advanced/testing-dependencies/` for the query
  *"override dependency in tests"* until it was excluded.
- **Translated doc trees.** FastAPI publishes ~20 languages under `/es/`, `/zh/`, `/pt/` … all inside
  the default `subpages` scope, quietly eating most of the budget.

Both are excluded per-library in `libraries.tsv`. Apply the same when adding a library, and always
finish by running a real query against it rather than trusting that the job said `completed`.

## Notes
- **Embeddings.** The image ships a local ONNX embedding model, so semantic search works with no key
  and no external calls. Setting `OPENAI_API_KEY` (or an Ollama/Gemini/Azure provider) would swap in
  a stronger model — deliberately not done here, since limit-free and local is the whole point.
- **Adding a library:** append a row to `libraries.tsv`, then `./index-libraries.sh <name>`. Keep the
  file as the source of truth — don't scrape ad-hoc, or the next machine gets a different index.
- **Companion setup:** the `exa` plugin covers open-web research (20 000 requests/month free) where
  this covers pinned library docs. Exa's hosted MCP needs an OAuth login on first use.
- Upstream: <https://github.com/arabold/docs-mcp-server> (MIT).
