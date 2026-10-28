"""Test M0: HTTP API, sessioni, place, ticket e relay per stanze."""
from __future__ import annotations

import base64
import hashlib
import hmac
import http.client
import json
import select
import socket
import sys
import tempfile
import threading
import time
import unittest
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
import places  # noqa: E402
from relay import RelayServer  # noqa: E402
from wsproto import FrameReader, OP_CLOSE, OP_PING, OP_PONG, OP_TEXT, client_handshake, send_frame, send_text  # noqa: E402


class HttpClient:
    def __init__(self, base_url: str):
        self.base_url = base_url.rstrip("/")
        self.cookies: dict[str, str] = {}

    def request(self, method: str, path: str, body=None, headers: dict | None = None):
        parsed = urlsplit(self.base_url)
        conn = http.client.HTTPConnection(parsed.hostname, parsed.port, timeout=10)
        request_headers = dict(headers or {})
        request_headers["Connection"] = "close"
        if self.cookies:
            request_headers["Cookie"] = "; ".join(
                f"{key}={value}" for key, value in self.cookies.items()
            )
        payload = None
        if body is not None:
            payload = json.dumps(body).encode("utf-8")
            request_headers.setdefault("Content-Type", "application/json")
        conn.request(method, path, body=payload, headers=request_headers)
        response = conn.getresponse()
        raw = response.read()
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

        config.configure(data_dir=base / "data", web_root=web, http_port=0, ws_port=0)
        config.ensure_data_dir()
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

        status, _, payload = self.client().get(f"/api/places/{self.seed_place_id}")
        self.assertEqual(status, 200)
        self.assertEqual(payload["place"]["id"], self.seed_place_id)

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
