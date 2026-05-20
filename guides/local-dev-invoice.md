# Local Dev Setup — Finance Invoice Feature

Run HomeUI locally against the deployed `lab-api-dev.922-studio.com` instance. No local HomeAPI required.

## Prerequisites

- `lab-api-dev.922-studio.com` must be reachable. It is Cloudflare-fronted — no VPN needed.
- Your user account must exist on the dev instance. If you don't have a token yet, see [Token bootstrapping](#token-bootstrapping) below.

## Setup

```bash
cd /Users/gregor/dev/922/HomeUI
cp .env.example .env.local
# In .env.local, set:
#   VITE_API_BASE_URL=https://lab-api-dev.922-studio.com
npm install
npm run dev   # serves on http://localhost:8001
```

## CORS Note — TODO before local-dev works

`http://localhost:8001` is **not** currently in HomeAPI's CORS allow-list.

The default in `HomeAPI/config.py` is:

```
CORS_ORIGINS = https://lab.922-studio.com,http://localhost:5173,http://localhost:3000
```

Neither `HomeAPI/.env.dev` nor `HomeStructure/infra/.env.dev` override `CORS_ORIGINS`, so port 8001 requests will be blocked by the browser.

**Fix (server-side change, do not edit manually — commit and let CI deploy):**

Add `http://localhost:8001` to `CORS_ORIGINS` in the deployed dev env. The canonical place to do this is in the HomeStructure infra dev configuration. Check `HomeStructure/infra/.env.dev` — add or update the line:

```
CORS_ORIGINS=https://lab.922-studio.com,https://lab-api-dev.922-studio.com,http://localhost:5173,http://localhost:3000,http://localhost:8001
```

Commit the change to HomeStructure and push; CI will redeploy the dev stack.

Until this is done, `fetchInvoicePreview` and all other HomeAPI calls from `localhost:8001` will be rejected at the browser's CORS preflight stage.

## Token Bootstrapping

1. Open `http://localhost:8001/login` in your browser (once the dev server is running).
2. Log in with your 922-Studio account credentials — the same account you use on `lab-dev.922-studio.com`.
3. On successful login, the Axios interceptor in `HomeUI/src/lib/http.ts` stores the Bearer token in `localStorage` and attaches it to every subsequent request.

If you already have an active session on `lab-dev.922-studio.com`, you can copy the token from that tab's `localStorage` (`token` key) and set it manually in the `localhost:8001` tab's `localStorage` to skip re-authentication.

## Iterating on HomeAPI Invoice Changes

Push to the feature branch (`feat/finance-invoice-overhaul`) — CI auto-deploys to `lab-api-dev.922-studio.com` in approximately 3 minutes. Refresh HomeUI in the browser to pick up the new API version.

The dev database (`dev_postgres:5433`, database `dev_home_api`) is kept in sync with production via:

```
HomeStructure/infra/mirror-prod-to-dev.sh
```

Run the script from the server (`ssh lab`) before starting a dev session to ensure the Person and debt_transaction tables reflect current prod data.

## Quick Reference

| What | Value |
|------|-------|
| HomeUI dev URL | `http://localhost:8001` |
| API target | `https://lab-api-dev.922-studio.com` |
| Dev DB host | `dev_postgres:5433` |
| Dev DB name | `dev_home_api` |
| Mirror script | `HomeStructure/infra/mirror-prod-to-dev.sh` |
| CORS config (code) | `HomeAPI/config.py` — `CORS_ORIGINS` default |
| CORS config (server) | `HomeStructure/infra/.env.dev` — `CORS_ORIGINS` override |
