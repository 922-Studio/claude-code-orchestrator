# Project: Discord Bot (EggVault)

## Overview
- **Type**: app
- **Path**: /Users/gregor/dev/922/discord
- **Status**: active
- **Description**: Discord bot combining utility integrations with an idle game (EggVault). Players collect eggs by chatting, earn energy, progress through encounters, manage inventory, unlock areas, and complete milestones. Also provides debt tracking (NL parsing), ideas tracking (AI-refined), and wellbeing logging. Stateless for business logic — delegates data operations to HomeAPI via HTTP.

## Tech Stack
- **Language(s)**: Python 3.13
- **Framework(s)**: discord.py 2.4.0, SQLAlchemy 2.0.39 (async), httpx 0.28.1, asyncpg 0.30.0, Alembic 1.14.1
- **Image processing**: Pillow 11.1.0
- **Database**: PostgreSQL 16 (production), SQLite in-memory (tests)
- **Infrastructure**: Docker (infra network only, no exposed ports), Alembic
- **CI/CD**: GitHub Actions (922-Studio/workflows), pytest, ruff + mypy

## Key Files to Read

| File | Purpose | When to read |
|------|---------|--------------|
| `CLAUDE.md` | Architecture rules, naming, patterns, testing strategy | Always |
| `docs/AI_CONTEXT.md` | AI-optimized quick reference | Always |
| `README.md` | Features, commands, stack summary | First time |
| `bot.py` | Main entry point (HomeBot class, cog auto-discovery, encounters) | When touching bot core |
| `config.py` | Environment variable loading | When touching config |
| `database.py` | SQLAlchemy async engine setup | When touching DB |
| `game/engine.py` | EncounterEngine (pure logic, no Discord imports) | When touching game |
| `game/drop_logic.py` | Rarity rolls, golden/shiny mechanics | When touching drops |
| `game/egg_data.py` | Egg loader and lookup helpers | When touching eggs |
| `services/homeapi.py` | Async HomeAPI client (debts, ideas, wellbeing, prompts) | When touching integrations |
| `cogs/debt.py` | Debt tracking with confirmation views | When touching debt feature |
| `.github/workflows/deploy.yml` | CI/CD pipeline | When pushing changes |

## Best Practices
- **Never import Discord types into game logic** — `game/` modules have zero discord.py imports
- Game logic is pure, fully testable in isolation
- Cog auto-discovery: all `.py` in `cogs/` loaded automatically
- Session per request via `self.bot.db()` context manager
- CRUD: static `@staticmethod async def` methods, take `session: AsyncSession` first
- Commands use `;` prefix (e.g., `;stats`, `;vault`, `;slot`)
- No `Co-Authored-By` trailers in commits

## Testing Strategy
- **Unit tests**: `tests/unit/test_*.py` — `pytest tests/unit/`
- **Framework**: pytest + pytest-asyncio (asyncio_mode=auto)
- **DB mocking**: In-memory SQLite via aiosqlite
- **Reporting**: Allure at `http://home-lab:5050` (project: discord-bot)
- **Coverage**: >=70% enforced on `game` package in CI

## Documentation
- **Where**: `docs/` (MkDocs at http://home-lab:8005)
- **Key sections**: game-design/, services/, ops/
- **Update rule**: Update AI_CONTEXT.md when structure, commands, or tech stack changes

## Pipeline & Deployment
- **CI trigger**: Push to main
- **Pipeline**: cancel-previous → version → tests (>=70% on game package) → deploy → notify
- **Additional workflows**: deploy-docs.yml
- **Deploy**: Docker Compose via `deploy.sh` on self-hosted runner
- **Monitor after push**: Discord notification, check bot online status

## Dependencies on Other Projects
- **HomeAPI**: All business data (debts, ideas, wellbeing, prompts) via HTTP
- **HomeStructure**: Shared PostgreSQL (external infra network)
- **workflows**: Uses reusable CI/CD workflows

## Notes
- Game data in `data/eggs.json`, `data/eggs_golden_reach.json`, `data/buildings.json`
- 3 Alembic migrations (initial, eggvault phase 1, phase 2 golden reach)
- Connects to shared_postgres:5432 via external infra network
- HomeAPI base URL: `http://home_api_api:8080/api` (production), `http://localhost:8080/api` (dev)
