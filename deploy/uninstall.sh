#!/usr/bin/env bash
# FamilyGram — remove the Docker Compose stack installed by deploy/install.sh
#
# Usage:
#   sudo bash deploy/uninstall.sh
#   sudo bash deploy/uninstall.sh --yes
#   sudo bash deploy/uninstall.sh --keep-data
#   sudo bash deploy/uninstall.sh --install-dir /opt/familygram --remove-images
#
# Options:
#   --install-dir PATH   default /opt/familygram
#   --yes, -y            skip confirmation prompt
#   --keep-data          keep docker/compose/data and .env
#   --keep-repo          keep the git clone; only stop containers and remove data
#   --remove-images      docker image prune for familygram/familygram-web:local
#   --help               show help
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/opt/familygram}"
COMPOSE_DIR="${INSTALL_DIR}/docker/compose"
COMPOSE_FILE="${COMPOSE_DIR}/docker-compose.yml"
ASSUME_YES=false
KEEP_DATA=false
KEEP_REPO=false
REMOVE_IMAGES=false

usage() {
  sed -n '2,16p' "$0"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-dir) INSTALL_DIR="${2:-}"; COMPOSE_DIR="${INSTALL_DIR}/docker/compose"; COMPOSE_FILE="${COMPOSE_DIR}/docker-compose.yml"; shift 2 ;;
    --yes|-y) ASSUME_YES=true; shift ;;
    --keep-data) KEEP_DATA=true; shift ;;
    --keep-repo) KEEP_REPO=true; shift ;;
    --remove-images) REMOVE_IMAGES=true; shift ;;
    --help|-h) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root (sudo)." >&2
  exit 1
fi

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  echo "No FamilyGram install found at ${INSTALL_DIR} (missing ${COMPOSE_FILE})." >&2
  exit 1
fi

load_install_config() {
  local summary="${INSTALL_DIR}/deploy/last-install-config.txt"
  if [[ -f "${summary}" ]]; then
    # shellcheck disable=SC1090
    source "${summary}"
  fi
  ENABLE_WEB="${ENABLE_WEB:-yes}"
  ENABLE_BOT="${ENABLE_BOT:-yes}"
}

compose_profiles() {
  local profiles=()
  [[ "${ENABLE_BOT}" == "yes" ]] && profiles+=(bot)
  [[ "${ENABLE_WEB}" == "yes" ]] && profiles+=(web)
  if ((${#profiles[@]} > 0)); then
    local IFS=,
    printf '%s' "${profiles[*]}"
  fi
}

compose_down() {
  local profiles
  profiles="$(compose_profiles)"
  cd "${COMPOSE_DIR}"
  if [[ -n "${profiles}" ]]; then
    COMPOSE_PROFILES="${profiles}" docker compose down --remove-orphans "$@"
  else
    docker compose down --remove-orphans "$@"
  fi
}

load_install_config

echo "FamilyGram uninstall"
echo "  Install dir: ${INSTALL_DIR}"
echo "  Compose:     ${COMPOSE_DIR}"
echo "  Profiles:    $(compose_profiles || echo default)"
echo "  Keep data:   ${KEEP_DATA}"
echo "  Keep repo:   ${KEEP_REPO}"
echo "  Remove imgs: ${REMOVE_IMAGES}"
echo ""

if [[ "${ASSUME_YES}" != "true" ]]; then
  read -r -p "This stops all FamilyGram containers and removes stack data. Continue? [y/N] " reply
  [[ "${reply}" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
fi

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  echo "==> Stopping containers..."
  compose_down
else
  echo "==> Docker not available — skipping compose down"
fi

if [[ "${KEEP_DATA}" != "true" ]]; then
  echo "==> Removing stack data..."
  rm -rf "${COMPOSE_DIR}/data"
  rm -f "${COMPOSE_DIR}/docker-compose.override.yml"
  if [[ -f "${COMPOSE_DIR}/.env" ]]; then
    rm -f "${COMPOSE_DIR}/.env"
  fi
fi

if [[ "${REMOVE_IMAGES}" == "true" ]] && command -v docker >/dev/null 2>&1; then
  echo "==> Removing local FamilyGram Web image (if present)..."
  docker image rm -f familygram/familygram-web:local 2>/dev/null || true
fi

if [[ "${KEEP_REPO}" != "true" ]]; then
  echo "==> Removing install directory ${INSTALL_DIR}..."
  rm -rf "${INSTALL_DIR}"
else
  echo "==> Kept ${INSTALL_DIR} (git clone and deploy scripts remain)."
fi

echo ""
echo "Done. FamilyGram stack removed."
echo "Manual cleanup (if used):"
echo "  • Nginx Proxy Manager proxy host for your web domain"
echo "  • UFW rules for MTProto / TURN / web ports opened by the installer"
echo "  • DNS records and router port forwards"