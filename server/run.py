#!/usr/bin/env python3
"""Avvia l'intera piattaforma: HTTP (sito + API) e relay WebSocket nello stesso processo."""
from __future__ import annotations

import argparse
import signal
import sys
import threading

import app
import auth
import config
import db
import logs
import moderation
import places
from relay import RelayServer


def _install_signal_handlers() -> None:
    def stop(_signum, _frame):
        raise KeyboardInterrupt

    for name in ("SIGTERM", "SIGINT"):
        value = getattr(signal, name, None)
        if value is not None:
            try:
                signal.signal(value, stop)
            except (ValueError, OSError):  # pragma: no cover - solo main thread
                pass


def _maintenance_loop(stop_event: threading.Event) -> None:
    """Pulizia periodica di ospiti e sessioni scadute (thread separato)."""
    log = logs.get("maintenance")
    interval = max(0.0, float(config.MAINTENANCE_HOURS)) * 3600.0
    if interval <= 0:
        return
    while not stop_event.wait(interval):
        try:
            guests = auth.cleanup_guests()
            auth.cleanup_sessions()
            log.info("manutenzione: ospiti rimossi=%s", guests)
        except Exception as exc:  # pragma: no cover - dipende dal DB
            log.warning("manutenzione non riuscita: %r", exc)
    db.close()


def main() -> int:
    parser = argparse.ArgumentParser(description="RobloxWeb — server locale")
    parser.add_argument("--host", default=config.HOST, help="indirizzo di ascolto")
    parser.add_argument("--http-port", type=int, default=config.HTTP_PORT)
    parser.add_argument("--ws-port", type=int, default=config.WS_PORT)
    parser.add_argument("--no-seed", action="store_true", help="non creare i dati demo")
    args = parser.parse_args()

    config.configure(host=args.host, http_port=args.http_port, ws_port=args.ws_port)
    config.ensure_data_dir()
    logs.setup()
    log = logs.get("server")
    log.info("avvio RobloxWeb %s", config.VERSION)
    db.configure(config.db_path())
    db.init()
    if not args.no_seed:
        places.seed_demo()
    moderation.apply_env_admins(config.ADMIN_USERS)
    auth.cleanup_guests()
    auth.cleanup_sessions()

    stop_event = threading.Event()
    maintenance = threading.Thread(
        target=_maintenance_loop,
        args=(stop_event,),
        name="maintenance",
        daemon=True,
    )
    maintenance.start()

    relay = RelayServer(args.host, args.ws_port)
    relay.start()
    httpd = app.create_server(
        args.host, args.http_port, relay=relay, web_root=config.WEB_ROOT
    )
    host, port = httpd.server_address
    log.info("sito e API: http://%s:%s/", host, port)
    log.info("WebSocket:  ws://%s:%s", host, relay.port)
    log.info("dati in:    %s", config.DATA_DIR)
    _install_signal_handlers()
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        log.info("stop richiesto")
    finally:
        stop_event.set()
        maintenance.join(timeout=2)
        httpd.server_close()
        relay.stop()
        db.close()
        log.info("server fermato")
    return 0


if __name__ == "__main__":
    sys.exit(main())
