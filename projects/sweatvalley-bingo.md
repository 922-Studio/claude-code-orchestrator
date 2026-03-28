# Project: Sweatvalley Bingo

## Overview
- **Type**: app
- **Path**: /Users/gregor/dev/922/sweatvalley_bingo
- **Status**: active
- **Description**: Real-time multiplayer bingo game for classroom observation. Players join via game code, get randomized 3x3 or 4x4 grids with teacher behavior items, and mark squares in real-time with synchronized scoring. German language word set with difficulty classification.

## Tech Stack
- **Language(s)**: JavaScript (Node.js)
- **Framework(s)**: Express 4.18.2 (server), React 18.2.0 (client, CRA via react-scripts 5.0.1), Socket.io 4.5.4 (WebSocket)
- **Data**: csv-parse 5.4.1
- **Database**: None (in-memory game state)
- **Infrastructure**: Docker (Node Alpine), Cloudflare Tunnel
- **CI/CD**: GitHub Actions (922-Studio/workflows), Vitest 4.0.18 (server, 70%), Jest (client, 30%)

## Key Files to Read

| File | Purpose | When to read |
|------|---------|--------------|
| `CLAUDE.md` | Architecture, testing strategy, Socket.io setup, conventions | Always |
| `README.md` | German language setup and usage guide | First time |
| `server/server.js` | Express/Socket.io server, game state, event handlers | When touching backend |
| `server/gameLogic.js` | Pure game logic (grid generation, line checking) | When touching game rules |
| `client/src/App.js` | Single-component React app (all game states) | When touching frontend |
| `client/src/index.css` | All styling (responsive, dark mode) | When touching design |
| `data/words.csv` | German bingo words with difficulty (leicht/mittel/schwer) | When touching word list |
| `docker-compose.yml` | Service definition, Traefik labels, health check | When touching deployment |
| `.github/workflows/deploy.yml` | CI/CD pipeline | When pushing changes |
| `.planning/PROJECT.md` | Project goals and requirements | For context |

## Best Practices
- Server: CommonJS (`require`/`module.exports`), Client: ES modules
- Pure game logic separated in `gameLogic.js` for testability
- Socket.io: WebSocket-only (no polling) for Cloudflare Tunnel compatibility
- Difficulty distribution per grid: proportional (hard + medium + easy)
- Test listeners set up BEFORE socket emit to avoid race conditions

## Testing Strategy
- **Server unit tests**: `server/gameLogic.test.js` — Vitest
- **Server integration**: `server/integration.test.js` — full Socket.io round-trip
- **Server socket**: `server/socket.test.js` — event handler validation
- **Client tests**: `client/src/App.test.js` — Jest + React Testing Library
- **How to run**: `cd server && npm test` / `cd client && CI=true npm test -- --watchAll=false`
- **Reporting**: Allure in CI

## Documentation
- **Where**: `README.md` (German), `CLAUDE.md`, `.planning/`
- **Update rule**: Update README when features change

## Pipeline & Deployment
- **CI trigger**: Push to main + manual
- **Pipeline**: cancel-previous → version → server tests → client tests → smoke test → deploy → notify
- **Deploy**: Docker Compose via `deploy.sh`
- **Monitor after push**: Discord notification, check https://sweatvalley-bingo.922-studio.com

## Dependencies on Other Projects
- **HomeStructure**: Traefik proxy network, Cloudflare Tunnel
- **workflows**: Uses reusable CI/CD workflows

## Notes
- Public URL: https://sweatvalley-bingo.922-studio.com
- Internal port 3001, host port 3923
- Version: 0.7.4
- Dark mode toggle with localStorage persistence
