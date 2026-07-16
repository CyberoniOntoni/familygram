#!/usr/bin/env bash
# Static checks and a local dry-run of .env / compose generation (no docker pull).
# Run from repo root on Linux:  sudo bash deploy/verify-installer.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_SH="${ROOT}/deploy/install.sh"
INSTALLER_LIB="${ROOT}/deploy/lib/installer-lib.sh"
COMPOSE_DIR="${ROOT}/docker/compose"

echo "==> bash -n install.sh"
bash -n "${INSTALL_SH}"

echo "==> bash -n installer-lib.sh"
bash -n "${INSTALLER_LIB}"

echo "==> dry-run: write .env + compose override (fixed-code path)"
export NON_INTERACTIVE=true
export INSTALLER_VERSION="verify"
export PUBLIC_IP="203.0.113.50"
export LAN_IP="192.168.1.10"
export BRAND="FamilyGram"
export FIXED_VERIFY_CODE="12345"
export ENABLE_BOT="no"
export BOT_TOKEN=""
export ENABLE_PASSKEY="no"
export ENABLE_RTMP="no"
export ENABLE_WEB="yes"
export WEB_DOMAIN="web.example.com"
export TELEGRAM_API_ID="12345678"
export TELEGRAM_API_HASH="abcdef0123456789abcdef0123456789"
export TURN_PASS="test-turn-secret"
export INSTALL_DIR="${ROOT}"
export COMPOSE_DIR="${COMPOSE_DIR}"
export COMPOSE_FILE="${COMPOSE_DIR}/docker-compose.yml"
export PORT_MT1=20443 PORT_MT2=20543 PORT_MT3=20643 PORT_MT4=20644
export PORT_HTTPS=30443 PORT_HTTPS_ALT=30444 PORT_STUN=5348
export PORT_RELAY_MIN=49152 PORT_RELAY_MAX=49172
export WEB_HOST_PORT=8082 WEB_CONTAINER_PORT=8082
export PASSKEY_DOMAIN="localhost"
export DO_FIREWALL=false

# shellcheck source=lib/installer-lib.sh
source "${INSTALLER_LIB}"
installer_lib_init

TMP_ENV="${COMPOSE_DIR}/.env.verify.bak"
COMPOSE_YML="${COMPOSE_DIR}/docker-compose.yml"
[[ -f "${COMPOSE_DIR}/.env" ]] && cp "${COMPOSE_DIR}/.env" "${TMP_ENV}" || true
[[ -f "${COMPOSE_YML}" ]] && cp "${COMPOSE_YML}" "${COMPOSE_YML}.verify.bak" || true
OVERRIDE="${COMPOSE_DIR}/docker-compose.override.yml"
[[ -f "${OVERRIDE}" ]] && cp "${OVERRIDE}" "${OVERRIDE}.verify.bak" || true

cleanup() {
  if [[ -f "${TMP_ENV}" ]]; then
    mv -f "${TMP_ENV}" "${COMPOSE_DIR}/.env"
  elif [[ -f "${COMPOSE_DIR}/.env" ]]; then
    rm -f "${COMPOSE_DIR}/.env"
  fi
  if [[ -f "${COMPOSE_YML}.verify.bak" ]]; then
    mv -f "${COMPOSE_YML}.verify.bak" "${COMPOSE_YML}"
  fi
  if [[ -f "${OVERRIDE}.verify.bak" ]]; then
    mv -f "${OVERRIDE}.verify.bak" "${OVERRIDE}"
  elif [[ -f "${OVERRIDE}" ]]; then
    rm -f "${OVERRIDE}"
  fi
}
trap cleanup EXIT

cd "${COMPOSE_DIR}"
write_env_file
patch_compose "${COMPOSE_FILE}"
write_compose_override

grep -q '^App__FixedVerifyCode=12345$' .env || { echo "FAIL: App__FixedVerifyCode missing"; exit 1; }
grep -q '^TelegramBotSms__Enabled=false$' .env || { echo "FAIL: TelegramBotSms__Enabled"; exit 1; }
grep -q '^App__DcOptions__0__IpAddress=203.0.113.50$' .env || { echo "FAIL: PUBLIC_IP in .env"; exit 1; }
grep -q '^WEB_DOMAIN=web.example.com$' .env || { echo "FAIL: WEB_DOMAIN"; exit 1; }
[[ ! -f "${OVERRIDE}" ]] || { echo "FAIL: override should not exist without passkey"; exit 1; }

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  echo "==> docker compose config -q"
  compose_with_profiles config -q >/dev/null
else
  echo "==> skip docker compose config (docker not available)"
fi

echo "OK — installer scripts and dry-run passed"