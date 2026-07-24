# FamilyGram Web

Self-hosted [telegram-tt](https://github.com/Ajaxy/telegram-tt) web client for [FamilyGram Server](https://github.com/CyberoniOntoni/FamilyGram-Server).

Part of the unified [FamilyGram](https://github.com/CyberoniOntoni/familygram) monorepo (`main` branch) — use `deploy/install.sh` or `docker compose` from the repo root for the recommended setup.

Verified with FamilyGram-Server wire layer **228** (open session-server): login, chats, messaging, media, and calls.

## Requirements

- Node.js ^22.6 or ^24 (installer installs v24 via nvm when the host has v20 or older; Docker build uses Node 24 inside the image)
- A running FamilyGram stack ([install guide](https://github.com/CyberoniOntoni/familygram))
- Or Docker Compose from this monorepo (includes nginx + gateway proxy)

## Quick start

```bash
cp .env.production.example .env.production
# Fill TELEGRAM_API_ID / TELEGRAM_API_HASH from my.telegram.org (same as FamilyGram compose .env)
# Set BASE_URL and PRODUCTION_HOSTNAME to your public web URL

npm ci
npm run build:production
```

### Docker (recommended — unified stack)

From the monorepo compose directory:

```bash
cd ../docker/compose
docker compose build familygram-web
docker compose up -d familygram-web
```

The container serves static files and proxies `/apiws` to `gateway-server:30444` on the internal Docker network.

### Manual nginx deploy

Deploy the `dist/` folder to your web host. Example nginx locations:

- `/` → static files from `dist/`
- `/apiws`, `/apiw1` → gateway on Docker network (unified stack: use `familygram-web`; legacy host nginx needs `127.0.0.1:30444` bound locally only)

## Development

```bash
cp .env.example .env
# Add API credentials and FAMILYGRAM_SELF_HOSTED=1

FAMILYGRAM_SELF_HOSTED=1 FAMILYGRAM_GATEWAY_URL=http://YOUR_SERVER_IP:30444 npm run dev
```

## Deploy to server

Build locally, then upload with the helper script:

```bash
npm run build:production
cd dist && tar -czf ../familygram-web-dist.tar.gz .
```

```powershell
$env:FAMILYGRAM_SSH_HOST = 'your.server.example'
$env:FAMILYGRAM_SSH_PASSWORD = 'your-ssh-password'
python deploy/deploy-now.py
```

Environment variables for `deploy-now.py`:

| Variable | Default | Purpose |
|----------|---------|---------|
| `FAMILYGRAM_SSH_HOST` | — (required) | Web/nginx host |
| `FAMILYGRAM_SSH_USER` | `root` | SSH user |
| `FAMILYGRAM_SSH_PASSWORD` | — | Password auth |
| `FAMILYGRAM_DIST_TAR` | `familygram-web-dist.tar.gz` | Built tarball path |

After each deploy, users should **clear site data** for the web URL so the new JS bundle loads.

## FamilyGram TL / layer

Wire layer is **228** (`TG_GRAMJS_LAYER=228`, `invokeWithLayer` 228). Requires FamilyGram-Server open session-server and messenger images from **`main`** (`Layers.LayerLatest = 228`).

`src/util/familygramTlCompat.ts` keeps selected **224 constructor IDs as read aliases** so mixed traffic during client migration still deserializes.

| Issue | Fix |
|-------|-----|
| Layer negotiation | `AllTLObjects.LAYER` / vite `TG_GRAMJS_LAYER` → **228** for self-hosted |
| send/edit/saveDraft | Layer **228** constructors |
| user / message / channel | Layer **228** primary; 224 IDs aliased for read |
| `getDhConfig` with `randomLength: 0` → `RANDOM_LENGTH_INVALID` | Uses `randomLength: 256` for calls |
| Official Telegram RSA keys | FamilyGram production key fingerprint in `RSA.ts` |
| `aicompose.getTones` unsupported | Skipped on FamilyGram |
| Service worker caching stale bundles | Disabled for FamilyGram |

Other FamilyGram changes: same-origin WebSocket transport (`familygramServer.ts`), auth UX (preset verify code via server config), connection probe, chat loading hardening, call library versions `['4.0.0', '4.0.1', '2.7.7']`.

## Operations scripts

| Script | Purpose |
|--------|---------|
| `deploy/deploy-now.py` | Upload dist tarball and reload nginx |
| `deploy/reset-testgram-db.py` | Wipe FamilyGram data (destructive) |
| `deploy/fix-telegram-service-user.py` | Ensure user `777000` exists for chat list |
| `deploy/check-messaging-calls.py` | Tail server logs for send/call errors |
| `deploy/check-chats-deep.py` | Diagnose chat loading issues |

## Architecture (example deployment)

```
Browser → reverse proxy (443) → familygram-web :8082 → gateway :30444 (/apiws)
                                      ↓
                                 dist/ static
```

Public URL example: `https://web.example.com`

## Related projects

| Client | Repository |
|--------|------------|
| Unified stack | [CyberoniOntoni/familygram](https://github.com/CyberoniOntoni/familygram) (`main`) |
| Server | [CyberoniOntoni/FamilyGram-Server](https://github.com/CyberoniOntoni/FamilyGram-Server) (`main`) |
| Desktop | [CyberoniOntoni/familygram-desktop](https://github.com/CyberoniOntoni/familygram-desktop) |
