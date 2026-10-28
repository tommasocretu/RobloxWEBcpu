"""HTTP: sito statico (WEBhtml) + API JSON + sessioni."""
from __future__ import annotations

import json
import mimetypes
import posixpath
import re
import sys
import threading
import time
from http.cookies import SimpleCookie
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlsplit

import auth
import config
import db
import places

MIME_TYPES = {
    ".html": "text/html; charset=utf-8",
    ".htm": "text/html; charset=utf-8",
    ".css": "text/css; charset=utf-8",
    ".js": "text/javascript; charset=utf-8",
    ".mjs": "text/javascript; charset=utf-8",
    ".json": "application/json; charset=utf-8",
    ".wasm": "application/wasm",
    ".pck": "application/octet-stream",
    ".data": "application/octet-stream",
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".webp": "image/webp",
    ".svg": "image/svg+xml",
    ".ico": "image/x-icon",
    ".woff": "font/woff",
    ".woff2": "font/woff2",
    ".ttf": "font/ttf",
    ".txt": "text/plain; charset=utf-8",
    ".map": "application/json; charset=utf-8",
}


class ApiError(Exception):
    def __init__(self, status: int, message: str):
        super().__init__(message)
        self.status = status
        self.message = message


class RateLimiter:
    """Limite semplice in memoria per IP (finestra scorrevole)."""

    def __init__(self, limit: int = config.RATE_LIMIT_MAX, window: float = config.RATE_LIMIT_WINDOW):
        self.limit = limit
        self.window = window
        self._lock = threading.Lock()
        self._hits: dict[str, list[float]] = {}

    def allow(self, key: str) -> bool:
        now = time.monotonic()
        cutoff = now - self.window
        with self._lock:
            values = [stamp for stamp in self._hits.get(key, []) if stamp > cutoff]
            if len(values) >= self.limit:
                self._hits[key] = values
                return False
            values.append(now)
            self._hits[key] = values
            if len(self._hits) > 4096:
                for old_key in [k for k, v in self._hits.items() if not v or v[-1] <= cutoff]:
                    self._hits.pop(old_key, None)
        return True


class Platform:
    def __init__(self, relay=None, web_root: str | Path | None = None, quiet: bool = False):
        self.relay = relay
        self.web_root = Path(web_root) if web_root is not None else Path(config.WEB_ROOT)
        self.quiet = quiet
        self.ws_port = int(getattr(relay, "port", config.WS_PORT) or config.WS_PORT)
        self.rate_limiter = RateLimiter()

    def live(self, place_id: int) -> int:
        if self.relay is None:
            return 0
        try:
            return int(self.relay.live_players(place_id))
        except Exception:
            return 0


class PlatformHTTPServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True

    def __init__(self, address, platform: Platform):
        self.platform = platform
        super().__init__(address, PlatformHandler)

    def handle_error(self, request, client_address) -> None:
        # Il browser chiude spesso connessioni keep-alive durante la navigazione:
        # non sporcare i log con traceback di reset/pipe rotte.
        exc = sys.exc_info()[1]
        if isinstance(exc, (ConnectionResetError, BrokenPipeError)):
            return
        super().handle_error(request, client_address)


class PlatformHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "RobloxWeb/0.1"
    sys_version = ""

    # --- entry points ------------------------------------------------------

    def do_GET(self) -> None:
        self._dispatch("GET")

    def do_HEAD(self) -> None:
        self._dispatch("HEAD")

    def do_POST(self) -> None:
        self._dispatch("POST")

    def do_PUT(self) -> None:
        self._dispatch("PUT")

    def do_DELETE(self) -> None:
        self._dispatch("DELETE")

    def log_message(self, fmt: str, *args) -> None:
        platform: Platform = self.server.platform
        if not platform.quiet:
            print("[http] %s - %s" % (self.address_string(), fmt % args))

    @property
    def platform(self) -> Platform:
        return self.server.platform

    # --- dispatch ----------------------------------------------------------

    def _dispatch(self, method: str) -> None:
        self._body_read = False
        try:
            if method in ("POST", "PUT", "DELETE"):
                self._check_origin()
            parsed = urlsplit(self.path)
            path = unquote(parsed.path)
            if path.startswith("/api/") or path == "/api":
                self._handle_api(method, path, parse_qs(parsed.query))
            elif path.startswith("/thumbs/"):
                if method not in ("GET", "HEAD"):
                    raise ApiError(405, "Metodo non consentito.")
                self._serve_thumbnail(path)
            elif method in ("GET", "HEAD"):
                self._serve_static(path)
            else:
                raise ApiError(405, "Metodo non consentito.")
        except ApiError as exc:
            self._drain_on_error()
            self._send_json(exc.status, {"error": exc.message})
        except BrokenPipeError:
            pass
        except Exception as exc:  # pragma: no cover - log di sicurezza
            print(f"[http] errore interno: {exc!r}")
            self._drain_on_error()
            self._send_json(500, {"error": "Errore interno del server."})

    def _drain_on_error(self) -> None:
        """Consuma un body non letto prima di rispondere a un errore.

        Senza questo, su una connessione keep-alive i byte del body verrebbero
        interpretati come inizio della richiesta successiva.
        """
        if getattr(self, "_body_read", False):
            return
        try:
            length = self._content_length()
        except ApiError:
            self.close_connection = True
            return
        if length <= 0:
            self._body_read = True
            return
        if length > config.MAX_LEVEL_BYTES:
            # Troppo grande per essere consumato in sicurezza: chiudi la connessione.
            self.close_connection = True
            return
        try:
            self.rfile.read(length)
        except OSError:
            self.close_connection = True
        self._body_read = True

    def _check_origin(self) -> None:
        origin = self.headers.get("Origin")
        host = self.headers.get("Host", "")
        if origin:
            if origin == "null":
                raise ApiError(403, "Origine non consentita.")
            parsed = urlsplit(origin)
            if parsed.netloc.lower() != host.lower():
                raise ApiError(403, "Origine non consentita.")
            return
        referer = self.headers.get("Referer")
        if referer:
            parsed = urlsplit(referer)
            if parsed.netloc.lower() != host.lower():
                raise ApiError(403, "Referer non consentito.")

    # --- API ---------------------------------------------------------------

    def _handle_api(self, method: str, path: str, query: dict) -> None:
        parts = [part for part in path.strip("/").split("/") if part]
        if not parts or parts[0] != "api":
            raise ApiError(404, "Endpoint non trovato.")
        route = parts[1:]
        session_token = self._session_token()
        user = auth.resolve_session(session_token) if session_token else None

        if route == ["health"] and method == "GET":
            self._send_json(200, {"ok": True, "ws_port": self.platform.ws_port})
            return

        if route == ["guest"] and method == "POST":
            self._limit("guest")
            self._discard_body()
            user = auth.create_guest()
            token = auth.create_session(int(user["id"]))
            self._send_json(
                200, {"user": auth.public_user(user)}, session_token=token
            )
            return

        if route == ["register"] and method == "POST":
            self._limit("register")
            body = self._read_json()
            try:
                user = auth.create_account(
                    str(body.get("username", "")), str(body.get("password", ""))
                )
            except auth.AuthError as exc:
                raise ApiError(400, str(exc))
            token = auth.create_session(int(user["id"]))
            self._send_json(201, {"user": auth.public_user(user)}, session_token=token)
            return

        if route == ["login"] and method == "POST":
            self._limit("login")
            body = self._read_json()
            user = auth.authenticate(
                str(body.get("username", "")), str(body.get("password", ""))
            )
            if user is None:
                raise ApiError(401, "Username o password non validi.")
            token = auth.create_session(int(user["id"]))
            self._send_json(200, {"user": auth.public_user(user)}, session_token=token)
            return

        if route == ["logout"] and method == "POST":
            self._discard_body()
            if session_token:
                auth.delete_session(session_token)
            self._send_json(200, {"ok": True}, clear_session=True)
            return

        if route == ["me"] and method == "GET":
            if user is None:
                raise ApiError(401, "Sessione mancante o scaduta.")
            self._send_json(200, {"user": auth.public_user(user)})
            return

        if route == ["token"] and method == "POST":
            self._limit("login")
            body = self._read_json()
            user = auth.authenticate(
                str(body.get("username", "")), str(body.get("password", ""))
            )
            if user is None:
                raise ApiError(401, "Username o password non validi.")
            token = auth.create_session(int(user["id"]))
            self._send_json(
                200,
                {
                    "token": token,
                    "user": auth.public_user(user),
                    "expires_in": config.SESSION_DAYS * 24 * 60 * 60,
                },
            )
            return

        if route == ["me", "places"] and method == "GET":
            if user is None:
                raise ApiError(401, "Sessione mancante o scaduta.")
            self._send_json(
                200,
                {
                    "places": places.list_owned(
                        int(user["id"]),
                        self.platform.live,
                        places.liked_ids(int(user["id"])),
                    )
                },
            )
            return

        if route == ["me", "likes"] and method == "GET":
            if user is None:
                raise ApiError(401, "Sessione mancante o scaduta.")
            self._send_json(
                200, {"places": places.list_liked(int(user["id"]), self.platform.live)}
            )
            return

        if len(route) == 2 and route[0] == "users" and method == "GET":
            author = auth.get_user_by_id(self._place_id(route[1]))
            if author is None or bool(author["is_guest"]):
                raise ApiError(404, "Utente non trovato.")
            liked = places.liked_ids(int(user["id"])) if user else set()
            public = auth.public_user(author)
            public.pop("is_guest", None)
            self._send_json(
                200,
                {
                    "user": public,
                    "stats": places.author_stats(int(author["id"])),
                    "places": places.list_by_author(
                        int(author["id"]), self.platform.live, liked
                    ),
                },
            )
            return

        if route == ["places"] and method == "GET":
            sort = str(query.get("sort", ["popular"])[0])
            q = str(query.get("q", [""])[0])[:80]
            liked = places.liked_ids(int(user["id"])) if user else set()
            items = places.list_places(
                sort, q, live_lookup=self.platform.live, liked_ids=liked
            )
            self._send_json(200, {"places": items, "total": len(items)})
            return

        if route == ["places"] and method == "POST":
            self._limit("publish")
            owner = self._require_user(user)
            if bool(owner["is_guest"]):
                raise ApiError(403, "Gli ospiti non possono pubblicare esperienze.")
            body = self._read_json(config.MAX_PUBLISH_BODY)
            try:
                data_text, level = places.prepare_level(
                    body.get("level", body.get("data"))
                )
                meta = level.get("meta") if isinstance(level.get("meta"), dict) else {}
                place_id = places.create_place(
                    int(owner["id"]),
                    places.clean_title(body.get("title") or meta.get("title", "")),
                    body.get("description", ""),
                    data_text,
                    body.get("visibility", "public"),
                )
            except places.PlaceError as exc:
                raise ApiError(400, str(exc))
            row = places.get_place(place_id)
            self._send_json(
                201,
                {
                    "place": places.public_place(
                        row, self.platform.live(place_id)
                    ),
                    "version": 1,
                },
            )
            return

        if len(route) == 2 and route[0] == "places" and method == "GET":
            place_id = self._place_id(route[1])
            row = places.get_place(place_id)
            if row is None:
                raise ApiError(404, "Esperienza non trovata.")
            if not places.can_view(row, int(user["id"]) if user else None):
                raise ApiError(403, "Esperienza privata.")
            liked = places.is_liked(place_id, int(user["id"])) if user else False
            detail = places.public_place(row, self.platform.live(place_id), liked)
            self._send_json(200, {"place": detail})
            return

        if len(route) == 3 and route[0] == "places" and route[2] == "like" and method == "POST":
            self._limit("like")
            account = self._require_account(
                user, "Gli ospiti non possono mettere like. Registrati per continuare."
            )
            self._discard_body()
            place_id = self._place_id(route[1])
            row = places.get_place(place_id)
            if row is None:
                raise ApiError(404, "Esperienza non trovata.")
            if not places.can_view(row, int(account["id"])):
                raise ApiError(403, "Esperienza privata.")
            liked, likes = places.toggle_like(place_id, int(account["id"]))
            self._send_json(200, {"liked": liked, "likes": likes})
            return

        if len(route) == 3 and route[0] == "places" and route[2] == "report" and method == "POST":
            self._limit("report")
            account = self._require_account(
                user, "Gli ospiti non possono segnalare contenuti. Registrati per continuare."
            )
            body = self._read_json()
            place_id = self._place_id(route[1])
            row = places.get_place(place_id)
            if row is None:
                raise ApiError(404, "Esperienza non trovata.")
            if not places.can_view(row, int(account["id"])):
                raise ApiError(403, "Esperienza privata.")
            if places.is_owner(row, int(account["id"])):
                raise ApiError(400, "Non puoi segnalare la tua esperienza.")
            try:
                places.add_report(
                    place_id,
                    int(account["id"]),
                    body.get("reason", ""),
                    body.get("details", ""),
                )
            except places.PlaceError as exc:
                raise ApiError(400, str(exc))
            self._send_json(201, {"ok": True})
            return

        if len(route) == 2 and route[0] == "places" and method == "PUT":
            owner = self._require_user(user, allow_guest=False)
            place_id = self._place_id(route[1])
            row = self._owned_place(place_id, owner)
            body = self._read_json()
            fields = {
                key: body[key]
                for key in ("title", "description", "visibility")
                if key in body
            }
            if not fields:
                raise ApiError(400, "Nessun campo da aggiornare.")
            places.update_place(place_id, fields)
            row = places.get_place(place_id)
            self._send_json(
                200,
                {"place": places.public_place(row, self.platform.live(place_id))},
            )
            return

        if len(route) == 2 and route[0] == "places" and method == "DELETE":
            owner = self._require_user(user, allow_guest=False)
            place_id = self._place_id(route[1])
            self._owned_place(place_id, owner)
            self._discard_body()
            conn = db.connection()
            conn.execute("DELETE FROM places WHERE id = ?", (place_id,))
            conn.commit()
            try:
                places.thumbnail_file(place_id).unlink()
            except OSError:
                pass
            self._send_json(200, {"ok": True})
            return

        if len(route) == 3 and route[0] == "places" and route[2] == "play" and method == "POST":
            self._discard_body()
            if user is None:
                raise ApiError(401, "Accedi per giocare.")
            place_id = self._place_id(route[1])
            row = places.get_place(place_id)
            if row is None:
                raise ApiError(404, "Esperienza non trovata.")
            if not places.can_view(row, int(user["id"])):
                raise ApiError(403, "Esperienza privata.")
            version = places.current_version(place_id)
            if version is None:
                raise ApiError(503, "L'esperienza non ha ancora una versione pubblicata.")
            try:
                level = places.level_from_version(version)
            except places.PlaceError as exc:
                raise ApiError(500, str(exc))
            places.increment_visits(place_id)
            ticket = auth.make_ticket(user, place_id)
            self._send_json(
                200,
                {
                    "place": places.public_place(
                        row, self.platform.live(place_id) + 1
                    ),
                    "player": {
                        "name": str(user["display_name"]),
                        "is_guest": bool(user["is_guest"]),
                    },
                    "level": level,
                    "ws_url": self._ws_url(),
                    "ticket": ticket,
                },
            )
            return

        if len(route) == 3 and route[0] == "places" and route[2] == "versions" and method == "POST":
            self._limit("publish")
            owner = self._require_user(user, allow_guest=False)
            place_id = self._place_id(route[1])
            self._owned_place(place_id, owner)
            body = self._read_json(config.MAX_PUBLISH_BODY)
            try:
                data_text, _level = places.prepare_level(
                    body.get("level", body.get("data"))
                )
                fields = {
                    key: body[key]
                    for key in ("title", "description", "visibility")
                    if key in body
                }
                version = places.publish_version(place_id, data_text, fields)
            except places.PlaceError as exc:
                raise ApiError(400, str(exc))
            row = places.get_place(place_id)
            self._send_json(
                200,
                {
                    "place": places.public_place(
                        row, self.platform.live(place_id)
                    ),
                    "version": version,
                },
            )
            return

        if len(route) == 3 and route[0] == "places" and route[2] == "versions" and method == "GET":
            owner = self._require_user(user, allow_guest=False)
            place_id = self._place_id(route[1])
            self._owned_place(place_id, owner)
            self._send_json(
                200,
                {
                    "place_id": place_id,
                    "versions": places.list_versions(place_id),
                },
            )
            return

        if (
            len(route) == 5
            and route[0] == "places"
            and route[2] == "versions"
            and route[4] == "rollback"
            and method == "POST"
        ):
            self._limit("rollback")
            owner = self._require_user(user, allow_guest=False)
            place_id = self._place_id(route[1])
            self._owned_place(place_id, owner)
            self._discard_body()
            source_version = self._place_id(route[3])
            if places.get_version(place_id, source_version) is None:
                raise ApiError(404, "Versione non trovata.")
            try:
                version = places.rollback_version(place_id, source_version)
            except places.PlaceError as exc:
                raise ApiError(400, str(exc))
            row = places.get_place(place_id)
            self._send_json(
                200,
                {
                    "place": places.public_place(
                        row, self.platform.live(place_id),
                        places.is_liked(place_id, int(owner["id"])),
                    ),
                    "version": version,
                    "restored_from": source_version,
                },
            )
            return

        if (
            len(route) == 4
            and route[0] == "places"
            and route[2] == "versions"
            and method == "GET"
        ):
            owner = self._require_user(user, allow_guest=False)
            place_id = self._place_id(route[1])
            self._owned_place(place_id, owner)
            version = places.get_version(place_id, self._place_id(route[3]))
            if version is None:
                raise ApiError(404, "Versione non trovata.")
            try:
                level = places.level_from_version(version)
            except places.PlaceError as exc:
                raise ApiError(500, str(exc))
            self._send_json(
                200,
                {
                    "place_id": place_id,
                    "version": int(version["version"]),
                    "created_at": str(version["created_at"]),
                    "level": level,
                },
            )
            return

        if len(route) == 3 and route[0] == "places" and route[2] == "data" and method == "GET":
            owner = self._require_user(user, allow_guest=False)
            place_id = self._place_id(route[1])
            self._owned_place(place_id, owner)
            version = places.current_version(place_id)
            if version is None:
                raise ApiError(404, "L'esperienza non ha ancora una versione pubblicata.")
            try:
                level = places.level_from_version(version)
            except places.PlaceError as exc:
                raise ApiError(500, str(exc))
            row = places.get_place(place_id)
            self._send_json(
                200,
                {
                    "place": places.public_place(
                        row, self.platform.live(place_id)
                    ),
                    "version": int(version["version"]),
                    "level": level,
                },
            )
            return

        if len(route) == 3 and route[0] == "places" and route[2] == "thumbnail" and method == "POST":
            owner = self._require_user(user, allow_guest=False)
            place_id = self._place_id(route[1])
            self._owned_place(place_id, owner)
            data = self._read_raw(config.MAX_THUMBNAIL_BYTES)
            try:
                version = places.set_thumbnail(place_id, data)
            except places.PlaceError as exc:
                raise ApiError(400, str(exc))
            row = places.get_place(place_id)
            self._send_json(
                200,
                {
                    "ok": True,
                    "version": version,
                    "place": places.public_place(
                        row, self.platform.live(place_id)
                    ),
                },
            )
            return

        raise ApiError(404, "Endpoint non trovato.")

    def _require_user(self, user, allow_guest: bool = True):
        if user is None:
            raise ApiError(401, "Sessione mancante o scaduta.")
        if not allow_guest and bool(user["is_guest"]):
            raise ApiError(403, "Gli ospiti non possono modificare esperienze.")
        return user

    def _require_account(self, user, message: str):
        if user is None:
            raise ApiError(401, "Accedi o registrati per continuare.")
        if bool(user["is_guest"]):
            raise ApiError(403, message)
        return user

    def _owned_place(self, place_id: int, user):
        row = places.get_place(place_id)
        if row is None:
            raise ApiError(404, "Esperienza non trovata.")
        if not places.is_owner(row, int(user["id"])):
            raise ApiError(403, "Non sei l'autore di questa esperienza.")
        return row

    def _limit(self, scope: str) -> None:
        key = f"{self.client_address[0]}:{scope}"
        if not self.platform.rate_limiter.allow(key):
            raise ApiError(429, "Troppi tentativi. Riprova tra poco.")

    def _place_id(self, value: str) -> int:
        try:
            return int(value)
        except (TypeError, ValueError):
            raise ApiError(404, "Esperienza non trovata.")

    def _ws_url(self) -> str:
        if config.WS_PUBLIC_URL:
            return config.WS_PUBLIC_URL
        host_header = self.headers.get("Host", "")
        hostname = urlsplit("//" + host_header).hostname or "127.0.0.1"
        scheme = "wss" if self._is_https() else "ws"
        return f"{scheme}://{hostname}:{self.platform.ws_port}"

    def _is_https(self) -> bool:
        if isinstance(self.connection, object) and getattr(self.connection, "cipher", None):
            return True
        return self.headers.get("X-Forwarded-Proto", "").lower() == "https"

    # --- body / risposte ---------------------------------------------------

    def _content_length(self) -> int:
        try:
            length = int(self.headers.get("Content-Length", "0") or "0")
        except ValueError:
            raise ApiError(400, "Content-Length non valido.")
        if length < 0:
            raise ApiError(400, "Content-Length non valido.")
        return length

    def _discard_body(self) -> None:
        length = self._content_length()
        if length > config.MAX_JSON_BODY:
            raise ApiError(413, "Corpo della richiesta troppo grande.")
        if length:
            self.rfile.read(length)
        self._body_read = True

    def _read_json(self, limit: int | None = None) -> dict:
        limit = config.MAX_JSON_BODY if limit is None else int(limit)
        length = self._content_length()
        if length > limit:
            raise ApiError(413, "Corpo della richiesta troppo grande.")
        raw = self.rfile.read(length) if length else b""
        self._body_read = True
        if not raw:
            return {}
        try:
            value = json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            raise ApiError(400, "JSON non valido.")
        if not isinstance(value, dict):
            raise ApiError(400, "Il corpo deve essere un oggetto JSON.")
        return value

    def _read_raw(self, limit: int) -> bytes:
        length = self._content_length()
        if length <= 0:
            raise ApiError(400, "Corpo della richiesta mancante.")
        if length > limit:
            raise ApiError(413, "File troppo grande.")
        self._body_read = True
        return self.rfile.read(length)

    def _cookie(self, name: str) -> str:
        raw = self.headers.get("Cookie", "")
        if not raw:
            return ""
        try:
            jar = SimpleCookie()
            jar.load(raw)
            morsel = jar.get(name)
            return morsel.value if morsel else ""
        except Exception:
            return ""

    def _session_token(self) -> str:
        """Cookie del browser oppure Bearer (Studio e client nativi, senza CSRF)."""
        authorization = self.headers.get("Authorization", "").strip()
        if authorization.lower().startswith("bearer "):
            return authorization[7:].strip()
        return self._cookie("rw_session")

    def _session_cookie(self, token: str, clear: bool = False) -> str:
        if clear:
            value = "rw_session=; Path=/; Max-Age=0; HttpOnly; SameSite=Lax"
        else:
            max_age = config.SESSION_DAYS * 24 * 60 * 60
            value = (
                f"rw_session={token}; Path=/; Max-Age={max_age};"
                " HttpOnly; SameSite=Lax"
            )
        if self._is_https():
            value += "; Secure"
        return value

    def _send_json(
        self,
        status: int,
        payload: dict,
        *,
        session_token: str | None = None,
        clear_session: bool = False,
    ) -> None:
        body = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        headers = {"Cache-Control": "no-store"}
        if session_token is not None:
            headers["Set-Cookie"] = self._session_cookie(session_token)
        if clear_session:
            headers["Set-Cookie"] = self._session_cookie("", clear=True)
        self._send_bytes(status, "application/json; charset=utf-8", body, headers)

    def _redirect(self, location: str) -> None:
        self.send_response(301)
        self.send_header("Location", location)
        self.send_header("Content-Length", "0")
        self.send_header("Cache-Control", "no-store")
        self.end_headers()

    def _send_bytes(
        self, status: int, content_type: str, body: bytes, extra_headers: dict | None = None
    ) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("X-Content-Type-Options", "nosniff")
        if extra_headers:
            for key, value in extra_headers.items():
                self.send_header(key, value)
        self.end_headers()
        if self.command != "HEAD":
            try:
                self.wfile.write(body)
            except BrokenPipeError:
                pass

    # --- thumbnail ---------------------------------------------------------

    def _serve_thumbnail(self, path: str) -> None:
        name = posixpath.basename(path)
        if not re.fullmatch(r"\d+\.png", name):
            raise ApiError(404, "Thumbnail non trovata.")
        candidate = config.thumbs_dir() / name
        try:
            body = candidate.read_bytes()
        except OSError:
            raise ApiError(404, "Thumbnail non trovata.")
        self._send_bytes(200, "image/png", body, {"Cache-Control": "no-store"})

    # --- file statici ------------------------------------------------------

    def _serve_static(self, path: str) -> None:
        if "\x00" in path:
            raise ApiError(404, "File non trovato.")
        normalized = posixpath.normpath("/" + path.lstrip("/"))
        if normalized in ("/", "/."):
            normalized = "/index.html"
        if normalized.startswith("/../") or normalized == "/..":
            raise ApiError(404, "File non trovato.")
        root = self.platform.web_root.resolve()
        candidate = (root / normalized.lstrip("/")).resolve()
        try:
            candidate.relative_to(root)
        except ValueError:
            raise ApiError(404, "File non trovato.")
        if candidate.is_dir():
            if not path.endswith("/"):
                self._redirect(path + "/")
                return
            candidate = candidate / "index.html"
        if not candidate.is_file():
            self._send_bytes(
                404,
                "text/html; charset=utf-8",
                b"<html><body><h1>404</h1><p>File non trovato.</p></body></html>",
                {"Cache-Control": "no-store"},
            )
            return
        try:
            body = candidate.read_bytes()
        except OSError:
            raise ApiError(404, "File non trovato.")
        suffix = candidate.suffix.lower()
        content_type = MIME_TYPES.get(suffix) or mimetypes.guess_type(str(candidate))[0]
        if not content_type:
            content_type = "application/octet-stream"
        if content_type.startswith("text/") or content_type in (
            "application/json",
            "image/svg+xml",
        ):
            if "charset=" not in content_type:
                content_type += "; charset=utf-8"
        self._send_bytes(
            200,
            content_type,
            body,
            {"Cache-Control": "no-store"},
        )


def create_server(
    host: str,
    port: int,
    relay=None,
    web_root: str | Path | None = None,
    quiet: bool = False,
) -> PlatformHTTPServer:
    platform = Platform(relay=relay, web_root=web_root, quiet=quiet)
    server = PlatformHTTPServer((host, port), platform)
    return server
