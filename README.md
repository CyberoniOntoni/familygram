# FamilyGram

**FamilyGram** is a self-hosted, private messaging platform for families, teams, and small communities. It gives you a Telegram-like experience — chats, groups, media, voice/video calls, and a modern web app — on **your own server**, without depending on Telegram’s cloud.

This repository is the **unified deployment package**: it wires together the backend ([Testgram](https://github.com/CyberoniOntoni/testgram), a [MyTelegram](https://github.com/loyldg/mytelegram) fork) and the web client ([FamilyGram Web](web/), a [telegram-tt](https://github.com/Ajaxy/telegram-tt) fork) into one Docker Compose stack with an interactive installer.

## What this project is

FamilyGram is **not** a hosted service and **not** a connection to telegram.org. You run the full stack yourself (typically on a VPS, Proxmox VM, or home lab). Clients talk to **your** public IP or domain; messages, files, and account data stay on **your** infrastructure.

| Layer | What it does |
|-------|----------------|
| **Testgram server** | MTProto gateway, authentication, messaging, file storage (MinIO), voice/video (Coturn/TURN), optional verification bot |
| **FamilyGram Web** | Browser UI that connects to your server over WebSocket MTProto (`/apiws`) |
| **Docker Compose** | MongoDB, Redis, RabbitMQ, and all services orchestrated as one stack |
| **Installer** | Guided setup: IPs, branding, login mode, firewall, `.env`, and first start |

Native clients ([FamilyGram Desktop](https://github.com/CyberoniOntoni/familygram-desktop)) can also point at your server IP (work in progress); the web client is included here so users can sign in from any browser.

## What it is for

Typical use cases:

- **Private family or friend group** — a closed chat environment you control, with a familiar Telegram-style UI
- **Small team or community** — white-label branding (`App__Brand`), your hostname, your rules
- **Self-hosting / homelab** — learn and operate a full messaging backend without SaaS lock-in
- **Air-gapped or fixed-code login** — use a preset login code instead of @BotFather when you do not want a Telegram bot in the loop

**Good fit:** you are comfortable with Linux, Docker, router port forwards, and a reverse proxy for HTTPS.

**Not a fit:** you want official Telegram accounts, Telegram Cloud sync, or a zero-ops managed product — use [telegram.org](https://telegram.org) instead.

## Components in this repo

| Component | Path | Description |
|-----------|------|-------------|
| Server | GHCR `cyberoniontoni/testgram` images | MTProto gateway, auth, messaging, calls (Coturn) |
| Web | [`web/`](web/) | [telegram-tt](https://github.com/Ajaxy/telegram-tt) fork, built into `familygram-web` container |
| Compose | [`docker/compose/`](docker/compose/) | Full stack including nginx web front-end |
| Installer | [`deploy/install.sh`](deploy/install.sh) | Interactive setup wizard (v4.2.x) |

## Quick install

```bash
curl -fsSL https://raw.githubusercontent.com/CyberoniOntoni/familygram/main/deploy/install.sh -o install.sh
sudo bash install.sh
```

The wizard collects:

- Public WAN IP and LAN IP (port forwards)
- Brand name (default **FamilyGram**)
- Web hostname (e.g. `web.example.com`) and API credentials from [my.telegram.org](https://my.telegram.org)
- Login verification: **@BotFather bot** (unique codes per user) **or fixed login code** (same code for everyone — no bot)
- Optional passkey domain and RTMP ports

Then it installs prerequisites (apt packages, Docker, Node.js 24 via nvm when the web client is enabled), clones this repo to `/opt/familygram`, writes `docker/compose/.env`, and starts the stack.

### Non-interactive

```bash
# With @BotFather bot (verification codes via Telegram):
PUBLIC_IP=1.2.3.4 LAN_IP=192.168.1.10 \
WEB_DOMAIN=web.example.com \
TELEGRAM_API_ID=12345678 TELEGRAM_API_HASH=your_api_hash \
BOT_TOKEN='123456789:AAH...' \
sudo bash install.sh --non-interactive --start

# With a fixed login code (no @BotFather):
PUBLIC_IP=1.2.3.4 LAN_IP=192.168.1.10 \
WEB_DOMAIN=web.example.com \
TELEGRAM_API_ID=12345678 TELEGRAM_API_HASH=your_api_hash \
FIXED_VERIFY_CODE=12345 \
sudo bash install.sh --non-interactive --start
```

## Networking and ports

FamilyGram uses your **public WAN IP** in client configs (`App__DcOptions__*__IpAddress`). Never put a LAN address there — remote phones and desktops cannot reach `192.168.x.x`.

MTProto and WebRTC must hit your server **directly**. Do not proxy them through Cloudflare orange-cloud or similar CDNs. The web UI is the only service that should go through an HTTPS reverse proxy.

### Router port forwards (WAN → FamilyGram host LAN IP)

Forward these from the internet to the machine running Docker Compose (defaults shown; the installer can customize MTProto/STUN ports).

| WAN port | Protocol | Service | Required |
|----------|----------|---------|----------|
| `20443` | TCP | MTProto DC1 — main entry for native clients | **Yes** |
| `20543` | TCP | MTProto DC2 | **Yes** |
| `20643` | TCP | MTProto DC3 | **Yes** |
| `20644` | TCP | MTProto DC4 (media) | **Yes** |
| `5348` | TCP + UDP | STUN/TURN (voice/video calls) | **Yes** |
| `49152–49172` | UDP | TURN relay media | **Yes** |
| `443` | TCP | Public HTTPS (Nginx Proxy Manager, Caddy, etc.) | **Yes** for web UI |
| `8082` | TCP | `familygram-web` directly (skip if using NPM on same host) | See web section |
| `30443` | TCP | Passkey HTTPS gateway (WebAuthn) — **only if passkey enabled** | Passkey only |
| `1935` | TCP | RTMP live streaming | Optional |
| `8888` | TCP | RTMP HLS playback | Optional |

**Do not forward** `30444`. It is the gateway HTTP/WebSocket transport on the **Docker network only** (`gateway-server:30444`). The `familygram-web` container proxies `/apiws` to it; browsers never connect to `:30444` on the host.

**Do not forward** `30443` unless you enabled passkey (WebAuthn) in the installer. The default stack keeps both `30443` and `30444` off the host; the installer writes `docker-compose.override.yml` to publish `30443` only when passkey is on.

### Host firewall (UFW)

If you use the installer with UFW enabled, it opens:

| Port | Protocol | Purpose |
|------|----------|---------|
| `22` | TCP | SSH |
| `20443–20644` | TCP | MTProto (four DC ports) |
| `30443` | TCP | Passkey HTTPS gateway (only if passkey enabled at install) |
| `5348` | TCP + UDP | STUN/TURN |
| `49152–49172` | UDP | TURN relay |
| `8082` | TCP | FamilyGram Web (`WEB_HOST_PORT`) |
| `1935`, `8888` | TCP | RTMP (only if enabled in wizard) |

Manual check:

```bash
ss -lntp | grep -E '20443|20543|20643|20644|5348|8082'
# 30443 appears only when passkey is enabled:
ss -lntp | grep 30443
ss -lunp  | grep -E '5348|49152'
```

### Web domain and `familygram-web` ports

The web client runs in the **`familygram-web`** container (nginx + built SPA). Configure these in `docker/compose/.env`:

| Variable | Default | Meaning |
|----------|---------|---------|
| `WEB_DOMAIN` | — | Public hostname users open in the browser |
| `WEB_BASE_URL` | `https://WEB_DOMAIN/` | Baked into the build; must match the public URL |
| `WEB_HOST_PORT` | `8082` | Port published on the **host** (`host:8082` → container) |
| `WEB_CONTAINER_PORT` | `8082` | Port nginx listens on **inside** the container |

**Inside Docker (no public forward needed):**

| Port | Listener | Notes |
|------|----------|-------|
| `8082` | `familygram-web` nginx | Serves static files, SPA routing |
| `30444` | `gateway-server` | WebSocket MTProto at `/apiws` — proxied by nginx to `gateway-server:30444` |

**Example — subdomain on a reverse proxy (recommended)**

```
DNS:   web.example.com  →  A  →  203.0.113.50  (your public WAN IP)
NPM:   web.example.com:443  →  proxy  →  192.168.1.10:8082
       (enable WebSockets / upgrade headers)
User:  https://web.example.com/
```

`.env` fragment:

```env
WEB_DOMAIN=web.example.com
WEB_BASE_URL=https://web.example.com/
WEB_HOST_PORT=8082
TELEGRAM_API_ID=12345678
TELEGRAM_API_HASH=your_api_hash
```

**Example — same host as NPM**

```
WAN :443  →  192.168.1.11:443   (Nginx Proxy Manager)
NPM       →  192.168.1.10:8082  (familygram-web on FamilyGram host)
```

**Example — direct exposure (lab / no reverse proxy)**

```
WAN :8082  →  192.168.1.10:8082
User:       http://203.0.113.50:8082/
```

Use HTTPS in production; set `WEB_DOMAIN` to the hostname clients actually use.

**Example — passkey (WebAuthn) on a separate subdomain**

Enable passkey in the installer (or copy `docker-compose.passkey.example.yml` → `docker-compose.override.yml`). That is the **only** reason to expose `30443` on the host.

```
DNS:   tg.example.com  →  A  →  203.0.113.50
NPM:   tg.example.com:443  →  192.168.1.10:30443
.env:  App__PasskeyRpId=tg.example.com
```

After changing `WEB_DOMAIN`, API credentials, or `WEB_BASE_URL`, rebuild the web image:

```bash
cd /opt/familygram/docker/compose
docker compose build familygram-web --no-cache
docker compose up -d familygram-web
```

### Architecture

```
Browser https://web.example.com/
  → reverse proxy :443 (SSL, WebSockets ON)
  → familygram-web :8082 (static SPA + /apiws proxy)
  → gateway-server :30444 (Docker internal, not public)
  → auth / session / messenger / …

Native clients → PUBLIC_IP:20443–20644 (MTProto TCP, direct)
Voice/video    → PUBLIC_IP:5348 (TCP+UDP) + 49152–49172/udp (TURN relay)
```

On first `docker compose up`, `familygram-web` runs `npm install` and a production build inside the image. Later starts reuse the cached image until you change `WEB_DOMAIN`, API credentials, or `WEB_BASE_URL` (rebuild commands above).

## Manual operation

```bash
cd /opt/familygram/docker/compose
cp .env.example .env   # edit secrets, IPs, WEB_DOMAIN, TELEGRAM_API_*
# Passkey only: cp docker-compose.passkey.example.yml docker-compose.override.yml
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
