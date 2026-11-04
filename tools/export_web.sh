#!/usr/bin/env bash
# Esporta il client Web di RobloxWebEngine in WEBhtml/dev/index.html.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT/Godot/robloxwebengine"
OUTPUT="$ROOT/WEBhtml/dev/index.html"

mkdir -p "$(dirname "$OUTPUT")"

flatpak run org.godotengine.Godot --headless \
  --path "$PROJECT" \
  --export-release "Web" \
  "$OUTPUT"

echo "Export Web completato: $OUTPUT"
