#!/usr/bin/env python3
"""Client di test per il server di relay: invia stato/chat e verifica le risposte.

Esempi:
  python3 server/test_peer.py --name A --expect-chat "ciao" &
  python3 server/test_peer.py --name B --send-chat "ciao da B"

Uso: python3 server/test_peer.py [--url ws://127.0.0.1:9080] [--name Bot]
     [--send-chat TESTO] [--expect-chat SOTTOTEKSTO] [--timeout 15]
"""
import argparse
import json
import socket
import struct
import sys
import time
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


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default="ws://127.0.0.1:9080")
    parser.add_argument("--name", default="Bot")
    parser.add_argument("--send-chat", default="")
    parser.add_argument("--expect-chat", default="")
    parser.add_argument("--state", default="10,20,30")
    parser.add_argument("--timeout", type=float, default=15.0)
    args = parser.parse_args()

    parsed = urlparse(args.url)
    host = parsed.hostname or "127.0.0.1"
    port = parsed.port or 80

    sock = socket.create_connection((host, port), timeout=10)
    rest = client_handshake(sock, host, port, parsed.path or "/")
    reader = FrameReader(sock, rest)
    sock.settimeout(0.2)

    send_text(sock, json.dumps({"type": "hello", "name": args.name}), mask=True)
    point = [float(v) for v in args.state.split(",")]
    print(f"[peer:{args.name}] connesso a {args.url}", flush=True)

    deadline = time.time() + args.timeout
    next_state = 0.0
    chat_sent = False
    chat_ok = not args.expect_chat
    got_welcome = False
    peers_seen = 0

    while time.time() < deadline:
        now = time.time()
        if now >= next_state:
            send_text(
                sock,
                json.dumps({"type": "state", "p": point, "y": 1.5, "s": 0.0}),
                mask=True,
            )
            next_state = now + 0.25
        if args.send_chat and not chat_sent and got_welcome and now > deadline - args.timeout + 1.5:
            send_text(sock, json.dumps({"type": "chat", "text": args.send_chat}), mask=True)
            print(f"[peer:{args.name}] chat inviata: {args.send_chat!r}", flush=True)
            chat_sent = True
        if chat_ok and chat_sent:
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
                got_welcome = True
                peers_seen = len(message.get("peers", []))
                print(f"[peer:{args.name}] welcome id={message.get('id')} peers={peers_seen}", flush=True)
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

    send_frame(sock, OP_CLOSE, b"", mask=True)
    sock.close()

    if args.expect_chat and not chat_ok:
        print(f"[peer:{args.name}] TIMEOUT in attesa della chat {args.expect_chat!r}", flush=True)
        sys.exit(1)
    print(f"[peer:{args.name}] OK", flush=True)


if __name__ == "__main__":
    main()
