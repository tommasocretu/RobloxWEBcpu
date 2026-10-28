#!/usr/bin/env bash
# Compila RobloxWeb Studio per Linux e Windows e prepara i download del sito.
# Uso (dalla root del repo): ./build_studio.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$ROOT/Godot/robloxwebengine"
LINUX_DIR="$ROOT/build/studio/linux"
WINDOWS_DIR="$ROOT/build/studio/windows"
DOWNLOADS="$ROOT/WEBhtml/downloads"
GODOT=(flatpak run org.godotengine.Godot --headless --path "$PROJECT")

if ! command -v flatpak >/dev/null 2>&1; then
  echo "Errore: flatpak non trovato (serve l'installazione Flatpak di Godot 4.7)." >&2
  exit 1
fi

mkdir -p "$LINUX_DIR" "$WINDOWS_DIR" "$DOWNLOADS"

echo "== Import delle risorse =="
"${GODOT[@]}" --import

echo "== Export Linux Studio =="
"${GODOT[@]}" --export-release "Linux Studio" "$LINUX_DIR/RobloxWebStudio.x86_64"
test -f "$LINUX_DIR/RobloxWebStudio.x86_64"

echo "== Export Windows Studio =="
"${GODOT[@]}" --export-release "Windows Studio" "$WINDOWS_DIR/RobloxWebStudio.exe"
test -f "$WINDOWS_DIR/RobloxWebStudio.exe"

echo "== Pacchetti per il download =="
rm -f "$LINUX_DIR/RobloxWebStudio-linux.zip" "$WINDOWS_DIR/RobloxWebStudio-windows.zip"
(cd "$LINUX_DIR" && zip -q -9 RobloxWebStudio-linux.zip RobloxWebStudio.x86_64)
(cd "$WINDOWS_DIR" && zip -q -9 RobloxWebStudio-windows.zip RobloxWebStudio.exe)
cp "$LINUX_DIR/RobloxWebStudio-linux.zip" "$DOWNLOADS/"
cp "$WINDOWS_DIR/RobloxWebStudio-windows.zip" "$DOWNLOADS/"

(cd "$ROOT" && sha256sum \
  build/studio/linux/RobloxWebStudio.x86_64 \
  build/studio/windows/RobloxWebStudio.exe \
  WEBhtml/downloads/RobloxWebStudio-linux.zip \
  WEBhtml/downloads/RobloxWebStudio-windows.zip \
  > build/studio/SHA256SUMS)

echo
echo "Pronti:"
echo "  $LINUX_DIR/RobloxWebStudio.x86_64"
echo "  $WINDOWS_DIR/RobloxWebStudio.exe"
echo "  $DOWNLOADS/RobloxWebStudio-linux.zip"
echo "  $DOWNLOADS/RobloxWebStudio-windows.zip"
echo
echo "Smoke test headless:"
echo "  $LINUX_DIR/RobloxWebStudio.x86_64 --headless --quit-after 3"
