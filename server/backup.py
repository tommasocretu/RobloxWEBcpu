"""Backup e ripristino di DB + thumbnail.

Il DB viene copiato con l'API di SQLite (`db.backup`), quindi è consistente
anche con WAL attivo. Ogni backup è una cartella autoconsistente:

    data/backups/app-20261028-120000/
      app.db
      thumbs/<place_id>.png
      manifest.json
"""
from __future__ import annotations

import json
import shutil
import sqlite3
from datetime import datetime, timezone
from pathlib import Path

import config
import db
import logs

_log = logs.get("backup")


class BackupError(Exception):
    pass


def _stamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")


def _manifest(db_file: Path, thumbs: Path | None) -> dict:
    thumb_files = (
        list(thumbs.glob("*.png")) if thumbs is not None and thumbs.is_dir() else []
    )
    conn = sqlite3.connect(str(db_file))
    try:
        version = int(conn.execute("PRAGMA user_version").fetchone()[0])
        places = int(conn.execute("SELECT COUNT(*) FROM places").fetchone()[0])
        users = int(conn.execute("SELECT COUNT(*) FROM users").fetchone()[0])
    finally:
        conn.close()
    return {
        "format": "robloxweb-backup",
        "version": 1,
        "app_version": config.VERSION,
        "schema_version": version,
        "created_at": db.utc_now(),
        "db_bytes": db_file.stat().st_size,
        "thumbs": len(thumb_files),
        "users": users,
        "places": places,
    }


def create_backup(
    destination: str | Path | None = None,
    *,
    include_thumbs: bool = True,
    keep: int | None = None,
) -> Path:
    """Crea un backup completo e ritorna la cartella (o il file `.db`).

    `destination` può essere una cartella oppure un file `.db` (in quel caso le
    thumbnail vanno in `<nome>-thumbs/` e il manifest in `<nome>-manifest.json`).
    """
    config.ensure_data_dir()
    config.backups_dir().mkdir(parents=True, exist_ok=True)
    legacy_file = False
    if destination is None:
        stamp = _stamp()
        root = config.backups_dir() / f"app-{stamp}"
        suffix = 1
        while root.exists():
            root = config.backups_dir() / f"app-{stamp}-{suffix}"
            suffix += 1
        db_file = root / "app.db"
        thumbs_target = root / "thumbs"
        manifest_target = root / "manifest.json"
    else:
        target = Path(destination)
        if target.suffix.lower() == ".db":
            legacy_file = True
            db_file = target
            root = target.parent
            thumbs_target = root / f"{target.stem}-thumbs"
            manifest_target = root / f"{target.stem}-manifest.json"
        else:
            root = target
            db_file = root / "app.db"
            thumbs_target = root / "thumbs"
            manifest_target = root / "manifest.json"
    db_file.parent.mkdir(parents=True, exist_ok=True)
    if db_file.resolve() == config.db_path().resolve():
        raise BackupError("La destinazione del backup non può essere il database attivo.")
    if db_file.exists():
        db_file.unlink()
    db.backup(db_file)

    if include_thumbs:
        source_thumbs = config.thumbs_dir()
        if thumbs_target.exists():
            shutil.rmtree(thumbs_target)
        if source_thumbs.is_dir():
            shutil.copytree(source_thumbs, thumbs_target)
        else:
            thumbs_target.mkdir(parents=True, exist_ok=True)
    else:
        if thumbs_target.exists():
            shutil.rmtree(thumbs_target)
        thumbs_target = None

    manifest = _manifest(db_file, thumbs_target)
    manifest["include_thumbs"] = bool(include_thumbs)
    manifest_target.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    _log.info(
        "backup creato in %s (db=%s B, thumbnail=%s)",
        root,
        manifest["db_bytes"],
        manifest["thumbs"],
    )
    if not legacy_file:
        effective_keep = config.BACKUP_KEEP if keep is None else int(keep)
        if effective_keep > 0:
            prune_backups(keep=effective_keep)
    return db_file if legacy_file else root


def prune_backups(keep: int = config.BACKUP_KEEP) -> list[Path]:
    """Elimina i backup `app-*` più vecchi, mantenendo almeno l'ultimo."""
    keep = max(1, int(keep))
    root = config.backups_dir()
    if not root.is_dir():
        return []
    candidates = sorted(
        (path for path in root.glob("app-*") if path.is_dir()),
        key=lambda path: path.stat().st_mtime,
        reverse=True,
    )
    removed = []
    for path in candidates[keep:]:
        try:
            shutil.rmtree(path)
            removed.append(path)
        except OSError as exc:  # pragma: no cover - dipende dal filesystem
            _log.warning("impossibile rimuovere il backup %s: %r", path, exc)
    if removed:
        _log.info("backup rimossi: %d", len(removed))
    return removed


def _resolve_source(source: str | Path) -> tuple[Path, Path | None, Path | None]:
    source = Path(source)
    if source.is_file() and source.suffix.lower() == ".db":
        thumbs = source.parent / f"{source.stem}-thumbs"
        manifest = source.parent / f"{source.stem}-manifest.json"
        return source, thumbs if thumbs.is_dir() else None, manifest if manifest.is_file() else None
    if source.is_dir():
        db_file = source / "app.db"
        if not db_file.is_file():
            raise BackupError(f"Backup non valido: manca {db_file}.")
        thumbs = source / "thumbs"
        manifest = source / "manifest.json"
        return db_file, thumbs if thumbs.is_dir() else None, manifest if manifest.is_file() else None
    raise BackupError(f"Backup non trovato: {source}")


def _integrity_check(path: Path) -> None:
    if not path.is_file():
        raise BackupError(f"File di backup mancante: {path}")
    conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    try:
        result = conn.execute("PRAGMA integrity_check").fetchone()
    except sqlite3.Error as exc:
        raise BackupError(f"Database di backup illeggibile: {exc}") from exc
    finally:
        conn.close()
    if not result or str(result[0]).lower() != "ok":
        raise BackupError("Il database di backup non supera il controllo di integrità.")


def restore_backup(source: str | Path) -> dict:
    """Sostituisce DB e thumbnail correnti con quelli di un backup.

    Operazione distruttiva: il chiamante (manage.py) deve chiedere conferma.
    """
    db_file, thumbs, manifest_path = _resolve_source(source)
    _integrity_check(db_file)
    config.ensure_data_dir()
    db.close()
    target = config.db_path()
    temp_db = target.with_name(target.name + ".restore.tmp")
    shutil.copy2(db_file, temp_db)
    for suffix in ("", "-wal", "-shm"):
        candidate = Path(str(target) + suffix)
        if candidate.exists():
            candidate.unlink()
    target.parent.mkdir(parents=True, exist_ok=True)
    temp_db.replace(target)
    if thumbs is not None:
        current = config.thumbs_dir()
        temp_thumbs = current.with_name(current.name + ".restore.tmp")
        if temp_thumbs.exists():
            shutil.rmtree(temp_thumbs)
        shutil.copytree(thumbs, temp_thumbs)
        if current.exists():
            shutil.rmtree(current)
        temp_thumbs.replace(current)
    db.configure(target)
    db.init()
    manifest = {}
    if manifest_path is not None:
        try:
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            manifest = {}
    _log.warning("backup ripristinato da %s", db_file)
    return {"db": str(target), "thumbs": bool(thumbs), "manifest": manifest}
