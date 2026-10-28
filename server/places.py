"""Place, versioni, thumbnail e seed della piattaforma."""
from __future__ import annotations

import json
import struct
from pathlib import Path

import auth
import config
import db

SORTS = {"popular", "recent", "visits"}
VISIBILITIES = ("public", "unlisted", "private")
MAX_TITLE = 60
MAX_DESCRIPTION = 500
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


class PlaceError(Exception):
    pass


def _validate_level_text(text: str) -> dict:
    if len(text.encode("utf-8")) > config.MAX_LEVEL_BYTES:
        raise PlaceError("Livello troppo grande (massimo 2 MB).")
    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        raise PlaceError("Il livello non è JSON valido.") from exc
    if not isinstance(data, dict):
        raise PlaceError("Il livello deve essere un oggetto JSON.")
    if data.get("format") != "robloxweb-level":
        raise PlaceError('Formato livello non riconosciuto (atteso "robloxweb-level").')
    version_value = data.get("version")
    if isinstance(version_value, bool) or not isinstance(version_value, (int, float)):
        raise PlaceError("Versione del livello non supportata.")
    version = int(version_value)
    if version != version_value or version < 1 or version > 2:
        raise PlaceError("Versione del livello non supportata.")
    meta = data.get("meta", {})
    if not isinstance(meta, dict):
        raise PlaceError('Campo "meta" non valido.')
    parts = data.get("parts")
    if not isinstance(parts, list):
        raise PlaceError('Campo "parts" mancante o non valido.')
    if len(parts) > 2000:
        raise PlaceError("Troppe parti nel livello (massimo 2000).")
    scripts = data.get("scripts", [])
    if not isinstance(scripts, list) or len(scripts) > 200:
        raise PlaceError('Campo "scripts" non valido.')
    return data


def prepare_level(value) -> tuple[str, dict]:
    """Accetta un livello come oggetto o come stringa JSON.

    Ritorna il testo originale (o la serializzazione compatta dell'oggetto) e i dati
    parsati: il server salva il testo senza riscriverlo quando arriva già come stringa.
    """
    if isinstance(value, str):
        text = value
    elif isinstance(value, dict):
        text = json.dumps(value, ensure_ascii=False, separators=(",", ":"))
    else:
        raise PlaceError('Campo "level" mancante o non valido.')
    return text, _validate_level_text(text)


def clean_title(value, fallback: str = "Esperienza senza titolo") -> str:
    title = str(value or "").strip()
    return title[:MAX_TITLE] if title else fallback


def clean_description(value) -> str:
    return str(value or "").strip()[:MAX_DESCRIPTION]


def clean_visibility(value, fallback: str = "public") -> str:
    visibility = str(value or "").strip().lower()
    return visibility if visibility in VISIBILITIES else fallback


def read_default_level_text() -> str:
    path = Path(config.DEFAULT_LEVEL_PATH)
    if not path.exists():
        raise PlaceError(f"Livello predefinito non trovato: {path}")
    text = path.read_text(encoding="utf-8")
    _validate_level_text(text)
    return text


def _row_dict(row) -> dict:
    return {key: row[key] for key in row.keys()}


def public_place(row, live: int = 0) -> dict:
    keys = row.keys()
    thumbnail_path = row["thumbnail_path"] if "thumbnail_path" in keys else None
    place_id = int(row["id"])
    version = int(row["current_version"])
    thumbnail_url = None
    if thumbnail_path and version > 0 and thumbnail_file(place_id).is_file():
        thumbnail_url = f"/thumbs/{place_id}.png?v={version}"
    return {
        "id": place_id,
        "title": str(row["title"]),
        "description": str(row["description"]),
        "author": str(row["author"]) if "author" in keys else "",
        "owner_id": int(row["owner_id"]),
        "visibility": str(row["visibility"]),
        "visits": int(row["visits"]),
        "live_players": int(live),
        "current_version": version,
        "created_at": str(row["created_at"]),
        "updated_at": str(row["updated_at"]),
        "thumbnail_url": thumbnail_url,
    }


