"""Moderazione di base: amministratori, segnalazioni e place nascoste.

Un amministratore vede le segnalazioni aperte, può ignorarle oppure nascondere
l'esperienza. Le place nascoste restano visibili al proprietario nel profilo, ma
escono da catalogo, profili pubblici, like e play.
"""
from __future__ import annotations

import db
import logs

REPORT_STATUSES = ("open", "resolved", "all")
MAX_REASON = 200

_log = logs.get("moderation")


class ModerationError(Exception):
    """Errore mostrabile all'utente (segnalazione o place non valida)."""


def is_admin(user) -> bool:
    if user is None:
        return False
    try:
        return bool(user["is_admin"])
    except (KeyError, IndexError):
        return False


def apply_env_admins(usernames) -> int:
    """Rende `usernames` l'elenco autorevole degli amministratori.

    Se la lista è vuota non tocca il database: i permessi restano quelli
    assegnati con `manage.py admin`.
    """
    names = [str(name).strip() for name in usernames if str(name).strip()]
    if not names:
        return 0
    conn = db.connection()
    conn.execute("UPDATE users SET is_admin = 0")
    changed = 0
    for name in names:
        cur = conn.execute(
            "UPDATE users SET is_admin = 1 WHERE username = ? COLLATE NOCASE"
            " AND is_guest = 0",
            (name,),
        )
        changed += max(0, cur.rowcount)
    conn.commit()
    _log.info("amministratori da ambiente: %s", ", ".join(names))
    return changed


def set_admin(username: str, enabled: bool = True) -> bool:
    """Assegna o revoca il ruolo admin a un account esistente."""
    conn = db.connection()
    cur = conn.execute(
        "UPDATE users SET is_admin = ? WHERE username = ? COLLATE NOCASE AND is_guest = 0",
        (1 if enabled else 0, str(username).strip()),
    )
    conn.commit()
    return cur.rowcount > 0


def _report_dict(row) -> dict:
    return {
        "id": int(row["id"]),
        "place_id": int(row["place_id"]),
        "place_title": str(row["place_title"]),
        "place_author": str(row["place_author"]),
        "place_owner_id": int(row["place_owner_id"]),
        "place_hidden": bool(row["place_hidden"]),
        "reporter_id": int(row["reporter_id"]),
        "reporter": str(row["reporter_name"]),
        "reason": str(row["reason"]),
        "details": str(row["details"]),
        "status": str(row["status"]),
        "created_at": str(row["created_at"]),
        "resolved_at": str(row["resolved_at"]) if row["resolved_at"] else None,
    }


def list_reports(status: str = "open", limit: int = 100) -> list[dict]:
    status = str(status or "open").lower()
    if status not in REPORT_STATUSES:
        status = "open"
    where = "" if status == "all" else "WHERE r.status = ?"
    params: list = [] if status == "all" else [status]
    rows = db.connection().execute(
        "SELECT r.*, p.title AS place_title, p.owner_id AS place_owner_id,"
        " p.hidden AS place_hidden, owner.display_name AS place_author,"
        " reporter.display_name AS reporter_name"
        " FROM reports r"
        " JOIN places p ON p.id = r.place_id"
        " JOIN users owner ON owner.id = p.owner_id"
        " JOIN users reporter ON reporter.id = r.reporter_id"
        f" {where} ORDER BY r.created_at DESC, r.id DESC LIMIT ?",
        [*params, max(1, min(int(limit), 200))],
    ).fetchall()
    return [_report_dict(row) for row in rows]


def report_counts() -> dict:
    row = db.connection().execute(
        "SELECT SUM(CASE WHEN status = 'open' THEN 1 ELSE 0 END) AS open,"
        " COUNT(*) AS total FROM reports"
    ).fetchone()
    hidden = db.connection().execute(
        "SELECT COUNT(*) AS total FROM places WHERE hidden = 1"
    ).fetchone()
    return {
        "open": int(row["open"] or 0),
        "total": int(row["total"] or 0),
        "hidden": int(hidden["total"] or 0),
    }


def list_hidden_places(limit: int = 100) -> list[dict]:
    rows = db.connection().execute(
        "SELECT p.id, p.title, p.hidden_reason, p.visibility, p.updated_at,"
        " u.display_name AS author FROM places p JOIN users u ON u.id = p.owner_id"
        " WHERE p.hidden = 1 ORDER BY p.id DESC LIMIT ?",
        (max(1, min(int(limit), 200)),),
    ).fetchall()
    return [
        {
            "id": int(row["id"]),
            "title": str(row["title"]),
            "author": str(row["author"]),
            "visibility": str(row["visibility"]),
            "hidden_reason": str(row["hidden_reason"] or ""),
            "updated_at": str(row["updated_at"]),
        }
        for row in rows
    ]


def set_hidden(place_id: int, hidden: bool, reason: str = "") -> bool:
    """Nasconde o ripristina una place senza modificarne i metadati editoriali."""
    conn = db.connection()
    row = conn.execute("SELECT id FROM places WHERE id = ?", (int(place_id),)).fetchone()
    if row is None:
        raise ModerationError("Esperienza non trovata.")
    conn.execute(
        "UPDATE places SET hidden = ?, hidden_reason = ? WHERE id = ?",
        (1 if hidden else 0, str(reason or "")[:MAX_REASON] if hidden else "", int(place_id)),
    )
    conn.commit()
    return bool(hidden)


def resolve_report(
    report_id: int, admin_id: int, action: str, reason: str = ""
) -> dict:
    """Chiude una segnalazione; `hide` nasconde anche la place."""
    action = str(action or "").strip().lower()
    if action not in ("dismiss", "hide"):
        raise ModerationError("Azione non valida (dismiss oppure hide).")
    conn = db.connection()
    row = conn.execute(
        "SELECT * FROM reports WHERE id = ?", (int(report_id),)
    ).fetchone()
    if row is None:
        raise ModerationError("Segnalazione non trovata.")
    place_id = int(row["place_id"])
    try:
        if action == "hide":
            if conn.execute(
                "SELECT 1 FROM places WHERE id = ?", (place_id,)
            ).fetchone() is None:
                raise ModerationError("Esperienza non trovata.")
            conn.execute(
                "UPDATE places SET hidden = 1, hidden_reason = ? WHERE id = ?",
                (str(reason or f"Segnalazione #{report_id}")[:MAX_REASON], place_id),
            )
        conn.execute(
            "UPDATE reports SET status = 'resolved', resolved_at = ?, resolved_by = ?"
            " WHERE id = ?",
            (db.utc_now(), int(admin_id), int(report_id)),
        )
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    _log.info(
        "segnalazione %s %s da admin=%s place=%s",
        report_id,
        "nascosta" if action == "hide" else "ignorata",
        admin_id,
        place_id,
    )
    return {"report_id": int(report_id), "place_id": place_id, "action": action}
