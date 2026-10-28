"""Configurazione del server RobloxWeb (un solo processo Python, sola stdlib).

Tutti i valori possono essere sovrascritti con variabili d'ambiente:
  ROBLOXWEB_HOST, ROBLOXWEB_HTTP_PORT, ROBLOXWEB_WS_PORT,
  ROBLOXWEB_DATA_DIR, ROBLOXWEB_WS_URL, ROBLOXWEB_SECRET,
  ROBLOXWEB_LOG_LEVEL, ROBLOXWEB_TRUST_PROXY, ROBLOXWEB_ADMIN_USERS,
  ROBLOXWEB_BACKUP_KEEP, ROBLOXWEB_MAINTENANCE_HOURS
I test usano `configure(...)` per puntare a una data dir/porta temporanea.
"""
from __future__ import annotations

import os
import secrets
from pathlib import Path

SERVER_DIR = Path(__file__).resolve().parent
ROOT_DIR = SERVER_DIR.parent

VERSION = "0.5.0"


def _env_int(name: str, default: int) -> int:
    try:
        return int(os.environ.get(name, str(default)))
    except (TypeError, ValueError):
        return default


def _env_bool(name: str, default: bool) -> bool:
    value = os.environ.get(name)
    if value is None:
        return default
    return value.strip().lower() in ("1", "true", "yes", "si", "sì", "on")


def _env_list(name: str) -> tuple[str, ...]:
    value = os.environ.get(name, "")
    return tuple(item.strip() for item in value.split(",") if item.strip())


HOST = os.environ.get("ROBLOXWEB_HOST", "127.0.0.1")
HTTP_PORT = _env_int("ROBLOXWEB_HTTP_PORT", 9080)
WS_PORT = _env_int("ROBLOXWEB_WS_PORT", 9081)
DATA_DIR = Path(os.environ.get("ROBLOXWEB_DATA_DIR", str(SERVER_DIR / "data")))
WEB_ROOT = ROOT_DIR / "WEBhtml"
DEFAULT_LEVEL_PATH = ROOT_DIR / "Godot" / "robloxwebengine" / "levels" / "default.rwl.json"
SCRIPT_DEMO_LEVEL_PATH = ROOT_DIR / "Godot" / "robloxwebengine" / "levels" / "scripts_demo.rwl.json"

# Override esplicito per il deploy (es. wss://dominio/ws). Vuoto = derivato dalla richiesta.
WS_PUBLIC_URL = os.environ.get("ROBLOXWEB_WS_URL", "")

# Dietro un reverse proxy (Caddy/nginx) l'IP reale arriva da X-Forwarded-For.
# Attivare solo quando il proxy è l'unico modo per raggiungere il server.
TRUST_PROXY = _env_bool("ROBLOXWEB_TRUST_PROXY", False)
ADMIN_USERS = _env_list("ROBLOXWEB_ADMIN_USERS")

LOG_LEVEL = os.environ.get("ROBLOXWEB_LOG_LEVEL", "INFO").upper()
LOG_MAX_BYTES = _env_int("ROBLOXWEB_LOG_MAX_BYTES", 2 * 1024 * 1024)
LOG_BACKUP_COUNT = max(1, _env_int("ROBLOXWEB_LOG_BACKUP_COUNT", 3))
BACKUP_KEEP = max(0, _env_int("ROBLOXWEB_BACKUP_KEEP", 14))

SESSION_DAYS = 30
TICKET_SECONDS = 600
GUEST_CLEANUP_DAYS = 7
MAINTENANCE_HOURS = _env_int("ROBLOXWEB_MAINTENANCE_HOURS", 6)

