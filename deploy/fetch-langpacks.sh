#!/usr/bin/env bash
# Download and convert official Telegram language packs for FamilyGram Server.
#
# FamilyGram Web uses LANG_PACK=weba. Android-only packs only cover ~30% of WebA
# keys, so we merge:
#   1) android (broad catalog)
#   2) weba   (web UI keys — wins on conflicts)
#
# Run from repo root: bash deploy/fetch-langpacks.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${ROOT}/deploy/scripts/convert-langpack-export.mjs"
OUT_ROOT="${ROOT}/docker/compose/langpacks"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

fetch_export() {
  local code="$1"
  local pack="$2" # android | weba | webk | ...
  local out="${TMP_DIR}/${code}-${pack}.export"
  local url="https://translations.telegram.org/${code}/${pack}/export?format=json"
  echo "==> Fetching ${code}/${pack} from ${url}"
  curl -fsSL --retry 3 --retry-delay 2 "${url}" -o "${out}"
  # Telegram may return empty/HTML on rate limit
  if [[ ! -s "${out}" ]]; then
    echo "ERROR: empty download for ${code}/${pack}" >&2
    return 1
  fi
  printf '%s\n' "${out}"
}

fetch_lang() {
  local code="$1"
  local json="${OUT_ROOT}/${code}/android.json"
  mkdir -p "${OUT_ROOT}/${code}"

  local android_file weba_file
  android_file="$(fetch_export "${code}" android)"
  weba_file="$(fetch_export "${code}" weba)"

  # Merge: android base + weba overlay (weba wins). Output still named android.json
  # for data-seeder path compatibility; content is multi-platform.
  node "${SCRIPT}" \
    --lang "${code}" \
    --pack weba \
    --out "${json}" \
    "${android_file}" \
    "${weba_file}"
}

command -v node >/dev/null 2>&1 || { echo "Node.js required"; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "curl required"; exit 1; }

fetch_lang en
fetch_lang ru

echo ""
echo "Language packs written under ${OUT_ROOT} (en + ru, android∪weba)"
echo "On a running stack, re-seed (version changes force re-import):"
echo "  cp -a docker/compose/langpacks/. docker/compose/data/mytelegram/data-seeder/downloads/langpacks/"
echo "  # clear seeder import marker so new version is applied:"
echo "  # (optional) delete ImportedLanguagePackVersions keys in data seeder config"
echo "  cd docker/compose && docker compose restart data-seeder messenger-query-server"