def _select_places(where: str, params: list, order: str, limit: int) -> list:
    sql = (
        "SELECT p.*, u.display_name AS author,"
        " (SELECT v.thumbnail_path FROM place_versions v"
        "   WHERE v.place_id = p.id AND v.version = p.current_version) AS thumbnail_path"
        " FROM places p JOIN users u ON u.id = p.owner_id"
        f" WHERE {where} ORDER BY {order} LIMIT ?"
    )
    return db.connection().execute(sql, [*params, max(1, min(int(limit), 100))]).fetchall()


def list_places(sort: str = "popular", q: str = "", live_lookup=None, limit: int = 50) -> list[dict]:
    if sort not in SORTS:
        sort = "popular"
    order = {
        "popular": "p.visits DESC, p.updated_at DESC",
        "visits": "p.visits DESC, p.updated_at DESC",
        "recent": "p.updated_at DESC, p.id DESC",
    }[sort]
    where = "p.visibility = 'public' AND p.current_version > 0"
    params: list = []
    query = q.strip()
    if query:
        where += " AND (p.title LIKE ? OR u.display_name LIKE ?)"
        like = f"%{query}%"
        params.extend([like, like])
    out = []
    for row in _select_places(where, params, order, limit):
        live = int(live_lookup(int(row["id"]))) if live_lookup else 0
        out.append(public_place(row, live))
    return out


def list_owned(owner_id: int, live_lookup=None) -> list[dict]:
    """Tutte le place dell'utente, incluse private e senza versione pubblicata."""
    rows = _select_places(
        "p.owner_id = ?", [int(owner_id)], "p.updated_at DESC, p.id DESC", 200
    )
    out = []
    for row in rows:
        live = int(live_lookup(int(row["id"]))) if live_lookup else 0
        out.append(public_place(row, live))
    return out


def list_by_author(owner_id: int, live_lookup=None) -> list[dict]:
    rows = _select_places(
        "p.owner_id = ? AND p.visibility = 'public' AND p.current_version > 0",
        [int(owner_id)],
        "p.visits DESC, p.updated_at DESC",
        100,
    )
    out = []
    for row in rows:
        live = int(live_lookup(int(row["id"]))) if live_lookup else 0
        out.append(public_place(row, live))
    return out


def get_place(place_id: int):
    return db.connection().execute(
        "SELECT p.*, u.display_name AS author,"
        " (SELECT v.thumbnail_path FROM place_versions v"
        "   WHERE v.place_id = p.id AND v.version = p.current_version) AS thumbnail_path"
        " FROM places p JOIN users u ON u.id = p.owner_id WHERE p.id = ?",
        (int(place_id),),
    ).fetchone()


def get_place_detail(place_id: int, live: int = 0) -> dict | None:
    row = get_place(place_id)
    return public_place(row, live) if row else None


def current_version(place_id: int):
    return db.connection().execute(
        "SELECT * FROM place_versions WHERE place_id = ? AND version ="
        " (SELECT current_version FROM places WHERE id = ?)",
        (int(place_id), int(place_id)),
    ).fetchone()


def increment_visits(place_id: int) -> None:
    conn = db.connection()
    conn.execute("UPDATE places SET visits = visits + 1 WHERE id = ?", (int(place_id),))
    conn.commit()


def can_view(place_row, user_id: int | None) -> bool:
    if place_row is None:
        return False
    visibility = str(place_row["visibility"])
    if visibility in ("public", "unlisted"):
        return True
    return user_id is not None and int(place_row["owner_id"]) == int(user_id)


def is_owner(place_row, user_id: int | None) -> bool:
    return (
        place_row is not None
        and user_id is not None
        and int(place_row["owner_id"]) == int(user_id)
    )


