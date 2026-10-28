"""Configurazione del server RobloxWeb (un solo processo Python, sola stdlib).

Tutti i valori possono essere sovrascritti con variabili d'ambiente:
  ROBLOXWEB_HOST, ROBLOXWEB_HTTP_PORT, ROBLOXWEB_WS_PORT,
  ROBLOXWEB_DATA_DIR, ROBLOXWEB_WS_URL
I test usano `configure(...)` per puntare a una data dir/porta temporanea.
"""
from __future__ import annotations

import os
import secrets
from pathlib import Path

SERVER_DIR = Path(__file__).resolve().parent
ROOT_DIR = SERVER_DIR.parent

HOST = os.environ.get("ROBLOXWEB_HOST", "127.0.0.1")
HTTP_PORT = int(os.environ.get("ROBLOXWEB_HTTP_PORT", "9080"))
WS_PORT = int(os.environ.get("ROBLOXWEB_WS_PORT", "9081"))
DATA_DIR = Path(os.environ.get("ROBLOXWEB_DATA_DIR", str(SERVER_DIR / "data")))
WEB_ROOT = ROOT_DIR / "WEBhtml"
DEFAULT_LEVEL_PATH = ROOT_DIR / "Godot" / "robloxwebengine" / "levels" / "default.rwl.json"

# Override esplicito per il deploy (es. wss://dominio/ws). Vuoto = derivato dalla richiesta.
WS_PUBLIC_URL = os.environ.get("ROBLOXWEB_WS_URL", "")

SESSION_DAYS = 30
TICKET_SECONDS = 600
GUEST_CLEANUP_DAYS = 7

MAX_JSON_BODY = 64 * 1024
MAX_LEVEL_BYTES = 2 * 1024 * 1024
MAX_PUBLISH_BODY = MAX_LEVEL_BYTES + MAX_JSON_BODY
MAX_THUMBNAIL_BYTES = 1024 * 1024
MAX_THUMBNAIL_WIDTH = 1920
MAX_THUMBNAIL_HEIGHT = 1080
MAX_PLAYERS_PER_ROOM = 16
MAX_WS_CLIENTS = 64

RATE_LIMIT_WINDOW = 60.0
RATE_LIMIT_MAX = 20

DEMO_USERNAME = "demo"
DEMO_PASSWORD = "demo1234"
AUTHOR_USERNAME = "RobloxWeb"

_SEED_PLACE_TITLE = "Welcome Obby"

_secret_cache: bytes | None = None


def configure(
    *,
    host: str | None = None,
    http_port: int | None = None,
    ws_port: int | None = None,
    data_dir: str | Path | None = None,
    web_root: str | Path | None = None,
    default_level_path: str | Path | None = None,
    ws_public_url: str | None = None,
) -> None:
    """Riconfigura il modulo (usato dai test e da run.py)."""
    global HOST, HTTP_PORT, WS_PORT, DATA_DIR, WEB_ROOT, DEFAULT_LEVEL_PATH
    global WS_PUBLIC_URL, _secret_cache
    if host is not None:
        HOST = host
    if http_port is not None:
        HTTP_PORT = http_port
    if ws_port is not None:
        WS_PORT = ws_port
    if data_dir is not None:
        DATA_DIR = Path(data_dir)
    if web_root is not None:
        WEB_ROOT = Path(web_root)
    if default_level_path is not None:
        DEFAULT_LEVEL_PATH = Path(default_level_path)
    if ws_public_url is not None:
        WS_PUBLIC_URL = ws_public_url
    _secret_cache = None


def db_path() -> Path:
    return DATA_DIR / "app.db"


def thumbs_dir() -> Path:
    return DATA_DIR / "thumbs"


def ensure_data_dir() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    thumbs_dir().mkdir(parents=True, exist_ok=True)


def secret_key() -> bytes:
    """Chiave HMAC persistente in data/secret.key (generata al primo uso)."""
    global _secret_cache
    if _secret_cache is not None:
        return _secret_cache
    ensure_data_dir()
    path = DATA_DIR / "secret.key"
    try:
        value = path.read_bytes().strip()
    except FileNotFoundError:
        value = secrets.token_urlsafe(48).encode("ascii")
        path.write_bytes(value)
        try:
            path.chmod(0o600)
        except OSError:
            pass
    if not value:
        value = secrets.token_urlsafe(48).encode("ascii")
        path.write_bytes(value)
    _secret_cache = value
    return value


def seed_place_title() -> str:
    return _SEED_PLACE_TITLE
