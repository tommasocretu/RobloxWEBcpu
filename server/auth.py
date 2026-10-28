"""Account, sessioni, ospiti e ticket HMAC per il WebSocket."""
from __future__ import annotations

import base64
import hashlib
import hmac
import json
import re
import secrets
import time

import config
import db

USERNAME_RE = re.compile(r"^[A-Za-z0-9_]{3,20}$")
MIN_PASSWORD = 6
MAX_PASSWORD = 200
AVATAR_COLORS = (
    "#2bd576",
    "#4f8cff",
    "#a06bd0",
    "#ffcf4a",
    "#ff7a59",
    "#4fc2c2",
    "#e06bb0",
    "#8d6bd0",
)


def avatar_color(user_id: int) -> str:
    """Colore stabile dell'avatar, derivato dall'id utente."""
    return AVATAR_COLORS[int(user_id) % len(AVATAR_COLORS)]


class AuthError(Exception):
    """Errore di autenticazione con messaggio mostrabile al client."""


class TicketError(Exception):
    """Ticket WS mancante, scaduto, falsificato o per un'altra place."""


# --- Password -------------------------------------------------------------------


def hash_password(password: str) -> str:
    salt = secrets.token_bytes(16)
    digest = hashlib.scrypt(
        password.encode("utf-8"), salt=salt, n=2**14, r=8, p=1, dklen=32
    )
    return "scrypt$16384$8$1$%s$%s" % (
        base64.b64encode(salt).decode("ascii"),
        base64.b64encode(digest).decode("ascii"),
    )


def verify_password(stored: str, password: str) -> bool:
    try:
        scheme, n, r, p, salt_b64, hash_b64 = str(stored).split("$", 5)
        if scheme != "scrypt":
            return False
        salt = base64.b64decode(salt_b64)
        expected = base64.b64decode(hash_b64)
        actual = hashlib.scrypt(
            password.encode("utf-8"),
            salt=salt,
            n=int(n),
            r=int(r),
            p=int(p),
            dklen=len(expected),
        )
    except (ValueError, TypeError, MemoryError):
        return False
    return hmac.compare_digest(actual, expected)


# --- Utenti ---------------------------------------------------------------------


def _public_user(row) -> dict:
    return {
        "id": int(row["id"]),
        "username": str(row["username"]),
        "name": str(row["display_name"]),
        "avatar_color": avatar_color(int(row["id"])),
        "is_guest": bool(row["is_guest"]),
        "is_admin": bool(row["is_admin"]) if "is_admin" in row.keys() else False,
        "created_at": str(row["created_at"]),
    }


def get_user_by_id(user_id: int):
    return db.connection().execute(
        "SELECT * FROM users WHERE id = ?", (int(user_id),)
    ).fetchone()


def get_user_by_username(username: str):
    return db.connection().execute(
        "SELECT * FROM users WHERE username = ? COLLATE NOCASE", (username,)
    ).fetchone()


def _insert_user(username: str, display_name: str, password: str, is_guest: bool):
    conn = db.connection()
    try:
        cur = conn.execute(
            "INSERT INTO users(username, display_name, password_hash, is_guest, created_at)"
            " VALUES(?, ?, ?, ?, ?)",
            (
                username,
                display_name,
                hash_password(password) if password else "",
                1 if is_guest else 0,
                db.utc_now(),
            ),
        )
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    return get_user_by_id(int(cur.lastrowid))


def create_account(username: str, password: str):
    username = username.strip()
    if not USERNAME_RE.match(username):
        raise AuthError(
            "Username non valido: 3-20 caratteri tra lettere, numeri e underscore."
        )
    if len(password) < MIN_PASSWORD:
        raise AuthError(f"La password deve avere almeno {MIN_PASSWORD} caratteri.")
    if len(password) > MAX_PASSWORD:
        raise AuthError("Password troppo lunga.")
    if get_user_by_username(username) is not None:
        raise AuthError("Username già in uso.")
    return _insert_user(username, username, password, False)


def _dummy_verify(password: str) -> None:
    """Costo di verifica simile a quello reale per non rivelare gli username."""
    hashlib.scrypt(
        password.encode("utf-8")[:MAX_PASSWORD],
        salt=b"robloxweb-dummy!",
        n=2**14,
        r=8,
        p=1,
        dklen=32,
    )


def authenticate(username: str, password: str):
    row = get_user_by_username(username.strip())
    if row is None or bool(row["is_guest"]):
        _dummy_verify(str(password)[:MAX_PASSWORD])
        return None
    if len(password) > MAX_PASSWORD:
        _dummy_verify("")
        return None
    if not verify_password(str(row["password_hash"]), password):
        return None
    return row