def create_place(
    owner_id: int,
    title: str,
    description: str,
    data_text: str,
    visibility: str = "public",
) -> int:
    title = clean_title(title)
    description = clean_description(description)
    visibility = clean_visibility(visibility)
    _validate_level_text(data_text)
    now = db.utc_now()
    conn = db.connection()
    try:
        cur = conn.execute(
            "INSERT INTO places(owner_id, title, description, visibility, created_at, updated_at,"
            " current_version, visits) VALUES(?, ?, ?, ?, ?, ?, 1, 0)",
            (int(owner_id), title, description, visibility, now, now),
        )
        place_id = int(cur.lastrowid)
        conn.execute(
            "INSERT INTO place_versions(place_id, version, data_json, created_at)"
            " VALUES(?, 1, ?, ?)",
            (place_id, data_text, now),
        )
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    return place_id


def update_place(place_id: int, fields: dict) -> bool:
    """Aggiorna i metadati della place. Ritorna False se non esiste."""
    updates: list[str] = []
    params: list = []
    if "title" in fields:
        updates.append("title = ?")
        params.append(clean_title(fields["title"]))
    if "description" in fields:
        updates.append("description = ?")
        params.append(clean_description(fields["description"]))
    if "visibility" in fields:
        updates.append("visibility = ?")
        params.append(clean_visibility(fields["visibility"]))
    if not updates:
        return False
    updates.append("updated_at = ?")
    params.append(db.utc_now())
    params.append(int(place_id))
    conn = db.connection()
    cur = conn.execute(f"UPDATE places SET {', '.join(updates)} WHERE id = ?", params)
    conn.commit()
    return cur.rowcount > 0


def publish_version(place_id: int, data_text: str, fields: dict | None = None) -> int:
    """Aggiunge una nuova versione, la rende corrente e applica i metadati opzionali.

    La thumbnail della versione precedente viene riportata sulla nuova finché non
    ne arriva una aggiornata: la card non perde l'immagine a ogni pubblicazione.
    """
    _validate_level_text(data_text)
    conn = db.connection()
    row = conn.execute(
        "SELECT current_version,"
        " (SELECT thumbnail_path FROM place_versions WHERE place_id = ? AND version ="
        "   places.current_version) AS thumbnail_path"
        " FROM places WHERE id = ?",
        (int(place_id), int(place_id)),
    ).fetchone()
    if row is None:
        raise PlaceError("Place non trovata.")
    version = int(row["current_version"]) + 1
    now = db.utc_now()
    updates = ["current_version = ?", "updated_at = ?"]
    params: list = [version, now]
    if fields:
        if "title" in fields:
            updates.append("title = ?")
            params.append(clean_title(fields["title"]))
        if "description" in fields:
            updates.append("description = ?")
            params.append(clean_description(fields["description"]))
        if "visibility" in fields:
            updates.append("visibility = ?")
            params.append(clean_visibility(fields["visibility"]))
    params.append(int(place_id))
    try:
        conn.execute(
            "INSERT INTO place_versions(place_id, version, data_json, thumbnail_path, created_at)"
            " VALUES(?, ?, ?, ?, ?)",
            (int(place_id), version, data_text, row["thumbnail_path"], now),
        )
        conn.execute(
            f"UPDATE places SET {', '.join(updates)} WHERE id = ?",
            params,
        )
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    return version


def list_versions(place_id: int) -> list[dict]:
    rows = db.connection().execute(
        "SELECT version, thumbnail_path, created_at,"
        " length(CAST(data_json AS BLOB)) AS bytes"
        " FROM place_versions WHERE place_id = ? ORDER BY version DESC",
        (int(place_id),),
    ).fetchall()
    return [
        {
            "version": int(row["version"]),
            "bytes": int(row["bytes"]),
            "has_thumbnail": bool(row["thumbnail_path"]),
            "created_at": str(row["created_at"]),
        }
        for row in rows
    ]


def get_version(place_id: int, version: int):
    return db.connection().execute(
        "SELECT * FROM place_versions WHERE place_id = ? AND version = ?",
        (int(place_id), int(version)),
    ).fetchone()


def level_from_version(row) -> dict:
    try:
        value = json.loads(str(row["data_json"]))
    except (json.JSONDecodeError, TypeError, KeyError):
        raise PlaceError("Livello non leggibile sul server.")
    if not isinstance(value, dict):
        raise PlaceError("Livello non leggibile sul server.")
    return value


# --- Thumbnail ------------------------------------------------------------------


