#!/usr/bin/env python3
"""Avvia l'intera piattaforma: HTTP (sito + API) e relay WebSocket nello stesso processo."""
from __future__ import annotations

import argparse
import sys

import app
import auth
import config
import db
import places
from relay import RelayServer


def main() -> int:
    parser = argparse.ArgumentParser(description="RobloxWeb — server locale")
    parser.add_argument("--host", default=config.HOST, help="indirizzo di ascolto")
    parser.add_argument("--http-port", type=int, default=config.HTTP_PORT)
    parser.add_argument("--ws-port", type=int, default=config.WS_PORT)
    parser.add_argument("--no-seed", action="store_true", help="non creare i dati demo")
    args = parser.parse_args()

    config.configure(host=args.host, http_port=args.http_port, ws_port=args.ws_port)
    config.ensure_data_dir()
    db.configure(config.db_path())
    db.init()
    if not args.no_seed:
        places.seed_demo()
    auth.cleanup_guests()

    relay = RelayServer(args.host, args.ws_port)
    relay.start()
    httpd = app.create_server(
        args.host, args.http_port, relay=relay, web_root=config.WEB_ROOT
    )
    host, port = httpd.server_address
    print(f"[server] sito e API: http://{host}:{port}/")
    print(f"[server] WebSocket:  ws://{host}:{relay.port}")
    print(f"[server] dati in:    {config.DATA_DIR}")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n[server] stop")
    finally:
        httpd.server_close()
        relay.stop()
    return 0


if __name__ == "__main__":
    sys.exit(main())
