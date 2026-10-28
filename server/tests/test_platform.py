"""Test M0–M4: HTTP API, sessioni, place, like, versioni, ticket e relay per stanze."""
from __future__ import annotations

import base64
import hashlib
import hmac
import http.client
import json
import select
import socket
import struct
import sys
import tempfile
import threading
import time
import unittest
import zlib
from http.cookies import SimpleCookie
from pathlib import Path
from urllib.parse import urlsplit

SERVER_DIR = Path(__file__).resolve().parents[1]
if str(SERVER_DIR) not in sys.path:
    sys.path.insert(0, str(SERVER_DIR))

import app  # noqa: E402
import auth  # noqa: E402
import config  # noqa: E402
import db  # noqa: E402
import logs  # noqa: E402
import places  # noqa: E402
from relay import RelayServer  # noqa: E402
from wsproto import FrameReader, OP_CLOSE, OP_PING, OP_PONG, OP_TEXT, client_handshake, send_frame, send_text  # noqa: E402


class HttpClient:
    def __init__(self, base_url: str):
        self.base_url = base_url.rstrip("/")
        self.cookies: dict[str, str] = {}
        self.last_headers: dict[str, str] = {}

    def request(
        self,
        method: str,
        path: str,
        body=None,
        headers: dict | None = None,
        raw: bytes | None = None,
        content_type: str | None = None,
    ):
        parsed = urlsplit(self.base_url)
        conn = http.client.HTTPConnection(parsed.hostname, parsed.port, timeout=10)
        request_headers = dict(headers or {})
        request_headers["Connection"] = "close"
        if method not in ("GET", "HEAD"):
            request_headers.setdefault("Origin", self.base_url)
        if self.cookies:
            request_headers["Cookie"] = "; ".join(
                f"{key}={value}" for key, value in self.cookies.items()
            )
        payload = raw
        if body is not None:
            payload = json.dumps(body).encode("utf-8")
            request_headers.setdefault("Content-Type", "application/json")
        if content_type:
            request_headers["Content-Type"] = content_type
        conn.request(method, path, body=payload, headers=request_headers)
        response = conn.getresponse()
        raw = response.read()
        self.last_headers = {key.lower(): value for key, value in response.getheaders()}
        set_cookie = response.getheader("Set-Cookie")
        if set_cookie:
            jar = SimpleCookie()
            jar.load(set_cookie)
            for key, morsel in jar.items():
                if morsel["max-age"] == "0":
                    self.cookies.pop(key, None)
                else:
                    self.cookies[key] = morsel.value
        status = response.status
        content_type = response.getheader("Content-Type") or ""
        conn.close()
        parsed_body = None
        if raw:
            try:
                parsed_body = json.loads(raw.decode("utf-8"))
            except (UnicodeDecodeError, json.JSONDecodeError):
                parsed_body = raw
        return status, content_type, parsed_body

    def get(self, path: str, headers: dict | None = None):
        return self.request("GET", path, headers=headers)

    def post(self, path: str, body=None, headers: dict | None = None):
        return self.request("POST", path, body=body, headers=headers)

    def put(self, path: str, body=None, headers: dict | None = None):
        return self.request("PUT", path, body=body, headers=headers)

    def delete(self, path: str, headers: dict | None = None):
        return self.request("DELETE", path, headers=headers)


def make_png(width: int = 64, height: int = 36) -> bytes:
    """PNG RGB valido (senza dipendenze esterne) per i test delle thumbnail."""
    raw = b"".join(b"\x00" + b"\x20\x60\x40" * width for _ in range(height))

    def chunk(kind: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + kind
            + data
            + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
        )

    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(raw, 6))
        + chunk(b"IEND", b"")
    )


def _ticket_payload(payload: dict) -> str:
    raw = json.dumps(payload, separators=(",", ":"), sort_keys=True).encode("utf-8")
    body = base64.urlsafe_b64encode(raw).rstrip(b"=").decode("ascii")
    signature = hmac.new(
        config.secret_key(), body.encode("ascii"), hashlib.sha256
    ).digest()
    sig = base64.urlsafe_b64encode(signature).rstrip(b"=").decode("ascii")
    return f"{body}.{sig}"


class WsPeer:
    def __init__(self, port: int, ticket: str):
        self.sock = socket.create_connection(("127.0.0.1", port), timeout=10)
        rest = client_handshake(self.sock, "127.0.0.1", port, "/")
        self.reader = FrameReader(self.sock, rest)
        self.sock.settimeout(2.0)
        self.send({"type": "hello", "ticket": ticket})

    def send(self, message: dict) -> None:
        send_text(self.sock, json.dumps(message), mask=True)

    def next_message(self, timeout: float = 2.0):
        ready, _, _ = select.select([self.sock], [], [], timeout)
        if not ready:
            return None
        fin, opcode, payload = self.reader.read_frame()
        if opcode == OP_PING:
            send_frame(self.sock, OP_PONG, payload, mask=True)
            return self.next_message(timeout)
        if opcode == OP_CLOSE:
            return None
        if opcode != OP_TEXT:
            return self.next_message(timeout)
        return json.loads(payload.decode("utf-8"))

    def wait_for(self, kind: str, timeout: float = 3.0):
        deadline = time.time() + timeout
        while time.time() < deadline:
            message = self.next_message(max(0.05, deadline - time.time()))
            if message is None:
                continue
            if message.get("type") == kind:
                return message
        return None

    def close(self) -> None:
        try:
            send_frame(self.sock, OP_CLOSE, b"", mask=True)
        except OSError:
            pass
        self.sock.close()


class PlatformTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.tmp = tempfile.TemporaryDirectory()
        base = Path(cls.tmp.name)
        web = base / "web"
        (web / "dev").mkdir(parents=True)
        (web / "index.html").write_text("<h1>RobloxWeb test</h1>", encoding="utf-8")
        (web / "dev" / "index.html").write_text("<h1>Client test</h1>", encoding="utf-8")
        (web / "dev" / "test.wasm").write_bytes(b"\x00asm\x01\x00\x00\x00")
        (web / "assets").mkdir()
        (web / "assets" / "site.css").write_text("body{}", encoding="utf-8")

        config.configure(
            data_dir=base / "data",
            web_root=web,
            http_port=0,
            ws_port=0,
            # La suite M0–M4 non testa i rate limit: alza la soglia per non
            # interferire con decine di richieste dallo stesso IP.
            rate_limits={"default": (10000, 60.0)},
        )
        config.ensure_data_dir()
        logs.setup(quiet=True)
        db.configure(config.db_path())
        db.init()
        places.seed_demo()

        cls.relay = RelayServer("127.0.0.1", 0)
        cls.relay.start()
        cls.httpd = app.create_server(
            "127.0.0.1", 0, relay=cls.relay, web_root=web, quiet=True
        )
        cls.http_thread = threading.Thread(target=cls.httpd.serve_forever, daemon=True)
        cls.http_thread.start()
        cls.base_url = f"http://127.0.0.1:{cls.httpd.server_address[1]}"
        cls.seed_place_id = int(
            db.connection()
            .execute("SELECT id FROM places WHERE title = 'Welcome Obby'")
            .fetchone()["id"]
        )

    @classmethod
    def tearDownClass(cls) -> None:
        cls.httpd.shutdown()
        cls.httpd.server_close()
        cls.relay.stop()
        db.close()
        logs.reset()
        cls.tmp.cleanup()

    def client(self) -> HttpClient:
        return HttpClient(self.base_url)

    # --- statici -----------------------------------------------------------

    def test_home_and_mime_wasm(self):
        status, content_type, body = self.client().get("/")
        self.assertEqual(status, 200)
        self.assertIn("text/html", content_type)
        self.assertIn(b"RobloxWeb", body)

        status, content_type, _ = self.client().get("/dev/test.wasm")
        self.assertEqual(status, 200)
        self.assertEqual(content_type, "application/wasm")

        status, content_type, _ = self.client().get("/assets/site.css")
        self.assertEqual(status, 200)
        self.assertIn("text/css", content_type)

        status, _, _ = self.client().get("/dev")
        self.assertEqual(status, 301)
        status, content_type, body = self.client().get("/dev/")
        self.assertEqual(status, 200)
        self.assertIn("text/html", content_type)
        self.assertIn(b"Client test", body)

    def test_static_404_and_traversal(self):
        status, _, _ = self.client().get("/non-esiste.html")
        self.assertEqual(status, 404)
        for path in ("/../server/app.py", "/%2e%2e/server/app.py", "/..%2fserver/app.py"):
            status, _, _ = self.client().get(path)
            self.assertEqual(status, 404, path)

    # --- account -----------------------------------------------------------

    def test_register_login_logout(self):
        client = self.client()
        status, _, payload = client.post(
            "/api/register", {"username": "alice", "password": "segreta1"}
        )
        self.assertEqual(status, 201)
        self.assertEqual(payload["user"]["name"], "alice")
        self.assertFalse(payload["user"]["is_guest"])

        status, _, payload = client.get("/api/me")
        self.assertEqual(status, 200)
        self.assertTrue(payload["user"]["username"] == "alice")

        status, _, _ = client.post("/api/logout")
        self.assertEqual(status, 200)
        status, _, _ = client.get("/api/me")
        self.assertEqual(status, 401)

        status, _, _ = client.request(
            "POST", "/api/login", body={"username": "alice", "password": "sbagliata"}
        )
        self.assertEqual(status, 401)
        status, _, payload = client.request(
            "POST", "/api/login", body={"username": "alice", "password": "segreta1"}
        )
        self.assertEqual(status, 200)
        self.assertEqual(payload["user"]["username"], "alice")

    def test_duplicate_username_and_guest(self):
        client = self.client()
        status, _, _ = client.post(
            "/api/register", {"username": "carol", "password": "segreta3"}
        )
        self.assertEqual(status, 201)
        status, _, _ = client.post(
            "/api/register", {"username": "carol", "password": "segreta3"}
        )
        self.assertEqual(status, 400)

        guest = self.client()
        status, _, payload = guest.post("/api/guest")
        self.assertEqual(status, 200)
        self.assertTrue(payload["user"]["is_guest"])
        self.assertTrue(payload["user"]["name"].startswith("Ospite"))
        status, _, _ = guest.get("/api/me")
        self.assertEqual(status, 200)

    def test_expired_session(self):
        client = self.client()
        status, _, payload = client.post(
            "/api/register", {"username": "dave", "password": "segreta4"}
        )
        self.assertEqual(status, 201)
        user_id = payload["user"]["id"]
        db.connection().execute(
            "UPDATE sessions SET expires_at = ? WHERE user_id = ?",
            ("2000-01-01T00:00:00+00:00", int(user_id)),
        )
        db.connection().commit()
        status, _, _ = client.get("/api/me")
        self.assertEqual(status, 401)
        rows = db.connection().execute(
            "SELECT COUNT(*) AS n FROM sessions WHERE user_id = ?", (int(user_id),)
        ).fetchone()
        self.assertEqual(int(rows["n"]), 0)

    def test_origin_check(self):
        client = self.client()
        status, _, payload = client.post(
            "/api/guest", headers={"Origin": "http://evil.example"}
        )
        self.assertEqual(status, 403)
        self.assertIn("error", payload)

        status, _, _ = client.post(
            "/api/guest", headers={"Origin": self.base_url}
        )
        self.assertEqual(status, 200)

    def test_keep_alive_drains_body_on_error(self):
        """Un body non letto non deve corrompere la richiesta successiva (keep-alive)."""
        parsed = urlsplit(self.base_url)
        conn = http.client.HTTPConnection(parsed.hostname, parsed.port, timeout=10)
        payload = json.dumps({"padding": "x" * 200}).encode("utf-8")
        conn.request(
            "POST",
            "/api/places",
            body=payload,
            headers={"Content-Type": "application/json"},
        )
        first = conn.getresponse()
        first.read()
        self.assertEqual(first.status, 401)

        conn.request("GET", "/api/health")
        second = conn.getresponse()
        body = second.read()
        conn.close()
        self.assertEqual(second.status, 200)
        self.assertTrue(json.loads(body.decode("utf-8"))["ok"])

    def test_invalid_json_and_large_body(self):
        client = self.client()
        status, _, _ = client.post("/api/login", body=["non", "oggetto"])
        self.assertEqual(status, 400)

        status, _, _ = client.request(
            "POST",
            "/api/guest",
            body={"padding": "x" * (config.MAX_JSON_BODY + 100)},
        )
        self.assertEqual(status, 413)

    # --- places ------------------------------------------------------------

    def test_places_list_detail_and_404(self):
        status, _, payload = self.client().get("/api/places")
        self.assertEqual(status, 200)
        titles = [item["title"] for item in payload["places"]]
        self.assertIn("Welcome Obby", titles)
        place = next(item for item in payload["places"] if item["title"] == "Welcome Obby")
        self.assertEqual(place["author"], "RobloxWeb")
        self.assertEqual(place["live_players"], 0)
        self.assertEqual(place["likes"], 0)
        self.assertFalse(place["liked"])

        status, _, payload = self.client().get(f"/api/places/{self.seed_place_id}")
        self.assertEqual(status, 200)
        self.assertEqual(payload["place"]["id"], self.seed_place_id)
        self.assertFalse(payload["place"]["liked"])

        status, _, _ = self.client().get("/api/places/999999")
        self.assertEqual(status, 404)

    def test_play_requires_session_and_is_guest_friendly(self):
        client = self.client()
        status, _, _ = client.post(f"/api/places/{self.seed_place_id}/play")
        self.assertEqual(status, 401)

        client.post("/api/guest")
        status, _, payload = client.post(f"/api/places/{self.seed_place_id}/play")
        self.assertEqual(status, 200)
        self.assertEqual(payload["level"]["format"], "robloxweb-level")
        self.assertEqual(payload["place"]["title"], "Welcome Obby")
        self.assertTrue(payload["player"]["is_guest"])
        self.assertEqual(payload["ws_url"], f"ws://127.0.0.1:{self.relay.port}")
        self.assertGreaterEqual(len(payload["ticket"]), 20)

        before = db.connection().execute(
            "SELECT visits FROM places WHERE id = ?", (self.seed_place_id,)
        ).fetchone()["visits"]
        client.post(f"/api/places/{self.seed_place_id}/play")
        after = db.connection().execute(
            "SELECT visits FROM places WHERE id = ?", (self.seed_place_id,)
        ).fetchone()["visits"]
        self.assertEqual(after, before + 1)

    def test_private_place_forbidden(self):
        author = auth.get_user_by_username("RobloxWeb")
        text = Path(config.DEFAULT_LEVEL_PATH).read_text(encoding="utf-8")
        private_id = places.create_place(
            int(author["id"]), "Privata", "", text, visibility="private"
        )
        client = self.client()
        client.post("/api/guest")
        status, _, _ = client.get(f"/api/places/{private_id}")
        self.assertEqual(status, 403)
        status, _, _ = client.post(f"/api/places/{private_id}/play")
        self.assertEqual(status, 403)

    def test_me_places(self):
        client = self.client()
        client.post("/api/register", {"username": "bob", "password": "segreta2"})
        status, _, payload = client.get("/api/me/places")
        self.assertEqual(status, 200)
        self.assertEqual(payload["places"], [])

    # --- pubblicazione (M1) ------------------------------------------------

    def _register_user(self, username: str):
        client = self.client()
        status, _, payload = client.post(
            "/api/register", {"username": username, "password": "segreta1"}
        )
        self.assertEqual(status, 201, payload)
        return client, payload["user"]

    def _level(self, title: str) -> dict:
        data = json.loads(Path(config.DEFAULT_LEVEL_PATH).read_text(encoding="utf-8"))
        data["meta"] = {"title": title, "author": "", "description": ""}
        return data

    def test_bearer_token_login(self):
        client = self.client()
        status, _, payload = client.post(
            "/api/token", {"username": "demo", "password": "demo1234"}
        )
        self.assertEqual(status, 200)
        token = payload["token"]
        self.assertGreater(len(token), 20)
        self.assertNotIn("rw_session", client.cookies)

        status, _, payload = client.get(
            "/api/me", headers={"Authorization": f"Bearer {token}"}
        )
        self.assertEqual(status, 200)
        self.assertEqual(payload["user"]["username"], "demo")

        status, _, _ = client.post(
            "/api/token", {"username": "demo", "password": "sbagliata"}
        )
        self.assertEqual(status, 401)

        status, _, _ = client.post(
            "/api/logout", headers={"Authorization": f"Bearer {token}"}
        )
        self.assertEqual(status, 200)
        status, _, _ = client.get(
            "/api/me", headers={"Authorization": f"Bearer {token}"}
        )
        self.assertEqual(status, 401)

    def test_publish_flow_ownership_and_versions(self):
        author, author_user = self._register_user("autore_a")
        level = self._level("Livello di A")

        guest = self.client()
        self.assertEqual(guest.post("/api/guest")[0], 200)
        status, _, _ = guest.post("/api/places", {"title": "Guest", "level": level})
        self.assertEqual(status, 403)

        status, _, payload = author.post(
            "/api/places",
            {
                "title": "Livello di A",
                "description": "La prima esperienza di A.",
                "visibility": "public",
                "level": level,
            },
        )
        self.assertEqual(status, 201, payload)
        place = payload["place"]
        place_id = place["id"]
        self.assertEqual(place["current_version"], 1)
        self.assertEqual(place["author"], "autore_a")
        self.assertIsNone(place["thumbnail_url"])

        _, _, catalog = self.client().get("/api/places?sort=recent")
        self.assertIn(place_id, [item["id"] for item in catalog["places"]])
        _, _, mine = author.get("/api/me/places")
        self.assertIn(place_id, [item["id"] for item in mine["places"]])

        reader, reader_user = self._register_user("autore_b")
        status, _, detail = reader.get(f"/api/places/{place_id}")
        self.assertEqual(status, 200)
        self.assertEqual(detail["place"]["owner_id"], author_user["id"])

        status, _, play = reader.post(f"/api/places/{place_id}/play")
        self.assertEqual(status, 200)
        self.assertEqual(play["level"]["meta"]["title"], "Livello di A")
        self.assertEqual(play["player"]["name"], "autore_b")

        # B non può modificare, pubblicare, caricare thumbnail o cancellare.
        status, _, _ = reader.put(f"/api/places/{place_id}", {"title": "Rubata"})
        self.assertEqual(status, 403)
        status, _, _ = reader.post(
            f"/api/places/{place_id}/versions", {"level": level}
        )
        self.assertEqual(status, 403)
        status, _, _ = reader.request(
            "POST",
            f"/api/places/{place_id}/thumbnail",
            raw=make_png(),
            content_type="image/png",
        )
        self.assertEqual(status, 403)
        for path in (
            f"/api/places/{place_id}/data",
            f"/api/places/{place_id}/versions",
        ):
            status, _, _ = reader.get(path)
            self.assertEqual(status, 403, path)
        status, _, _ = reader.delete(f"/api/places/{place_id}")
        self.assertEqual(status, 403)

        # A pubblica la versione 2 e aggiorna i metadati nella stessa chiamata.
        level_two = self._level("Livello di A v2")
        status, _, published = author.post(
            f"/api/places/{place_id}/versions",
            {
                "level": level_two,
                "title": "A v2",
                "description": "Seconda versione.",
                "visibility": "unlisted",
            },
        )
        self.assertEqual(status, 200, published)
        self.assertEqual(published["version"], 2)
        self.assertEqual(published["place"]["title"], "A v2")
        self.assertEqual(published["place"]["visibility"], "unlisted")

        status, _, play = reader.post(f"/api/places/{place_id}/play")
        self.assertEqual(status, 200)
        self.assertEqual(play["level"]["meta"]["title"], "Livello di A v2")

        # Unlisted: raggiungibile per id ma assente dal catalogo.
        _, _, catalog = self.client().get("/api/places?sort=recent")
        self.assertNotIn(place_id, [item["id"] for item in catalog["places"]])
        status, _, _ = reader.get(f"/api/places/{place_id}")
        self.assertEqual(status, 200)

        # Private: solo l'autore.
        status, _, _ = author.put(
            f"/api/places/{place_id}", {"visibility": "private"}
        )
        self.assertEqual(status, 200)
        self.assertEqual(reader.get(f"/api/places/{place_id}")[0], 403)
        self.assertEqual(reader.post(f"/api/places/{place_id}/play")[0], 403)
        self.assertEqual(author.get(f"/api/places/{place_id}")[0], 200)
        self.assertEqual(author.post(f"/api/places/{place_id}/play")[0], 200)

        # Storico e download della versione corrente.
        status, _, versions = author.get(f"/api/places/{place_id}/versions")
        self.assertEqual(status, 200)
        self.assertEqual([item["version"] for item in versions["versions"]], [2, 1])
        status, _, old = author.get(f"/api/places/{place_id}/versions/1")
        self.assertEqual(status, 200)
        self.assertEqual(old["level"]["meta"]["title"], "Livello di A")
        status, _, current = author.get(f"/api/places/{place_id}/data")
        self.assertEqual(status, 200)
        self.assertEqual(current["version"], 2)
        self.assertEqual(current["level"]["meta"]["title"], "Livello di A v2")

    def test_thumbnail_upload_and_serving(self):
        author, _ = self._register_user("autore_thumb")
        level = self._level("Con thumbnail")
        status, _, payload = author.post(
            "/api/places", {"title": "Con thumbnail", "level": level}
        )
        self.assertEqual(status, 201)
        place_id = payload["place"]["id"]
        png = make_png(64, 36)

        status, _, uploaded = author.request(
            "POST",
            f"/api/places/{place_id}/thumbnail",
            raw=png,
            content_type="image/png",
        )
        self.assertEqual(status, 200, uploaded)
        url = uploaded["place"]["thumbnail_url"]
        self.assertEqual(url, f"/thumbs/{place_id}.png?v=1")

        status, content_type, body = self.client().get(f"/thumbs/{place_id}.png?v=1")
        self.assertEqual(status, 200)
        self.assertEqual(content_type, "image/png")
        self.assertEqual(body, png)

        status, _, detail = self.client().get(f"/api/places/{place_id}")
        self.assertEqual(detail["place"]["thumbnail_url"], url)

        # Una nuova versione eredita la thumbnail finché non ne arriva una nuova.
        status, _, published = author.post(
            f"/api/places/{place_id}/versions", {"level": level}
        )
        self.assertEqual(status, 200)
        self.assertEqual(
            published["place"]["thumbnail_url"], f"/thumbs/{place_id}.png?v=2"
        )

        status, _, _ = author.request(
            "POST",
            f"/api/places/{place_id}/thumbnail",
            raw=b"non un png",
            content_type="image/png",
        )
        self.assertEqual(status, 400)

        status, _, _ = author.request(
            "POST",
            f"/api/places/{place_id}/thumbnail",
            raw=b"\x00" * (config.MAX_THUMBNAIL_BYTES + 1),
            content_type="image/png",
        )
        self.assertEqual(status, 413)

        for path in ("/thumbs/../app.py", "/thumbs/1.txt", "/thumbs/999999.png"):
            status, _, _ = self.client().get(path)
            self.assertEqual(status, 404, path)

    def test_publish_validation(self):
        status, _, _ = self.client().post(
            "/api/places", {"title": "Anonima", "level": self._level("X")}
        )
        self.assertEqual(status, 401)

        author, _ = self._register_user("autore_val")
        level = self._level("Valida")
        status, _, _ = author.post("/api/places", {"title": "Manca il livello"})
        self.assertEqual(status, 400)
        broken = self._level("Rotta")
        broken["format"] = "altro"
        status, _, _ = author.post("/api/places", {"title": "Rotta", "level": broken})
        self.assertEqual(status, 400)

        # Script M3: v2 accettata, campi validati lato server.
        scripted = self._level("Con script")
        scripted["version"] = 2
        scripted["scripts"] = [{
            "id": "s1",
            "name": "Porta",
            "parent_id": scripted["parts"][0]["id"],
            "enabled": True,
            "source": "print('ciao')",
        }]
        status, _, payload = author.post(
            "/api/places", {"title": "Con script", "level": scripted}
        )
        self.assertEqual(status, 201, payload)
        status, _, payload = author.post(
            "/api/places",
            {"title": "Parent errato", "level": dict(
                scripted, scripts=[dict(scripted["scripts"][0], parent_id="p999")]
            )},
        )
        self.assertEqual(status, 400)
        status, _, _ = author.post(
            "/api/places",
            {"title": "Id duplicato", "level": dict(
                scripted, scripts=[scripted["scripts"][0], scripted["scripts"][0]]
            )},
        )
        self.assertEqual(status, 400)
        status, _, _ = author.post(
            "/api/places",
            {"title": "V1 con script", "level": dict(scripted, version=1)},
        )
        self.assertEqual(status, 400)

        big = dict(level)
        big["padding"] = "x" * (config.MAX_PUBLISH_BODY + 64)
        status, _, _ = author.post("/api/places", {"title": "Enorme", "level": big})
        self.assertEqual(status, 413)

        status, _, payload = author.post(
            "/api/places", {"title": "T" * 200, "level": level}
        )
        self.assertEqual(status, 201)
        self.assertEqual(len(payload["place"]["title"]), places.MAX_TITLE)

    def test_delete_own_place(self):
        author, _ = self._register_user("autore_del")
        level = self._level("Da cancellare")
        status, _, payload = author.post(
            "/api/places", {"title": "Da cancellare", "level": level}
        )
        self.assertEqual(status, 201)
        place_id = payload["place"]["id"]
        status, _, _ = author.delete(f"/api/places/{place_id}")
        self.assertEqual(status, 200)
        self.assertEqual(self.client().get(f"/api/places/{place_id}")[0], 404)
        _, _, mine = author.get("/api/me/places")
        self.assertNotIn(place_id, [item["id"] for item in mine["places"]])

    def test_public_user_profile(self):
        author = auth.get_user_by_username("RobloxWeb")
        status, _, payload = self.client().get(f"/api/users/{int(author['id'])}")
        self.assertEqual(status, 200)
        self.assertEqual(payload["user"]["name"], "RobloxWeb")
        self.assertTrue(str(payload["user"]["avatar_color"]).startswith("#"))
        self.assertGreaterEqual(payload["stats"]["places"], 2)
        self.assertIn(
            "Welcome Obby", [item["title"] for item in payload["places"]]
        )
        status, _, _ = self.client().get("/api/users/999999")
        self.assertEqual(status, 404)

    # --- scoperta (M4) -----------------------------------------------------

    def test_schema_v2_likes_and_reports(self):
        version = db.connection().execute("PRAGMA user_version").fetchone()[0]
        self.assertEqual(int(version), 3)
        columns = {
            row["name"]
            for row in db.connection().execute("PRAGMA table_info(places)").fetchall()
        }
        self.assertIn("likes", columns)
        self.assertIn("hidden", columns)
        self.assertIn("hidden_reason", columns)
        user_columns = {
            row["name"]
            for row in db.connection().execute("PRAGMA table_info(users)").fetchall()
        }
        self.assertIn("is_admin", user_columns)
        report_columns = {
            row["name"]
            for row in db.connection().execute("PRAGMA table_info(reports)").fetchall()
        }
        self.assertIn("status", report_columns)
        self.assertIn("resolved_at", report_columns)
        tables = {
            row["name"]
            for row in db.connection()
            .execute("SELECT name FROM sqlite_master WHERE type = 'table'")
            .fetchall()
        }
        self.assertIn("place_likes", tables)
        self.assertIn("reports", tables)

    def test_search_by_title_and_author(self):
        status, _, payload = self.client().get("/api/places?q=welcome")
        self.assertEqual(status, 200)
        self.assertIn("Welcome Obby", [item["title"] for item in payload["places"]])

        status, _, payload = self.client().get("/api/places?q=robloxweb")
        self.assertEqual(status, 200)
        self.assertIn("Welcome Obby", [item["title"] for item in payload["places"]])

        status, _, payload = self.client().get("/api/places?q=nessun-risultato-xyz")
        self.assertEqual(status, 200)
        self.assertEqual(payload["places"], [])

    def _public_place(self, owner_id: int, title: str) -> int:
        text = Path(config.DEFAULT_LEVEL_PATH).read_text(encoding="utf-8")
        return places.create_place(
            int(owner_id), title, "", text, visibility="public"
        )

    def test_like_toggle_guest_and_liked_list(self):
        author = auth.get_user_by_username("RobloxWeb")
        place_id = self._public_place(int(author["id"]), "Like test")

        anon = self.client()
        status, _, _ = anon.post(f"/api/places/{place_id}/like")
        self.assertEqual(status, 401)
        status, _, _ = anon.get("/api/me/likes")
        self.assertEqual(status, 401)

        guest = self.client()
        self.assertEqual(guest.post("/api/guest")[0], 200)
        status, _, payload = guest.post(f"/api/places/{place_id}/like")
        self.assertEqual(status, 403)
        self.assertIn("ospiti", payload["error"])

        reader, reader_user = self._register_user("liker")
        status, _, payload = reader.post(f"/api/places/{place_id}/like")
        self.assertEqual(status, 200)
        self.assertEqual(payload, {"liked": True, "likes": 1})

        status, _, detail = reader.get(f"/api/places/{place_id}")
        self.assertEqual(status, 200)
        self.assertTrue(detail["place"]["liked"])
        self.assertEqual(detail["place"]["likes"], 1)

        status, _, detail = self.client().get(f"/api/places/{place_id}")
        self.assertFalse(detail["place"]["liked"])
        self.assertEqual(detail["place"]["likes"], 1)

        status, _, liked = reader.get("/api/me/likes")
        self.assertEqual(status, 200)
        self.assertIn(place_id, [item["id"] for item in liked["places"]])

        # Un secondo click toglie il like e il conteggio torna a zero.
        status, _, payload = reader.post(f"/api/places/{place_id}/like")
        self.assertEqual(status, 200)
        self.assertEqual(payload, {"liked": False, "likes": 0})
        status, _, liked = reader.get("/api/me/likes")
        self.assertNotIn(place_id, [item["id"] for item in liked["places"]])

        status, _, _ = reader.post("/api/places/999999/like")
        self.assertEqual(status, 404)

    def test_popular_sort_uses_likes(self):
        author = auth.get_user_by_username("RobloxWeb")
        low = self._public_place(int(author["id"]), "Meno like")
        high = self._public_place(int(author["id"]), "Piu like")
        reader, _ = self._register_user("sorter")
        self.assertEqual(reader.post(f"/api/places/{high}/like")[0], 200)

        _, _, payload = reader.get("/api/places?sort=likes")
        ids = [item["id"] for item in payload["places"]]
        self.assertIn(low, ids)
        self.assertIn(high, ids)
        self.assertLess(ids.index(high), ids.index(low))

    def test_version_rollback(self):
        author, author_user = self._register_user("autore_rollback")
        level_one = self._level("Rollback v1")
        status, _, payload = author.post(
            "/api/places", {"title": "Rollback", "level": level_one}
        )
        self.assertEqual(status, 201)
        place_id = payload["place"]["id"]

        level_two = self._level("Rollback v2")
        status, _, published = author.post(
            f"/api/places/{place_id}/versions",
            {"level": level_two, "title": "Rollback v2"},
        )
        self.assertEqual(status, 200)
        self.assertEqual(published["version"], 2)

        guest = self.client()
        self.assertEqual(guest.post("/api/guest")[0], 200)
        status, _, _ = guest.post(f"/api/places/{place_id}/versions/1/rollback")
        self.assertEqual(status, 403)

        reader, _ = self._register_user("lettore_rollback")
        status, _, _ = reader.post(f"/api/places/{place_id}/versions/1/rollback")
        self.assertEqual(status, 403)

        status, _, restored = author.post(
            f"/api/places/{place_id}/versions/1/rollback"
        )
        self.assertEqual(status, 200, restored)
        self.assertEqual(restored["version"], 3)
        self.assertEqual(restored["restored_from"], 1)
        self.assertEqual(restored["place"]["current_version"], 3)
        # I metadati correnti restano quelli dell'ultima pubblicazione.
        self.assertEqual(restored["place"]["title"], "Rollback v2")

        status, _, data = author.get(f"/api/places/{place_id}/data")
        self.assertEqual(status, 200)
        self.assertEqual(data["level"]["meta"]["title"], "Rollback v1")

        status, _, versions = author.get(f"/api/places/{place_id}/versions")
        self.assertEqual(
            [item["version"] for item in versions["versions"]], [3, 2, 1]
        )

        status, _, _ = author.post(f"/api/places/{place_id}/versions/99/rollback")
        self.assertEqual(status, 404)

    def test_report_place(self):
        author = auth.get_user_by_username("RobloxWeb")
        place_id = self._public_place(int(author["id"]), "Da segnalare")

        anon = self.client()
        status, _, _ = anon.post(
            f"/api/places/{place_id}/report", {"reason": "spam"}
        )
        self.assertEqual(status, 401)

        guest = self.client()
        self.assertEqual(guest.post("/api/guest")[0], 200)
        status, _, _ = guest.post(
            f"/api/places/{place_id}/report", {"reason": "spam"}
        )
        self.assertEqual(status, 403)

        reporter, reporter_user = self._register_user("reporter")
        status, _, _ = reporter.post(
            f"/api/places/{place_id}/report",
            {"reason": "spam", "details": "Link sospetti"},
        )
        self.assertEqual(status, 201)
        # Una seconda segnalazione dello stesso utente aggiorna quella esistente.
        status, _, _ = reporter.post(
            f"/api/places/{place_id}/report",
            {"reason": "copyright", "details": "Aggiornata"},
        )
        self.assertEqual(status, 201)
        rows = db.connection().execute(
            "SELECT * FROM reports WHERE place_id = ? AND reporter_id = ?",
            (place_id, int(reporter_user["id"])),
        ).fetchall()
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["reason"], "copyright")

        status, _, _ = reporter.post(
            f"/api/places/{place_id}/report", {"reason": "sconosciuto"}
        )
        self.assertEqual(status, 400)

        own_id = self._public_place(int(reporter_user["id"]), "La mia")
        status, _, _ = reporter.post(
            f"/api/places/{own_id}/report", {"reason": "spam"}
        )
        self.assertEqual(status, 400)

        status, _, _ = reporter.post(
            "/api/places/999999/report", {"reason": "spam"}
        )
        self.assertEqual(status, 404)

    # --- ticket ------------------------------------------------------------

    def test_ticket_roundtrip_forged_and_expired(self):
        user = auth.get_user_by_username("demo")
        ticket = auth.make_ticket(user, self.seed_place_id)
        payload = auth.parse_ticket(ticket)
        self.assertEqual(payload["user_id"], int(user["id"]))
        self.assertEqual(payload["place_id"], self.seed_place_id)
        self.assertFalse(payload["is_guest"])

        with self.assertRaises(auth.TicketError):
            auth.parse_ticket(ticket[:-2] + "xx")

        expired = _ticket_payload(
            {
                "u": int(user["id"]),
                "p": self.seed_place_id,
                "e": int(time.time()) - 10,
                "g": False,
                "n": "demo",
            }
        )
        with self.assertRaises(auth.TicketError):
            auth.parse_ticket(expired)

    # --- relay -------------------------------------------------------------

    def _ticket_for(self, user, place_id: int) -> str:
        return auth.make_ticket(user, place_id)

    def _guest(self):
        return auth.create_guest()

    def _second_place(self) -> int:
        author = auth.get_user_by_username("RobloxWeb")
        text = Path(config.DEFAULT_LEVEL_PATH).read_text(encoding="utf-8")
        return places.create_place(
            int(author["id"]), "Seconda", "", text, visibility="public"
        )

    def test_relay_same_room_and_state(self):
        user_a = self._guest()
        user_b = self._guest()
        peer_a = WsPeer(self.relay.port, self._ticket_for(user_a, self.seed_place_id))
        welcome_a = peer_a.wait_for("welcome")
        self.assertIsNotNone(welcome_a)
        self.assertEqual(welcome_a["place_id"], self.seed_place_id)
        self.assertEqual(welcome_a["peers"], [])

        peer_b = WsPeer(self.relay.port, self._ticket_for(user_b, self.seed_place_id))
        welcome_b = peer_b.wait_for("welcome")
        self.assertIsNotNone(welcome_b)
        self.assertEqual(len(welcome_b["peers"]), 1)
        self.assertEqual(welcome_b["peers"][0]["id"], welcome_a["id"])

        join = peer_a.wait_for("join")
        self.assertIsNotNone(join)
        self.assertEqual(join["id"], welcome_b["id"])
        self.assertEqual(join["name"], user_b["display_name"])

        peer_b.send({"type": "state", "p": [1, 2, 3], "y": 0.5, "s": 4.0})
        state = peer_a.wait_for("state")
        self.assertIsNotNone(state)
        self.assertEqual(state["id"], welcome_b["id"])
        self.assertEqual(state["p"], [1.0, 2.0, 3.0])

        peer_b.close()
        leave = peer_a.wait_for("leave")
        self.assertIsNotNone(leave)
        self.assertEqual(leave["id"], welcome_b["id"])
        peer_a.close()

    def test_relay_room_isolation(self):
        place_two = self._second_place()
        peer_a = WsPeer(
            self.relay.port, self._ticket_for(self._guest(), self.seed_place_id)
        )
        welcome_a = peer_a.wait_for("welcome")
        self.assertIsNotNone(welcome_a)

        peer_c = WsPeer(self.relay.port, self._ticket_for(self._guest(), place_two))
        welcome_c = peer_c.wait_for("welcome")
        self.assertIsNotNone(welcome_c)
        self.assertEqual(welcome_c["place_id"], place_two)
        self.assertEqual(welcome_c["peers"], [])

        # A non deve ricevere il join di C.
        message = peer_a.next_message(0.5)
        self.assertTrue(
            message is None or message.get("type") != "join",
            f"messaggio inatteso nella stanza: {message}",
        )

        peer_c.send({"type": "state", "p": [9, 9, 9], "y": 0, "s": 0})
        message = peer_a.next_message(0.5)
        self.assertTrue(
            message is None or message.get("type") != "state",
            f"stato arrivato dalla stanza sbagliata: {message}",
        )
        peer_a.close()
        peer_c.close()

    def test_relay_guest_chat_blocked_and_user_chat_allowed(self):
        guest = self._guest()
        demo = auth.get_user_by_username("demo")
        guest_peer = WsPeer(
            self.relay.port, self._ticket_for(guest, self.seed_place_id)
        )
        self.assertIsNotNone(guest_peer.wait_for("welcome"))
        demo_peer = WsPeer(
            self.relay.port, self._ticket_for(demo, self.seed_place_id)
        )
        self.assertIsNotNone(demo_peer.wait_for("welcome"))
        self.assertIsNotNone(guest_peer.wait_for("join"))

        guest_peer.send({"type": "chat", "text": "ciao da ospite"})
        error = guest_peer.wait_for("error")
        self.assertIsNotNone(error)
        self.assertEqual(error["code"], "guest_chat")
        self.assertIsNone(demo_peer.next_message(0.4))

        demo_peer.send({"type": "chat", "text": "ciao da demo"})
        chat = guest_peer.wait_for("chat")
        self.assertIsNotNone(chat)
        self.assertEqual(chat["text"], "ciao da demo")
        self.assertEqual(chat["name"], "demo")

        guest_peer.close()
        demo_peer.close()

    def test_relay_rejects_bad_ticket(self):
        peer = WsPeer(self.relay.port, "ticket.falso")
        error = peer.wait_for("error")
        self.assertIsNotNone(error)
        self.assertEqual(error["code"], "rejected")
        peer.close()


if __name__ == "__main__":
    unittest.main()
