#!/usr/bin/env bash
# Gate di verifica del re-skin 2014.
#
# Uso:
#   tools/verify.sh            # gate fast: checker, server test, test Godot headless
#   tools/verify.sh --full     # gate full: server temporaneo, network/publish/studio, export Web
#   tools/verify.sh --visual   # stampa la procedura per le contact sheet (richiede display)
#
# Il server del gate full usa una data dir temporanea e porte 9080/9081, che
# devono essere libere. Il trap ferma il server e cancella la data dir anche in
# caso di errore.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT/Godot/robloxwebengine"
GODOT=(flatpak run org.godotengine.Godot --headless --path "$PROJECT")
HTTP_PORT=9080
WS_PORT=9081
FULL=0
VISUAL=0

for arg in "$@"; do
  case "$arg" in
    --full) FULL=1 ;;
    --visual) VISUAL=1 ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *)
      echo "Argomento sconosciuto: $arg" >&2
      exit 2
      ;;
  esac
done

cd "$ROOT"
SERVER_PID=""
DATA_DIR=""
SERVER_LOG=""

cleanup() {
  if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  if [[ -n "$DATA_DIR" ]]; then
    rm -rf "$DATA_DIR"
  fi
  if [[ -n "$SERVER_LOG" ]]; then
    rm -f "$SERVER_LOG"
  fi
}
trap cleanup EXIT

step() {
  printf '\n==> %s\n' "$*"
}

run_godot_test() {
  local script="$1"
  step "Godot $script"
  "${GODOT[@]}" --script "res://tools/$script"
}

port_free() {
  python3 - "$1" <<'PY'
import socket
import sys
port = int(sys.argv[1])
with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        sock.bind(("127.0.0.1", port))
    except OSError:
        sys.exit(1)
PY
}

wait_for_server() {
  python3 - "$HTTP_PORT" <<'PY'
import sys
import time
import urllib.request
url = f"http://127.0.0.1:{int(sys.argv[1])}/api/health"
deadline = time.time() + 20
while time.time() < deadline:
    try:
        with urllib.request.urlopen(url, timeout=1) as response:
            if response.status == 200:
                sys.exit(0)
    except Exception:
        time.sleep(0.2)
sys.exit(1)
PY
}

if [[ "$VISUAL" == "1" ]]; then
  cat <<'EOF'
Procedura visuale (richiede display e browser):
  1. tools/verify.sh --full
  2. python3 server/run.py  (server di sviluppo)
  3. aprire http://127.0.0.1:9080/ e acquisire le superfici della matrice
     in docs/roblox-2014/implementation-plan.md §8.2–8.3.
  4. salvare il set completo in .scratch/roblox-2014-aesthetic/evidence/ e le
     contact sheet ottimizzate in docs/roblox-2014/evidence/.
EOF
fi

step "Checker del sito e dei token"
python3 tools/check_design_tokens.py
python3 tools/check_site_content.py --strict-confirm

step "Test server (stdlib)"
python3 -m unittest discover -s server/tests -v

step "Import Godot"
"${GODOT[@]}" --import

run_godot_test test_theme.gd
run_godot_test test_hud.gd
run_godot_test test_gameplay.gd
run_godot_test test_level_io.gd
run_godot_test test_editor.gd
run_godot_test test_lua.gd

if [[ "$FULL" == "1" ]]; then
  step "Porte $HTTP_PORT/$WS_PORT"
  if ! port_free "$HTTP_PORT" || ! port_free "$WS_PORT"; then
    echo "Le porte $HTTP_PORT/$WS_PORT sono occupate: fermare il server di sviluppo." >&2
    exit 1
  fi

  DATA_DIR="$(mktemp -d "${TMPDIR:-/tmp}/robloxweb-verify.XXXXXX")"
  SERVER_LOG="$(mktemp "${TMPDIR:-/tmp}/robloxweb-verify-log.XXXXXX")"
  step "Server temporaneo in $DATA_DIR"
  ROBLOXWEB_DATA_DIR="$DATA_DIR" \
    ROBLOXWEB_HTTP_PORT="$HTTP_PORT" \
    ROBLOXWEB_WS_PORT="$WS_PORT" \
    python3 server/run.py >"$SERVER_LOG" 2>&1 &
  SERVER_PID=$!
  if ! wait_for_server; then
    echo "Il server non ha risposto su /api/health." >&2
    tail -40 "$SERVER_LOG" >&2 || true
    exit 1
  fi

  run_godot_test test_network.gd
  run_godot_test test_publish.gd
  run_godot_test test_studio.gd

  step "Export Web"
  ./tools/export_web.sh

  step "Smoke HTTP di play.html"
  python3 - "$HTTP_PORT" <<'PY'
import sys
import urllib.request
url = f"http://127.0.0.1:{int(sys.argv[1])}/play.html?id=1"
with urllib.request.urlopen(url, timeout=5) as response:
    body = response.read().decode("utf-8")
    assert response.status == 200
    assert "play-bar" in body and "rw-ready" in body
print("play.html: 200 e handshake presente")
PY
fi

if [[ "$FULL" == "1" ]]; then
  step "Gate full verde"
else
  step "Gate fast verde"
fi
