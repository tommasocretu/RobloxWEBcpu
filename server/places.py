"""Place, versioni e seed della piattaforma."""
from __future__ import annotations

import json
from pathlib import Path

import auth
import config
import db

SORTS = {"popular", "recent", "visits"}


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
    version = data.get("version")
    if not isinstance(version, int) or version < 1 or version > 2:
        raise PlaceError("Versione del livello non supportata.")
    parts = data.get("parts")
    if not isinstance(parts, list):
        raise PlaceError('Campo "parts" mancante o non valido.')
    if len(parts) > 2000:
        raise PlaceError("Troppe parti nel livello (massimo 2000).")
    scripts = data.get("scripts", [])
    if not isinstance(scripts, list) or len(scripts) > 200:
        raise PlaceError('Campo "scripts" non valido.')
    return data


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
    return {
        "id": int(row["id"]),
        "title": str(row["title"]),
        "description": str(row["description"]),
        "author": str(row["author"]) if "author" in row.keys() else "",
        "owner_id": int(row["owner_id"]),
        "visibility": str(row["visibility"]),
        "visits": int(row["visits"]),
        "live_players": int(live),
        "current_version": int(row["current_version"]),
        "created_at": str(row["created_at"]),
        "updated_at": str(row["updated_at"]),
        "thumbnail_url": None,
    }


def list_places(sort: str = "popular", q: str = "", live_lookup=None, limit: int = 50) -> list[dict]:
    if sort not in SORTS:
        sort = "popular"
    order = {
        "popular": "p.visits DESC, p.updated_at DESC",
        "visits": "p.visits DESC, p.updated_at DESC",
        "recent": "p.updated_at DESC, p.id DESC",
    }[sort]
    sql = (
        "SELECT p.*, u.display_name AS author FROM places p"
        " JOIN users u ON u.id = p.owner_id"
        " WHERE p.visibility = 'public' AND p.current_version > 0"
    )
    params: list = []
    query = q.strip()
    if query:
        sql += " AND (p.title LIKE ? OR u.display_name LIKE ?)"
        like = f"%{query}%"
        params.extend([like, like])
    sql += f" ORDER BY {order} LIMIT ?"
    params.append(max(1, min(int(limit), 100)))
    rows = db.connection().execute(sql, params).fetchall()
    out = []
    for row in rows:
        live = int(live_lookup(int(row["id"]))) if live_lookup else 0
        out.append(public_place(row, live))
    return out


def get_place(place_id: int):
    return db.connection().execute(
        "SELECT p.*, u.display_name AS author FROM places p"
        " JOIN users u ON u.id = p.owner_id WHERE p.id = ?",
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


def create_place(
    owner_id: int,
    title: str,
    description: str,
    data_text: str,
    visibility: str = "public",
) -> int:
    title = title.strip()[:60] or "Esperienza senza titolo"
    description = description.strip()[:500]
    if visibility not in ("public", "unlisted", "private"):
        visibility = "public"
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


def publish_version(place_id: int, data_text: str) -> int:
    """Aggiunge una nuova versione e la rende corrente (usato dal seed/M1)."""
    _validate_level_text(data_text)
    conn = db.connection()
    row = conn.execute("SELECT current_version FROM places WHERE id = ?", (int(place_id),)).fetchone()
    if row is None:
        raise PlaceError("Place non trovata.")
    version = int(row["current_version"]) + 1
    now = db.utc_now()
    try:
        conn.execute(
            "INSERT INTO place_versions(place_id, version, data_json, created_at)"
            " VALUES(?, ?, ?, ?)",
            (int(place_id), version, data_text, now),
        )
        conn.execute(
            "UPDATE places SET current_version = ?, updated_at = ? WHERE id = ?",
            (version, now, int(place_id)),
        )
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    return version


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
