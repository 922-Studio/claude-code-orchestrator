# Project: Portfolio

## Overview
- **Type**: app (website)
- **Path**: /Users/gregor/dev/922/portfolio
- **Status**: active
- **Description**: Gregor Krykon's personal portfolio website. Showcases Automation Engineer and Full-Stack Developer profile with projects, tech stack, testimonials, CV downloads. Multi-language (EN/DE), responsive, dark/light theme. Live at https://gregor.922-studio.com.

## Tech Stack
- **Language(s)**: TypeScript 5+, React 19.2.3
- **Framework(s)**: Next.js 16.1.6, next-intl 4.8.3 (i18n), Tailwind CSS 4.2.1
- **Testing**: Vitest 2.1.9, Playwright 1.58.2
- **Infrastructure**: Docker (private registry), Traefik, Google Analytics 4
- **CI/CD**: GitHub Actions (922-Studio/workflows), ESLint 9

## Key Files to Read

| File | Purpose | When to read |
|------|---------|--------------|
| `CLAUDE.md` | Commit conventions | Always |
| `package.json` | Dependencies and scripts | When planning changes |
| `next.config.ts` | Next.js config (standalone output, next-intl plugin) | When touching build |
| `src/app/[locale]/layout.tsx` | Locale-aware layout with metadata, fonts, theme | When touching layout |
| `src/app/[locale]/page.tsx` | Home page (orchestrates all sections) | When touching content |
| `src/i18n/routing.ts` | Locales config (en, de) | When touching i18n |
| `messages/en.json` | English translations | When touching copy |
| `messages/de.json` | German translations | When touching copy |
| `src/app/globals.css` | Theme CSS variables, animations | When touching design |
| `Dockerfile` | Multi-stage build | When touching deployment |
| `.github/workflows/deploy.yml` | CI/CD pipeline | When pushing changes |

## Best Practices
- Locale-first routing with `[locale]` segments
- Strict TypeScript, `@/*` path aliases
- Sections in `src/components/sections/`
- CSS custom variables for dark/light theme with class-based switching
- SSR/SSG mix: generateStaticParams for locale routes
- No `Co-Authored-By` trailers in commits

## Testing Strategy
- **E2E tests**: `e2e/*.spec.ts` with Playwright (Chrome)
- **How to run**: `npm run test`
- **Fixtures**: buttons, carousel, theme-toggle, impressum
- **CI**: 2 retries, Allure + HTML reporting

## Documentation
- **Where**: `README.md`, translation files in `messages/`
- **Update rule**: Keep translations in sync when changing copy

## Pipeline & Deployment
- **CI trigger**: Push to main + manual
- **Pipeline**: cancel-previous → version → build → push → kick-off-e2e → notify (Discord)
- **Deploy**: Docker build with GA_MEASUREMENT_ID, docker compose up
- **Monitor after push**: Discord notification, check https://gregor.922-studio.com

## Dependencies on Other Projects
- **HomeStructure**: Traefik proxy network
- **workflows**: Uses reusable CI/CD workflows

## Notes
- Live domain: portfolio.922-studio.com
- Single-page with sections: Hero, About, Stack, Projects (carousel), Testimonials, Contact
- Font: next/font optimized loading
