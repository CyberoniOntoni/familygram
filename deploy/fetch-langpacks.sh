#!/usr/bin/env bash
# Download and convert official Telegram Android language packs for Testgram data-seeder.
# Run from repo root: bash deploy/fetch-langpacks.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${ROOT}/deploy/scripts/convert-android-langpack-export.mjs"
OUT_ROOT="${ROOT}/docker/compose/langpacks"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

fetch_lang() {
  local code="$1"
  local url="https://translations.telegram.org/${code}/android/export?format=json"
  local xml="${TMP_DIR}/${code}.xml"
  local json="${OUT_ROOT}/${code}/android.json"

  echo "==> Fetching ${code} from ${url}"
  mkdir -p "${OUT_ROOT}/${code}"
  curl -fsSL "${url}" -o "${xml}"
  node "${SCRIPT}" "${xml}" "${json}" "${code}"
}

command -v node >/dev/null 2>&1 || { echo "Node.js required"; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "curl required"; exit 1; }

fetch_lang en

if [[ "${FETCH_RU:-no}" == "yes" ]]; then
  fetch_lang ru
fi

echo ""
echo "Language packs written under ${OUT_ROOT}"
echo "On a running stack, copy into data-seeder downloads and restart:"
echo "  cp -a docker/compose/langpacks/. docker/compose/data/mytelegram/data-seeder/downloads/langpacks/"
echo "  cd docker/compose && docker compose restart data-seeder messenger-query-server"