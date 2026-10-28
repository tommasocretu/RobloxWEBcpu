#!/usr/bin/env python3
"""Client di test: ottiene un ticket dall'API e simula un giocatore sul relay.

Esempi:
  # ospite sulla place 1
  python3 server/test_peer.py --guest

  # account demo, invia e attende una chat
  python3 server/test_peer.py --username demo --password demo1234 \
      --send-chat "ciao" --expect-chat "risposta"

  # verifica che un ospite non possa chattare
  python3 server/test_peer.py --guest --send-chat "ciao" \
      --expect-error guest_chat --timeout 5

  # usa un ticket già ottenuto (es. da /api/places/1/play)
  python3 server/test_peer.py --ticket "<ticket>" --ws-url ws://127.0.0.1:9081
"""
from __future__ import annotations

import argparse
import http.cookiejar
import json
import socket
import struct
import sys
import time
import urllib.error
import urllib.request
from urllib.parse import urlparse

from wsproto import (
    FrameReader,
    OP_CLOSE,
    OP_PING,
    OP_PONG,
    OP_TEXT,
    client_handshake,
    send_frame,
    send_text,
)


class Api:
    def __init__(self, base_url: str):
        self.base_url = base_url.rstrip("/")
        self.jar = http.cookiejar.CookieJar()
        self.opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(self.jar)
        )

    def post(self, path: str, payload: dict | None = None) -> dict:
        data = json.dumps(payload or {}).encode("utf-8")
        request = urllib.request.Request(
            self.base_url + path,
            data=data,
            method="POST",
            headers={"Content-Type": "application/json"},
        )
        return self._open(request)

    def get(self, path: str) -> dict:
        return self._open(urllib.request.Request(self.base_url + path))

    def _open(self, request) -> dict:
        try:
            with self.opener.open(request, timeout=10) as response:
                return json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            body = exc.read().decode("utf-8", "replace")
            raise SystemExit(f"[api] HTTP {exc.code}: {body}")
        except urllib.error.URLError as exc:
            raise SystemExit(f"[api] server non raggiungibile: {exc.reason}")


def obtain_play(args) -> tuple[str, str, str]:
    api = Api(args.server)
    if args.ticket:
        if not args.ws_url:
            raise SystemExit("--ticket richiede --ws-url")
        return args.ticket, args.ws_url, args.name
    if args.guest:
        api.post("/api/guest")
    else:
        api.post("/api/login", {"username": args.username, "password": args.password})
    payload = api.post(f"/api/places/{args.place}/play")
    name = payload.get("player", {}).get("name", args.name)
    return payload["ticket"], payload["ws_url"], name


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--server", default="http://127.0.0.1:9080")
    parser.add_argument("--place", type=int, default=1)
    parser.add_argument("--username", default="demo")
    parser.add_argument("--password", default="demo1234")
    parser.add_argument("--guest", action="store_true")
    parser.add_argument("--ticket", default="")
    parser.add_argument("--ws-url", default="")
    parser.add_argument("--name", default="Bot")
    parser.add_argument("--send-chat", default="")
    parser.add_argument("--expect-chat", default="")
    parser.add_argument("--expect-error", default="")
    parser.add_argument("--state", default="10,20,30")
    parser.add_argument("--timeout", type=float, default=15.0)
    args = parser.parse_args()

    ticket, ws_url, player_name = obtain_play(args)
    if player_name and args.name == "Bot":
        args.name = player_name

    parsed = urlparse(ws_url)
    host = parsed.hostname or "127.0.0.1"
    port = parsed.port or 80

    sock = socket.create_connection((host, port), timeout=10)
    rest = client_handshake(sock, host, port, parsed.path or "/")
    reader = FrameReader(sock, rest)
    sock.settimeout(0.2)

    send_text(sock, json.dumps({"type": "hello", "ticket": ticket}), mask=True)
    point = [float(v) for v in args.state.split(",")]
    print(f"[peer:{args.name}] connesso a {ws_url}", flush=True)

    deadline = time.time() + args.timeout
    next_state = 0.0
    chat_sent = False
    chat_ok = not args.expect_chat
    error_ok = not args.expect_error
    welcome = None
    peers_seen = 0
    exit_code = 0

    while time.time() < deadline:
        now = time.time()
        if now >= next_state:
            send_text(
                sock,
                json.dumps({"type": "state", "p": point, "y": 1.5, "s": 0.0}),
                mask=True,
            )
            next_state = now + 0.25
        if args.send_chat and not chat_sent and welcome and now > deadline - args.timeout + 1.5:
            send_text(sock, json.dumps({"type": "chat", "text": args.send_chat}), mask=True)
            print(f"[peer:{args.name}] chat inviata: {args.send_chat!r}", flush=True)
            chat_sent = True
        if chat_sent:
            if args.expect_chat and chat_ok:
                break
            if args.expect_error and error_ok:
                break

        try:
            fin, opcode, payload = reader.read_frame()
        except socket.timeout:
            continue
        except (ConnectionError, OSError, struct.error):
            print(f"[peer:{args.name}] connessione chiusa", flush=True)
            break

        if opcode == OP_PING:
            send_frame(sock, OP_PONG, payload, mask=True)
        elif opcode == OP_CLOSE:
            break
        elif opcode == OP_TEXT:
            try:
                message = json.loads(payload.decode("utf-8"))
            except (UnicodeDecodeError, json.JSONDecodeError):
                continue
            kind = message.get("type")
            if kind == "welcome":
                welcome = message
                peers_seen = len(message.get("peers", []))
                print(
                    f"[peer:{args.name}] welcome id={message.get('id')}"
                    f" place={message.get('place_id')} peers={peers_seen}",
                    flush=True,
                )
            elif kind == "join":
                peers_seen += 1
                print(f"[peer:{args.name}] join id={message.get('id')}", flush=True)
            elif kind == "leave":
                print(f"[peer:{args.name}] leave id={message.get('id')}", flush=True)
            elif kind == "chat":
                text = message.get("text", "")
                print(f"[peer:{args.name}] chat da {message.get('name')}: {text!r}", flush=True)
                if args.expect_chat and args.expect_chat in text:
                    chat_ok = True
            elif kind == "error":
                print(f"[peer:{args.name}] errore: {message.get('message')}", flush=True)
                if message.get("code") == args.expect_error:
                    error_ok = True
                elif message.get("code") == "guest_chat":
                    exit_code = 2

    send_frame(sock, OP_CLOSE, b"", mask=True)
    sock.close()

    if not welcome:
        print(f"[peer:{args.name}] TIMEOUT: nessun welcome (ticket rifiutato?)", flush=True)
        return 1
    if args.expect_chat and not chat_ok:
        print(f"[peer:{args.name}] TIMEOUT in attesa della chat {args.expect_chat!r}", flush=True)
        return 1
    if args.expect_error and not error_ok:
        print(f"[peer:{args.name}] TIMEOUT in attesa dell'errore {args.expect_error!r}", flush=True)
        return 1
    print(f"[peer:{args.name}] OK", flush=True)
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
