#!/bin/bash
# Deploy FamilyGram Web (telegram-tt) on the FamilyGram host (legacy manual nginx path).
# Run as root on the server after syncing source to /opt/familygram-web-src

set -euo pipefail

SRC_DIR="${SRC_DIR:-/opt/familygram-web-src}"
DIST_DIR="${DIST_DIR:-/opt/familygram-web/dist}"

cd "$SRC_DIR"

if [[ ! -f .env ]]; then
  cp .env.production .env
fi

unset NODE_OPTIONS
npm ci
npm run build:production

mkdir -p "$DIST_DIR"
rm -rf "${DIST_DIR:?}/"*
cp -a dist/. "$DIST_DIR/"

echo "Deployed $(cat public/version.txt 2>/dev/null || echo unknown) to $DIST_DIR"
echo "Hard-refresh browsers (Ctrl+Shift+R) after deploy."