# FamilyGram

Unified self-hosted Telegram-compatible stack: **Testgram server** + **FamilyGram Web** client in one Docker Compose package.

| Component | Path | Description |
|-----------|------|-------------|
| Server | GHCR `cyberoniontoni/testgram` images | MTProto gateway, auth, messaging, calls (Coturn) |
| Web | [`web/`](web/) | [telegram-tt](https://github.com/Ajaxy/telegram-tt) fork, built into `familygram-web` container |
| Compose | [`docker/compose/`](docker/compose/) | Full stack including nginx web front-end |
| Installer | [`deploy/install.sh`](deploy/install.sh) | Interactive setup wizard |

## Quick install

```bash
curl -fsSL https://raw.githubusercontent.com/CyberoniOntoni/familygram/main/deploy/install.sh -o install.sh
sudo bash install.sh
```

The wizard collects:

- Public WAN IP and LAN IP (port forwards)
- Brand name (default **FamilyGram**)
- Web hostname (e.g. `web.example.com`) and API credentials from [my.telegram.org](https://my.telegram.org)
- @BotFather bot token (login verification codes)
- Optional passkey domain and RTMP ports

Then it clones this repo to `/opt/familygram`, writes `docker/compose/.env`, and starts the stack.

### Non-interactive

```bash
PUBLIC_IP=1.2.3.4 LAN_IP=192.168.1.10 \
WEB_DOMAIN=web.example.com \
TELEGRAM_API_ID=12345678 TELEGRAM_API_HASH=your_api_hash \
BOT_TOKEN='123456789:AAH...' \
sudo bash install.sh --non-interactive --start
```

## Architecture

```
Browser https://web.example.com/
  → reverse proxy :443 (SSL, WebSockets ON)
  → familygram-web :8082 (static SPA + /apiws proxy)
  → gateway-server :30444 (Docker internal)
  → auth / session / messenger / …

Native clients → PUBLIC_IP:20443+ (MTProto, direct — not through CDN)
Voice/video    → PUBLIC_IP:5348 + TURN relay UDP range
```

The `familygram-web` container builds the web client on first `docker compose up` (npm install + production build). Subsequent starts use the cached image unless you change API credentials or hostname — then rebuild:

```bash
cd /opt/familygram/docker/compose
docker compose build familygram-web --no-cache
docker compose up -d familygram-web
```

## Manual operation

```bash
cd /opt/familygram/docker/compose
cp .env.example .env   # edit secrets, IPs, WEB_DOMAIN, TELEGRAM_API_*
docker compose pull --ignore-buildable
docker compose build familygram-web
docker compose up -d
docker compose ps
docker compose logs -f familygram-web
```

## Repository layout

```
familygram/
├── deploy/           # Interactive installer
├── docker/compose/   # docker-compose.yml, init scripts, .env templates
└── web/              # FamilyGram Web source + Dockerfile
```

Server binaries are pulled from [CyberoniOntoni/testgram](https://github.com/CyberoniOntoni/testgram) GHCR packages — this repo does not rebuild them.

## Related projects

| Platform | Repository |
|----------|------------|
| Server source | [CyberoniOntoni/testgram](https://github.com/CyberoniOntoni/testgram) |
| Web source (standalone) | [CyberoniOntoni/familygram-web](https://github.com/CyberoniOntoni/familygram-web) |
| Desktop | [CyberoniOntoni/familygram-desktop](https://github.com/CyberoniOntoni/familygram-desktop) |

## Web client details

See [`web/README-FAMILYGRAM.md`](web/README-FAMILYGRAM.md) for TL layer-224 compatibility patches, dev mode, and troubleshooting.