MAX_JSON_BODY = 64 * 1024
MAX_LEVEL_BYTES = 2 * 1024 * 1024
MAX_PUBLISH_BODY = MAX_LEVEL_BYTES + MAX_JSON_BODY
MAX_THUMBNAIL_BYTES = 1024 * 1024
MAX_THUMBNAIL_WIDTH = 1920
MAX_THUMBNAIL_HEIGHT = 1080
MAX_PLAYERS_PER_ROOM = 16
MAX_WS_CLIENTS = 64
MAX_WS_CONNECTIONS = 96
MAX_WS_PER_IP = 12
MAX_WS_MESSAGE = 16 * 1024
WS_CHAT_PER_MINUTE = 20
WS_STATE_PER_SECOND = 30

# Limiti per scope: (richieste, finestra in secondi). Chiave = IP (+ soggetto).
RATE_LIMITS = {
    "default": (60, 60.0),
    "guest": (20, 60.0),
    "register": (10, 60.0),
    "login": (10, 60.0),
    "publish": (30, 60.0),
    "like": (60, 60.0),
    "report": (20, 60.0),
    "rollback": (20, 60.0),
    "play": (120, 60.0),
    "admin": (60, 60.0),
}

RATE_LIMIT_WINDOW = 60.0
RATE_LIMIT_MAX = 60

DEMO_USERNAME = "demo"
DEMO_PASSWORD = "demo1234"
AUTHOR_USERNAME = "RobloxWeb"

_SEED_PLACE_TITLE = "Welcome Obby"
_SCRIPT_DEMO_TITLE = "Demo script"

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
    trust_proxy: bool | None = None,
    admin_users: tuple[str, ...] | list[str] | str | None = None,
    log_level: str | None = None,
    rate_limits: dict[str, tuple[int, float]] | None = None,
    backup_keep: int | None = None,
) -> None:
    """Riconfigura il modulo (usato dai test e da run.py)."""
    global HOST, HTTP_PORT, WS_PORT, DATA_DIR, WEB_ROOT, DEFAULT_LEVEL_PATH
    global WS_PUBLIC_URL, TRUST_PROXY, ADMIN_USERS, LOG_LEVEL, RATE_LIMITS
    global BACKUP_KEEP, _secret_cache
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
    if trust_proxy is not None:
        TRUST_PROXY = bool(trust_proxy)
    if admin_users is not None:
        if isinstance(admin_users, str):
            ADMIN_USERS = tuple(
                item.strip() for item in admin_users.split(",") if item.strip()
            )
        else:
            ADMIN_USERS = tuple(str(item).strip() for item in admin_users if str(item).strip())
    if log_level is not None:
        LOG_LEVEL = str(log_level).upper()
    if rate_limits is not None:
        RATE_LIMITS = {key: (int(v[0]), float(v[1])) for key, v in rate_limits.items()}
    if backup_keep is not None:
        BACKUP_KEEP = max(0, int(backup_keep))
    _secret_cache = None


def db_path() -> Path:
    return DATA_DIR / "app.db"


def thumbs_dir() -> Path:
    return DATA_DIR / "thumbs"


def logs_dir() -> Path:
    return DATA_DIR / "logs"


def backups_dir() -> Path:
    return DATA_DIR / "backups"


def ensure_data_dir() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    thumbs_dir().mkdir(parents=True, exist_ok=True)
    logs_dir().mkdir(parents=True, exist_ok=True)
    backups_dir().mkdir(parents=True, exist_ok=True)


def secret_key() -> bytes:
    """Chiave HMAC persistente.

    Preferisce `ROBLOXWEB_SECRET` (utile in deploy); altrimenti usa
    `data/secret.key`, generata al primo uso con permessi 0600.
    """
    global _secret_cache
    if _secret_cache is not None:
        return _secret_cache
    env_secret = os.environ.get("ROBLOXWEB_SECRET", "").strip()
    if env_secret:
        _secret_cache = env_secret.encode("utf-8")
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


def rate_limits() -> dict[str, tuple[int, float]]:
    return dict(RATE_LIMITS)


def seed_place_title() -> str:
    return _SEED_PLACE_TITLE


def script_demo_title() -> str:
    return _SCRIPT_DEMO_TITLE
