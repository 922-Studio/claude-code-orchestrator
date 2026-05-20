# Project: Studio (922-Studio Landing Page)

## Overview
- **Type**: app (website)
- **Path**: /Users/gregor/dev/922/Studio
- **Status**: active
- **Description**: The public landing page for 922-Studio at studio.922-studio.com. Showcases the studio's identity, projects, and capabilities. Built with Next.js 16 and React 19, supporting internationalization via next-intl and rich content via MDX. Fully public, no authentication required.

## Tech Stack
- **Language(s)**: TypeScript 5+, React 19.2.3
- **Framework(s)**: Next.js 16.1.6, next-intl 4.8.3 (i18n), Tailwind CSS 4.2.1, next-mdx-remote 5.0.0, gray-matter 4.0.3
- **Content**: reading-time 1.5.0, lucide-react 0.575.0
- **Testing**: Vitest 2.1.9, Playwright 1.58.2
- **Infrastructure**: Docker, Traefik (proxy network), Cloudflare Tunnel
- **CI/CD**: GitHub Actions (922-Studio/workflows), self-hosted runner → deploy.sh

## Key Files to Read

| File | Purpose | When to read |
|------|---------|--------------|
| `CLAUDE.md` | Commit conventions and project instructions | Always |
| `package.json` | Dependencies and scripts | When planning changes |
| `next.config.ts` | Next.js config (standalone output, next-intl plugin, MDX) | When touching build |
| `src/app/[locale]/layout.tsx` | Locale-aware layout with metadata and fonts | When touching layout |
| `src/app/[locale]/page.tsx` | Home page | When touching content |
| `src/i18n/routing.ts` | Locales config | When touching i18n |
| `messages/en.json` | English translations | When touching copy |
| `messages/de.json` | German translations | When touching copy |
| `Dockerfile` | Multi-stage build | When touching deployment |
| `docker-compose.yaml` | Container config with Traefik labels | When touching deployment |
| `deploy.sh` | Zero-downtime deployment script | When touching deployment |
| `.github/workflows/deploy.yml` | CI/CD pipeline | When pushing changes |

## Best Practices
- Locale-first routing with `[locale]` segments via next-intl
- Strict TypeScript, `@/*` path aliases
- Tailwind CSS 4 utility classes — no custom CSS unless necessary
- MDX for content-heavy pages
- SSR/SSG mix: generateStaticParams for locale routes
- No `Co-Authored-By` trailers in commits

## Testing Strategy
- **Unit tests**: Vitest — `npm run test:unit`
- **E2E tests**: Playwright — `npm run test:e2e`
- **Allure projects**: `studio-unit` (unit), `studio-e2e` (E2E)
- **CI**: Allure reporting, retries enabled

## Documentation
- **Where**: `README.md`, translation files in `messages/`
- **Update rule**: Keep translations in sync when changing copy; update README for structural changes

## Pipeline & Deployment
- **CI trigger**: Push to main + manual dispatch
- **Pipeline**: cancel-previous → version → tests → deploy → notify (Discord)
- **Deploy**: GitHub Actions → self-hosted runner → `./deploy.sh` (zero-downtime, build-first)
- **Container**: `studio` on the `proxy` network, port 3000 (internal, Traefik-mapped)
- **Monitor after push**: Discord notification, check https://studio.922-studio.com

## Dependencies on Other Projects
- **HomeStructure**: Traefik proxy network, Cloudflare Tunnel routing
- **Workflows**: Uses reusable CI/CD workflows (922-Studio/workflows)

## Notes
- Live domain: studio.922-studio.com
- Port 3000 is internal only — Traefik handles external routing, no auth middleware
- Public site: no forward-auth, accessible without login
