#!/usr/bin/env bash
# Switch an existing FamilyGram install to the bleeding-edge layer228 stack.
# Updates git checkout + .env server image tag, rebuilds web, pulls server images.
#
# Usage (on the install host):
#   sudo bash /opt/familygram/deploy/switch-to-layer228.sh
#   sudo bash /opt/familygram/deploy/switch-to-layer228.sh --no-start
set -euo pipefail

DO_START=true
INSTALL_DIR="${INSTALL_DIR:-/opt/familygram}"
for arg in "$@"; do
  case "${arg}" in
    --no-start) DO_START=false ;;
    --install-dir=*) INSTALL_DIR="${arg#*=}" ;;
    --help|-h)
      sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
  esac
done

[[ "$(id -u)" -eq 0 ]] || { echo "Run as root"; exit 1; }
[[ -d "${INSTALL_DIR}/.git" ]] || { echo "Not a git install: ${INSTALL_DIR}"; exit 1; }
[[ -f "${INSTALL_DIR}/docker/compose/docker-compose.yml" ]] || { echo "Missing compose file"; exit 1; }

export REPO_BRANCH=layer228
export FamilyGramServerVersion=layer228

echo "==> Checkout familygram layer228 in ${INSTALL_DIR}"
git -C "${INSTALL_DIR}" fetch origin layer228
git -C "${INSTALL_DIR}" checkout -B layer228 origin/layer228

COMPOSE_DIR="${INSTALL_DIR}/docker/compose"
cd "${COMPOSE_DIR}"

if [[ ! -f .env ]]; then
  echo "ERROR: ${COMPOSE_DIR}/.env missing — run deploy/install.sh first"
  exit 1
fi

echo "==> Point .env at GHCR :layer228 server images"
if grep -q '^FamilyGramServerVersion=' .env; then
  sed -i 's|^FamilyGramServerVersion=.*|FamilyGramServerVersion=layer228|' .env
else
  echo 'FamilyGramServerVersion=layer228' >> .env
fi
if grep -q '^FamilyGramServerRegistry=' .env; then
  sed -i 's|^FamilyGramServerRegistry=.*|FamilyGramServerRegistry=ghcr.io/cyberoniontoni/familygram-server|' .env
else
  echo 'FamilyGramServerRegistry=ghcr.io/cyberoniontoni/familygram-server' >> .env
fi
if grep -q '^TestgramVersion=' .env; then
  sed -i 's|^TestgramVersion=.*|TestgramVersion=layer228|' .env
fi
if grep -q '^TestgramRegistry=' .env; then
  sed -i 's|^TestgramRegistry=.*|TestgramRegistry=ghcr.io/cyberoniontoni/familygram-server|' .env
fi

PROFILES=()
grep -qE '^ENABLE_WEB=|^WEB_DOMAIN=.' .env 2>/dev/null && PROFILES+=(web)
# bot profile when BOT_TOKEN set
if grep -qE '^BOT_TOKEN=.+' .env && ! grep -qE '^BOT_TOKEN=\s*$' .env; then
  PROFILES+=(bot)
fi
# Prefer compose profiles from running containers / common default
export COMPOSE_PROFILES="${COMPOSE_PROFILES:-web,bot}"

echo "==> Pull server images (tag layer228)"
docker compose pull --ignore-buildable

echo "==> Rebuild familygram-web from layer228 sources"
docker compose build familygram-web

if [[ "${DO_START}" == true ]]; then
  echo "==> Restart stack"
  docker compose up -d
  docker compose ps
  echo ""
  echo "Done. Verify API layer in gateway/messenger logs (expect layer 228)."
  echo "  cd ${COMPOSE_DIR} && docker compose logs --tail=50 gateway-server messenger-query-server"
else
  echo "Images updated. Start with: cd ${COMPOSE_DIR} && docker compose up -d"
fi
