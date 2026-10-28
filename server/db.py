"""SQLite: connessione per thread, schema e migrazioni (`PRAGMA user_version`)."""
from __future__ import annotations

import shutil
import sqlite3
import threading
from datetime import datetime, timezone
from pathlib import Path

import config

_local = threading.local()
_db_path: Path | None = None

SCHEMA_V1 = """
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT UNIQUE NOT NULL,
  display_name TEXT NOT NULL,
  password_hash TEXT NOT NULL DEFAULT '',
  is_guest INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS sessions (
  token_hash TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS places (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_id INTEGER NOT NULL REFERENCES users(id),
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  visibility TEXT NOT NULL DEFAULT 'public',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  current_version INTEGER NOT NULL DEFAULT 0,
  visits INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS place_versions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  place_id INTEGER NOT NULL REFERENCES places(id) ON DELETE CASCADE,
  version INTEGER NOT NULL,
  data_json TEXT NOT NULL,
  thumbnail_path TEXT,
  created_at TEXT NOT NULL,
  UNIQUE(place_id, version)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_username_nocase
  ON users(username COLLATE NOCASE);
CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_places_owner ON places(owner_id);
CREATE INDEX IF NOT EXISTS idx_places_visibility ON places(visibility);
CREATE INDEX IF NOT EXISTS idx_versions_place ON place_versions(place_id);
"""

SCHEMA_V2 = """
ALTER TABLE places ADD COLUMN likes INTEGER NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS place_likes (
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  place_id INTEGER NOT NULL REFERENCES places(id) ON DELETE CASCADE,
  created_at TEXT NOT NULL,
  PRIMARY KEY (user_id, place_id)
);

CREATE TABLE IF NOT EXISTS reports (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  place_id INTEGER NOT NULL REFERENCES places(id) ON DELETE CASCADE,
  reporter_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  details TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL,
  UNIQUE (place_id, reporter_id)
);

CREATE INDEX IF NOT EXISTS idx_place_likes_place ON place_likes(place_id);
CREATE INDEX IF NOT EXISTS idx_reports_place ON reports(place_id);
CREATE INDEX IF NOT EXISTS idx_reports_reporter ON reports(reporter_id);
"""

MIGRATIONS = [(1, SCHEMA_V1), (2, SCHEMA_V2)]


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def configure(path: str | Path | None = None) -> None:
    """Imposta il file del database e chiude la connessione del thread corrente."""
    global _db_path
    close()
    _db_path = Path(path) if path is not None else Path(config.db_path())


def path() -> Path:
    global _db_path
    if _db_path is None:
        _db_path = Path(config.db_path())
    return _db_path


def _connect(target: Path) -> sqlite3.Connection:
    target.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(target), timeout=10.0)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys=ON")
    conn.execute("PRAGMA busy_timeout=10000")
    return conn


def connection() -> sqlite3.Connection:
    target = path()
    conn = getattr(_local, "conn", None)
    if conn is None or getattr(_local, "path", None) != str(target):
        close()
        conn = _connect(target)
        _local.conn = conn
        _local.path = str(target)
    return conn


def close() -> None:
    conn = getattr(_local, "conn", None)
    if conn is not None:
        try:
            conn.close()
        except sqlite3.Error:
            pass
    if hasattr(_local, "conn"):
        del _local.conn
    if hasattr(_local, "path"):
        del _local.path


def init() -> None:
    """Crea lo schema e applica le migrazioni mancanti."""
    conn = connection()
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA synchronous=NORMAL")
    version = int(conn.execute("PRAGMA user_version").fetchone()[0])
    for number, sql in MIGRATIONS:
        if version < number:
            conn.executescript(sql)
            conn.execute(f"PRAGMA user_version={number}")
            conn.commit()
            version = number


def backup(destination: str | Path) -> Path:
    """Backup consistente del DB con l'API di SQLite (WAL incluso)."""
    destination = Path(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        destination.unlink()
    source = connection()
    target = sqlite3.connect(str(destination))
    try:
        source.backup(target)
    finally:
        target.close()
    return destination


def reset(delete_thumbs: bool = True) -> None:
    """Elimina DB, WAL e (opzionalmente) le thumbnail. Irreversibile."""
    close()
    target = path()
    for suffix in ("", "-wal", "-shm"):
        candidate = Path(str(target) + suffix)
        if candidate.exists():
            candidate.unlink()
    if delete_thumbs:
        thumbs = config.thumbs_dir()
        if thumbs.exists():
            shutil.rmtree(thumbs)
    init()
