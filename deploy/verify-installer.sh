#!/usr/bin/env bash
# Static checks and dry-runs of .env generation for both login modes.
# Run on Linux:  sudo bash deploy/verify-installer.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_SH="${ROOT}/deploy/install.sh"
INSTALLER_LIB="${ROOT}/deploy/lib/installer-lib.sh"
COMPOSE_DIR="${ROOT}/docker/compose"

echo "==> bash -n install.sh"
bash -n "${INSTALL_SH}"

echo "==> bash -n installer-lib.sh"
bash -n "${INSTALLER_LIB}"

# shellcheck source=lib/installer-lib.sh
source "${INSTALLER_LIB}"
installer_lib_init

run_dry_run() {
  local label="$1"
  shift

  echo ""
  echo "==> dry-run: ${label}"

  export NON_INTERACTIVE=true
  export INSTALLER_VERSION="verify"
  export PUBLIC_IP="203.0.113.50"
  export LAN_IP="192.168.1.10"
  export BRAND="FamilyGram"
  export ENABLE_PASSKEY="no"
  export ENABLE_RTMP="no"
  export ENABLE_WEB="yes"
  export WEB_DOMAIN="web.example.com"
  export TELEGRAM_API_ID="12345678"
  export TELEGRAM_API_HASH="abcdef0123456789abcdef0123456789"
  export TURN_USER="testgram"
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

  # shellcheck disable=SC2034
  while [[ $# -gt 0 ]]; do
    export "$1"
    shift
  done

  local tmp_env="${COMPOSE_DIR}/.env.verify.bak"
  local compose_yml="${COMPOSE_DIR}/docker-compose.yml"
  local override="${COMPOSE_DIR}/docker-compose.override.yml"
  [[ -f "${COMPOSE_DIR}/.env" ]] && cp "${COMPOSE_DIR}/.env" "${tmp_env}" || true
  [[ -f "${compose_yml}" ]] && cp "${compose_yml}" "${compose_yml}.verify.bak" || true
  [[ -f "${override}" ]] && cp "${override}" "${override}.verify.bak" || true

  cleanup() {
    if [[ -f "${tmp_env}" ]]; then
      mv -f "${tmp_env}" "${COMPOSE_DIR}/.env"
    elif [[ -f "${COMPOSE_DIR}/.env" ]]; then
      rm -f "${COMPOSE_DIR}/.env"
    fi
    if [[ -f "${compose_yml}.verify.bak" ]]; then
      mv -f "${compose_yml}.verify.bak" "${compose_yml}"
    fi
    if [[ -f "${override}.verify.bak" ]]; then
      mv -f "${override}.verify.bak" "${override}"
    elif [[ -f "${override}" ]]; then
      rm -f "${override}"
    fi
  }
  trap cleanup RETURN

  cd "${COMPOSE_DIR}"
  write_env_file
  patch_compose "${COMPOSE_FILE}"
  write_compose_override
  validate_required_env

  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    compose_with_profiles config -q >/dev/null
    echo "    docker compose config OK (profiles: $(compose_profile_list || echo none))"
  else
    echo "    skip docker compose config (docker not available)"
  fi
}

run_dry_run "fixed login code (no bot)" \
  ENABLE_BOT=no BOT_TOKEN= FIXED_VERIFY_CODE=12345

run_dry_run "@BotFather bot" \
  ENABLE_BOT=yes BOT_TOKEN='123456789:AAHfake_token_for_test' FIXED_VERIFY_CODE=

run_dry_run "passkey + bot" \
  ENABLE_BOT=yes BOT_TOKEN='123456789:AAHfake_token_for_test' FIXED_VERIFY_CODE= \
  ENABLE_PASSKEY=yes PASSKEY_DOMAIN=tg.example.com

echo ""
echo "OK — installer fills required parameters for all login modes"