"""Test M5: hardening, moderazione, backup, log e limiti."""
from __future__ import annotations

import http.client
import json
import logging
import os
import sys
import tempfile
import threading
import time
import unittest
from pathlib import Path
from urllib.parse import urlsplit

SERVER_DIR = Path(__file__).resolve().parents[1]
if str(SERVER_DIR) not in sys.path:
    sys.path.insert(0, str(SERVER_DIR))

import app  # noqa: E402
import backup  # noqa: E402
import config  # noqa: E402
import db  # noqa: E402
import logs  # noqa: E402
import moderation  # noqa: E402
import places  # noqa: E402
from relay import RelayServer  # noqa: E402
from test_platform import HttpClient, make_png  # noqa: E402


def _level() -> dict:
    return {
        "format": "robloxweb-level",
        "version": 2,
        "meta": {"title": "Test M5"},
        "parts": [],
        "scripts": [],
    }


class HardeningTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.tmp = tempfile.TemporaryDirectory()
        base = Path(cls.tmp.name)
        web = base / "web"
        (web / "dev").mkdir(parents=True)
        (web / "index.html").write_text("<h1>M5 test</h1>", encoding="utf-8")
        (web / "dev" / "index.html").write_text("<h1>Client M5</h1>", encoding="utf-8")
        config.configure(
            data_dir=base / "data",
            web_root=web,
            http_port=0,
            ws_port=0,
            trust_proxy=False,
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

    def register(self, username: str):
        client = self.client()
        status, _, payload = client.post(
            "/api/register", {"username": username, "password": "segreta1"}
        )
        self.assertEqual(status, 201, payload)
        return client, payload["user"]

    def create_place(self, client: HttpClient, title: str) -> int:
        status, _, payload = client.post(
            "/api/places",
            {"title": title, "description": "creata nei test M5", "level": _level()},
        )
        self.assertEqual(status, 201, payload)
        return int(payload["place"]["id"])

    # --- infrastruttura ----------------------------------------------------

    def test_health_and_security_headers(self):
        client = self.client()
        status, _, payload = client.get("/api/health")
        self.assertEqual(status, 200)
        self.assertTrue(payload["ok"])
        self.assertEqual(payload["db"], "ok")
        self.assertEqual(payload["version"], config.VERSION)
        self.assertIn("uptime", payload)
        self.assertEqual(client.last_headers["x-content-type-options"], "nosniff")
        self.assertEqual(client.last_headers["x-frame-options"], "SAMEORIGIN")
        self.assertEqual(client.last_headers["referrer-policy"], "same-origin")

        status, _, _ = client.get("/")
        self.assertEqual(status, 200)
        self.assertIn("content-security-policy", client.last_headers)
        self.assertIn("frame-ancestors 'self'", client.last_headers["content-security-policy"])

        status, _, _ = client.get("/dev/index.html")
        self.assertEqual(status, 200)
        self.assertNotIn("content-security-policy", client.last_headers)

    def test_transfer_encoding_chunked_rejected(self):
        parsed = urlsplit(self.base_url)
        conn = http.client.HTTPConnection(parsed.hostname, parsed.port, timeout=10)
        conn.putrequest("POST", "/api/guest")
        conn.putheader("Transfer-Encoding", "chunked")
        conn.putheader("Content-Type", "application/json")
        conn.endheaders()
        conn.send(b"0\r\n\r\n")
        response = conn.getresponse()
        response.read()
        self.assertEqual(response.status, 411)
        conn.close()

    # --- sessioni e CSRF ---------------------------------------------------

    def test_cookie_post_without_origin_is_rejected(self):
        client, _ = self.register("csrf_user")
        token = client.cookies["rw_session"]
        parsed = urlsplit(self.base_url)
        conn = http.client.HTTPConnection(parsed.hostname, parsed.port, timeout=10)
        conn.request(
            "POST",
            "/api/logout",
            body=b"",
            headers={"Cookie": f"rw_session={token}", "Content-Length": "0"},
        )
        response = conn.getresponse()
        response.read()
        self.assertEqual(response.status, 403)
        conn.close()
        # La sessione non è stata cancellata dalla richiesta rifiutata.
        status, _, _ = client.get("/api/me")
        self.assertEqual(status, 200)

    def test_session_rotation_on_login(self):
        client, _ = self.register("rotate_user")
        old = client.cookies["rw_session"]
        status, _, _ = client.post(
            "/api/login", {"username": "rotate_user", "password": "segreta1"}
        )
        self.assertEqual(status, 200)
        new = client.cookies["rw_session"]
        self.assertNotEqual(old, new)

        stale = self.client()
        stale.cookies["rw_session"] = old
        status, _, _ = stale.get("/api/me")
        self.assertEqual(status, 401)
        status, _, _ = client.get("/api/me")
        self.assertEqual(status, 200)

    # --- rate limit --------------------------------------------------------

    def test_rate_limit_scope_and_retry_after(self):
        limiter = self.httpd.platform.rate_limiter
        original = limiter.limits.get("login")
        limiter.limits["login"] = (2, 60.0)
        try:
            client = self.client()
            for _ in range(2):
                status, _, _ = client.post(
                    "/api/login", {"username": "nessuno", "password": "sbagliata"}
                )
                self.assertEqual(status, 401)
            status, _, payload = client.post(
                "/api/login", {"username": "nessuno", "password": "sbagliata"}
            )
            self.assertEqual(status, 429)
            self.assertIn("error", payload)
            self.assertGreaterEqual(int(client.last_headers["retry-after"]), 1)
        finally:
            if original is None:
                limiter.limits.pop("login", None)
            else:
                limiter.limits["login"] = original

    def test_trust_proxy_uses_forwarded_ip(self):
        limiter = self.httpd.platform.rate_limiter
        original = limiter.limits.get("guest")
        limiter.limits["guest"] = (1, 60.0)
        config.configure(trust_proxy=True)
        try:
            first = self.client()
            status, _, _ = first.post(
                "/api/guest", headers={"X-Forwarded-For": "203.0.113.10"}
            )
            self.assertEqual(status, 200)
            status, _, _ = first.post(
                "/api/guest", headers={"X-Forwarded-For": "203.0.113.10"}
            )
            self.assertEqual(status, 429)
            second = self.client()
            status, _, _ = second.post(
                "/api/guest", headers={"X-Forwarded-For": "203.0.113.11"}
            )
            self.assertEqual(status, 200)
        finally:
            config.configure(trust_proxy=False)
            if original is None:
                limiter.limits.pop("guest", None)
            else:
                limiter.limits["guest"] = original

    def test_rate_limiter_unit(self):
        limiter = app.RateLimiter({"default": (2, 60.0), "short": (1, 5.0)})
        self.assertTrue(limiter.check("default", "ip")[0])
        self.assertTrue(limiter.check("default", "ip")[0])
        allowed, retry = limiter.check("default", "ip")
        self.assertFalse(allowed)
        self.assertGreater(retry, 0)
        self.assertTrue(limiter.check("short", "altro")[0])
        self.assertFalse(limiter.check("short", "altro")[0])

    # --- moderazione -------------------------------------------------------

    def test_admin_moderation_hides_and_unhides(self):
        author, _ = self.register("mod_author")
        place_id = self.create_place(author, "Esperienza moderata M5")
        reporter, _ = self.register("mod_reporter")
        status, _, _ = reporter.post(
            f"/api/places/{place_id}/report",
            {"reason": "spam", "details": "test moderazione"},
        )
        self.assertEqual(status, 201)

        status, _, _ = author.get("/api/admin/reports")
        self.assertEqual(status, 403)

        admin, _ = self.register("mod_admin")
        self.assertTrue(moderation.set_admin("mod_admin", True))
        status, _, me = admin.get("/api/me")
        self.assertEqual(status, 200)
        self.assertTrue(me["user"]["is_admin"])

        status, _, payload = admin.get("/api/admin/reports?status=open")
        self.assertEqual(status, 200)
        report = next(
            item for item in payload["reports"] if item["place_id"] == place_id
        )
        self.assertEqual(report["reason"], "spam")
        self.assertFalse(report["place_hidden"])

        status, _, payload = admin.post(
            f"/api/admin/reports/{report['id']}/resolve",
            {"action": "hide", "reason": "contenuto di prova"},
        )
        self.assertEqual(status, 200, payload)
        self.assertTrue(payload["counts"]["hidden"] >= 1)

        # Fuori dal catalogo e dal profilo pubblico.
        status, _, payload = self.client().get("/api/places?q=moderata")
        self.assertEqual(status, 200)
        self.assertEqual(payload["places"], [])
        status, _, payload = self.client().get("/api/users/" + str(report["place_owner_id"]))
        self.assertEqual(status, 200)
        self.assertNotIn(place_id, [item["id"] for item in payload["places"]])

        # Il pubblico non la vede; l'autore e l'admin sì.
        status, _, _ = self.client().get(f"/api/places/{place_id}")
        self.assertEqual(status, 403)
        status, _, payload = author.get(f"/api/places/{place_id}")
        self.assertEqual(status, 200)
        self.assertTrue(payload["place"]["hidden"])
        self.assertEqual(payload["place"]["hidden_reason"], "contenuto di prova")
        status, _, _ = admin.get(f"/api/places/{place_id}")
        self.assertEqual(status, 200)

        # Il play è bloccato anche per l'autore.
        status, _, _ = author.post(f"/api/places/{place_id}/play")
        self.assertEqual(status, 403)

        status, _, payload = admin.get("/api/admin/places")
        self.assertEqual(status, 200)
        self.assertIn(place_id, [item["id"] for item in payload["places"]])

        status, _, payload = admin.get("/api/admin/reports?status=resolved")
        self.assertEqual(status, 200)
        self.assertIn(report["id"], [item["id"] for item in payload["reports"]])

        status, _, payload = admin.post(
            f"/api/admin/places/{place_id}/moderate",
            {"hidden": False},
        )
        self.assertEqual(status, 200, payload)
        self.assertFalse(payload["place"]["hidden"])
        status, _, payload = self.client().get("/api/places?q=moderata")
        self.assertEqual(status, 200)
        self.assertEqual([item["id"] for item in payload["places"]], [place_id])

    def test_admin_endpoints_require_account(self):
        guest = self.client()
        self.assertEqual(guest.post("/api/guest")[0], 200)
        status, _, _ = guest.get("/api/admin/reports")
        self.assertEqual(status, 403)
        status, _, _ = self.client().get("/api/admin/reports")
        self.assertEqual(status, 401)


class BackupTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        base = Path(self.tmp.name)
        config.configure(
            data_dir=base / "data",
            web_root=base / "web",
            trust_proxy=False,
            rate_limits={"default": (10000, 60.0)},
        )
        config.ensure_data_dir()
        logs.setup(quiet=True)
        db.configure(config.db_path())
        db.init()
        places.seed_demo()
        self.place_id = int(
            db.connection()
            .execute("SELECT id FROM places WHERE title = 'Welcome Obby'")
            .fetchone()["id"]
        )

    def tearDown(self) -> None:
        db.close()
        logs.reset()
        os.environ.pop("ROBLOXWEB_SECRET", None)
        config.configure(trust_proxy=False)
        self.tmp.cleanup()

    def test_backup_and_restore_with_thumbs(self):
        places.set_thumbnail(self.place_id, make_png())
        folder = backup.create_backup()
        self.assertTrue((folder / "app.db").is_file())
        self.assertTrue((folder / "thumbs" / f"{self.place_id}.png").is_file())
        manifest = json.loads((folder / "manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(manifest["format"], "robloxweb-backup")
        self.assertEqual(manifest["schema_version"], db.LATEST_VERSION)
        self.assertGreaterEqual(manifest["places"], 1)

        conn = db.connection()
        conn.execute("DELETE FROM places WHERE id = ?", (self.place_id,))
        conn.commit()
        self.assertIsNone(places.get_place(self.place_id))

        backup.restore_backup(folder)
        self.assertIsNotNone(places.get_place(self.place_id))
        self.assertTrue(places.thumbnail_file(self.place_id).is_file())

    def test_pre_migration_backup(self):
        legacy = Path(self.tmp.name) / "legacy"
        db.configure(legacy / "app.db")
        conn = db.connection()
        conn.executescript(db.SCHEMA_V1)
        conn.executescript(db.SCHEMA_V2)
        conn.execute("PRAGMA user_version=2")
        conn.commit()
        db.init()
        version = int(conn.execute("PRAGMA user_version").fetchone()[0])
        self.assertEqual(version, db.LATEST_VERSION)
        found = list(config.backups_dir().glob("pre-migration-v2-*.db"))
        self.assertEqual(len(found), 1)

    def test_backup_without_thumbs(self):
        places.set_thumbnail(self.place_id, make_png())
        folder = backup.create_backup(include_thumbs=False)
        self.assertFalse((folder / "thumbs").exists())
        manifest = json.loads((folder / "manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(manifest["thumbs"], 0)
        self.assertFalse(manifest["include_thumbs"])

    def test_restore_rejects_corrupt_backup(self):
        bad = Path(self.tmp.name) / "bad"
        bad.mkdir()
        (bad / "app.db").write_bytes(b"non e un database")
        with self.assertRaises(backup.BackupError):
            backup.restore_backup(bad)

    def test_backup_refuses_active_database_and_prunes(self):
        with self.assertRaises(backup.BackupError):
            backup.create_backup(config.db_path())
        first = backup.create_backup()
        os.utime(first, (time.time() - 10, time.time() - 10))
        second = backup.create_backup()
        self.assertNotEqual(first, second)
        removed = backup.prune_backups(keep=1)
        self.assertGreaterEqual(len(removed), 1)
        remaining = sorted(config.backups_dir().glob("app-*"))
        self.assertEqual(len(remaining), 1)
        self.assertEqual(remaining[0], second)

    def test_secret_from_environment_and_logging(self):
        os.environ["ROBLOXWEB_SECRET"] = "segreto-di-prova"
        config.configure()
        self.assertEqual(config.secret_key(), b"segreto-di-prova")
        os.environ.pop("ROBLOXWEB_SECRET")
        config.configure()
        self.assertNotEqual(config.secret_key(), b"segreto-di-prova")

        logs.setup(quiet=True)
        logs.get("test").info("messaggio unico di hardening")
        for handler in logging.getLogger(logs.LOGGER_NAME).handlers:
            handler.flush()
        text = (config.logs_dir() / "server.log").read_text(encoding="utf-8")
        self.assertIn("messaggio unico di hardening", text)


if __name__ == "__main__":
    unittest.main()