def thumbnail_file(place_id: int) -> Path:
    return config.thumbs_dir() / f"{int(place_id)}.png"


def png_size(data: bytes) -> tuple[int, int] | None:
    """Legge larghezza/altezza dall'IHDR, verificando firma e struttura minima."""
    if len(data) < 33 or not data.startswith(PNG_SIGNATURE):
        return None
    if data[12:16] != b"IHDR":
        return None
    width, height = struct.unpack(">II", data[16:24])
    if width <= 0 or height <= 0:
        return None
    return width, height


def validate_thumbnail(data: bytes) -> None:
    if len(data) > config.MAX_THUMBNAIL_BYTES:
        raise PlaceError("Thumbnail troppo grande (massimo 1 MB).")
    size = png_size(data)
    if size is None:
        raise PlaceError("La thumbnail deve essere un PNG valido.")
    width, height = size
    if width > config.MAX_THUMBNAIL_WIDTH or height > config.MAX_THUMBNAIL_HEIGHT:
        raise PlaceError(
            "Thumbnail troppo grande: massimo %dx%d pixel."
            % (config.MAX_THUMBNAIL_WIDTH, config.MAX_THUMBNAIL_HEIGHT)
        )


def set_thumbnail(place_id: int, data: bytes) -> int:
    """Salva la thumbnail della versione corrente. Ritorna la versione aggiornata."""
    validate_thumbnail(data)
    row = current_version(place_id)
    if row is None:
        raise PlaceError("L'esperienza non ha una versione pubblicata.")
    target = thumbnail_file(place_id)
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_suffix(".png.tmp")
    temporary.write_bytes(data)
    temporary.replace(target)
    conn = db.connection()
    conn.execute(
        "UPDATE place_versions SET thumbnail_path = ? WHERE place_id = ? AND version = ?",
        (target.name, int(place_id), int(row["version"])),
    )
    conn.commit()
    return int(row["version"])


def seed_demo() -> dict:
    """Seed idempotente: utenti demo/autore + "Welcome Obby" versione 1."""
    summary = {"created_users": [], "created_place": False, "place_id": None}
    demo = auth.get_user_by_username(config.DEMO_USERNAME)
    if demo is None:
        demo = auth.create_account(config.DEMO_USERNAME, config.DEMO_PASSWORD)
        summary["created_users"].append(config.DEMO_USERNAME)
        print(
            f"[seed] creato utente demo ({config.DEMO_USERNAME}/{config.DEMO_PASSWORD})"
            " — cambiare la password prima di un uso reale"
        )
    author = auth.get_user_by_username(config.AUTHOR_USERNAME)
    if author is None:
        try:
            author = auth.create_account(config.AUTHOR_USERNAME, "robloxweb-dev")
        except auth.AuthError:
            author = auth.create_guest()
            conn = db.connection()
            conn.execute(
                "UPDATE users SET username = ?, display_name = ?, is_guest = 0 WHERE id = ?",
                (config.AUTHOR_USERNAME.lower(), config.AUTHOR_USERNAME, int(author["id"])),
            )
            conn.commit()
            author = auth.get_user_by_id(int(author["id"]))
        summary["created_users"].append(config.AUTHOR_USERNAME)
        print(f"[seed] creato utente autore {config.AUTHOR_USERNAME}")

    conn = db.connection()
    place = conn.execute(
        "SELECT * FROM places WHERE owner_id = ? AND title = ?",
        (int(author["id"]), config.seed_place_title()),
    ).fetchone()
    if place is None:
        text = read_default_level_text()
        place_id = create_place(
            int(author["id"]),
            config.seed_place_title(),
            "Il primo obby della piattaforma: monete, checkpoint, lava e traguardo.",
            text,
            visibility="public",
        )
        summary["created_place"] = True
    else:
        place_id = int(place["id"])
        if int(place["current_version"]) <= 0:
            publish_version(place_id, read_default_level_text())
    summary["place_id"] = place_id
    if summary["created_place"]:
        print(f"[seed] creata place \"{config.seed_place_title()}\" (id {place_id})")
    return summary