def create_guest():
    for _ in range(20):
        username = "guest_%s" % secrets.token_hex(8)
        if get_user_by_username(username) is None:
            display = "Ospite%04d" % secrets.randbelow(9000)
            return _insert_user(username, display, "", True)
    raise AuthError("Impossibile creare un ospite, riprova.")


def public_user(row) -> dict:
    return _public_user(row)


def cleanup_guests(days: int = config.GUEST_CLEANUP_DAYS) -> int:
    """Elimina gli ospiti vecchi senza sessioni ancora valide."""
    conn = db.connection()
    cutoff = db.utc_now()  # confronto testuale ISO; calcoliamo la soglia in Python
    from datetime import datetime, timedelta, timezone

    threshold = (
        datetime.now(timezone.utc) - timedelta(days=max(0, int(days)))
    ).isoformat(timespec="seconds")
    cur = conn.execute(
        "DELETE FROM users WHERE is_guest = 1 AND created_at < ? AND id NOT IN ("
        " SELECT user_id FROM sessions WHERE expires_at > ?)",
        (threshold, cutoff),
    )
    removed = cur.rowcount
    conn.commit()
    return int(max(0, removed))


# --- Sessioni -------------------------------------------------------------------


def _token_hash(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def cleanup_sessions() -> None:
    conn = db.connection()
    conn.execute("DELETE FROM sessions WHERE expires_at <= ?", (db.utc_now(),))
    conn.commit()


def create_session(user_id: int, days: int = config.SESSION_DAYS) -> str:
    from datetime import datetime, timedelta, timezone

    cleanup_sessions()
    token = secrets.token_urlsafe(32)
    now = datetime.now(timezone.utc)
    expires = (now + timedelta(days=max(1, int(days)))).isoformat(timespec="seconds")
    conn = db.connection()
    conn.execute(
        "INSERT INTO sessions(token_hash, user_id, expires_at, created_at) VALUES(?, ?, ?, ?)",
        (_token_hash(token), int(user_id), expires, now.isoformat(timespec="seconds")),
    )
    conn.commit()
    return token


def resolve_session(token: str):
    if not token:
        return None
    row = db.connection().execute(
        "SELECT s.token_hash, s.expires_at, u.* FROM sessions s"
        " JOIN users u ON u.id = s.user_id WHERE s.token_hash = ?",
        (_token_hash(token),),
    ).fetchone()
    if row is None:
        return None
    if str(row["expires_at"]) <= db.utc_now():
        delete_session(token)
        return None
    return row


def delete_session(token: str) -> None:
    if not token:
        return
    conn = db.connection()
    conn.execute("DELETE FROM sessions WHERE token_hash = ?", (_token_hash(token),))
    conn.commit()


# --- Ticket WebSocket -----------------------------------------------------------


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _b64url_decode(text: str) -> bytes:
    padding = "=" * (-len(text) % 4)
    return base64.urlsafe_b64decode(text + padding)


def make_ticket(user, place_id: int, seconds: int = config.TICKET_SECONDS) -> str:
    payload = {
        "u": int(user["id"]),
        "p": int(place_id),
        "e": int(time.time()) + max(1, int(seconds)),
        "g": bool(user["is_guest"]),
        "n": str(user["display_name"])[:40],
    }
    raw = json.dumps(payload, separators=(",", ":"), sort_keys=True).encode("utf-8")
    body = _b64url(raw)
    signature = hmac.new(config.secret_key(), body.encode("ascii"), hashlib.sha256).digest()
    return "%s.%s" % (body, _b64url(signature))


def parse_ticket(ticket: str) -> dict:
    try:
        body, signature = str(ticket).split(".", 1)
        expected = hmac.new(
            config.secret_key(), body.encode("ascii"), hashlib.sha256
        ).digest()
        if not hmac.compare_digest(expected, _b64url_decode(signature)):
            raise TicketError("Firma del ticket non valida.")
        payload = json.loads(_b64url_decode(body).decode("utf-8"))
    except (ValueError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise TicketError("Ticket non valido.") from exc
    if not isinstance(payload, dict):
        raise TicketError("Ticket non valido.")
    try:
        user_id = int(payload["u"])
        place_id = int(payload["p"])
        expires = int(payload["e"])
        is_guest = bool(payload.get("g", False))
        name = str(payload.get("n", "Giocatore"))[:40]
    except (KeyError, TypeError, ValueError) as exc:
        raise TicketError("Ticket incompleto.") from exc
    if expires < int(time.time()):
        raise TicketError("Ticket scaduto.")
    return {
        "user_id": user_id,
        "place_id": place_id,
        "exp": expires,
        "is_guest": is_guest,
        "name": name,
    }
