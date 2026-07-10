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
| `30443` | TCP | Gateway HTTPS / passkey (WebAuthn) | Optional |
| `1935` | TCP | RTMP live streaming | Optional |
| `8888` | TCP | RTMP HLS playback | Optional |

**Do not forward** `30444` to the internet. That port is the gateway HTTP/WebSocket transport used **inside** Docker and by `familygram-web` on the Docker network (`gateway-server:30444`). Browsers reach it via same-origin `/apiws` on your web domain, not via a public `:30444` forward.

### Host firewall (UFW)

If you use the installer with UFW enabled, it opens:

| Port | Protocol | Purpose |
|------|----------|---------|
| `22` | TCP | SSH |
| `20443–20644` | TCP | MTProto (four DC ports) |
| `30443` | TCP | HTTPS gateway (passkey) |
| `5348` | TCP + UDP | STUN/TURN |
| `49152–49172` | UDP | TURN relay |
| `8082` | TCP | FamilyGram Web (`WEB_HOST_PORT`) |
| `1935`, `8888` | TCP | RTMP (only if enabled in wizard) |

Manual check:

```bash
ss -lntp | grep -E '20443|20543|20643|20644|30443|5348|8082'
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