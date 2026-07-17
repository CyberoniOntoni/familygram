#!/usr/bin/env bash
# Download and convert official Telegram language packs for FamilyGram Server.
#
# FamilyGram Web uses two localization systems:
#   1) New (useLang)     → lang_pack=weba keys (LastSeenHoursAgo, …)
#   2) Legacy (useOldLang) → merges android + ios + tdesktop + macos (incl. lng_* keys)
#
# We therefore merge: android, weba, webk, ios, macos, tdesktop (later packs win on conflict).
#
# Run from repo root: bash deploy/fetch-langpacks.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${ROOT}/deploy/scripts/convert-langpack-export.mjs"
OUT_ROOT="${ROOT}/docker/compose/langpacks"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

# Order matters: later sources override earlier for the same key.
PACK_SOURCES=(android weba webk ios macos tdesktop)

fetch_export() {
  local code="$1"
  local pack="$2"
  local out="${TMP_DIR}/${code}-${pack}.export"
  local url="https://translations.telegram.org/${code}/${pack}/export?format=json"
  echo "==> Fetching ${code}/${pack}"
  if ! curl -fsSL --retry 3 --retry-delay 2 --max-time 120 "${url}" -o "${out}"; then
    echo "WARN: failed to download ${code}/${pack} — skipping" >&2
    return 1
  fi
  if [[ ! -s "${out}" ]]; then
    echo "WARN: empty download for ${code}/${pack} — skipping" >&2
    return 1
  fi
  # Rate-limit / block pages sometimes return HTML
  if head -c 20 "${out}" | grep -qi '<html\|<!doctype'; then
    echo "WARN: non-export response for ${code}/${pack} — skipping" >&2
    return 1
  fi
  printf '%s\n' "${out}"
}

fetch_lang() {
  local code="$1"
  local json="${OUT_ROOT}/${code}/android.json"
  mkdir -p "${OUT_ROOT}/${code}"

  local files=()
  local pack f
  for pack in "${PACK_SOURCES[@]}"; do
    if f="$(fetch_export "${code}" "${pack}")"; then
      files+=("${f}")
    fi
  done

  if [[ ${#files[@]} -eq 0 ]]; then
    echo "ERROR: no packs downloaded for ${code}" >&2
    return 1
  fi

  node "${SCRIPT}" \
    --lang "${code}" \
    --pack weba \
    --out "${json}" \
    "${files[@]}"
}

command -v node >/dev/null 2>&1 || { echo "Node.js required"; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "curl required"; exit 1; }

fetch_lang en
fetch_lang ru

echo ""
echo "Language packs written under ${OUT_ROOT} (en + ru)"
echo "Merged sources: ${PACK_SOURCES[*]}"
echo "On a running stack:"
echo "  cp -a docker/compose/langpacks/. docker/compose/data/mytelegram/data-seeder/downloads/langpacks/"
echo "  # clear ImportedLanguagePackVersions for en/ru in dataseeder.json, then:"
echo "  cd docker/compose && docker compose restart data-seeder messenger-query-server"
