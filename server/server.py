#!/usr/bin/env python3
"""Server di relay multiplayer per RobloxWebEngine (puro Python, nessuna dipendenza).

Un thread per client; i messaggi JSON vengono inoltrati agli altri client.

Protocollo (JSON, un messaggio per frame di testo):
  client → server:
    {"type": "hello", "name": "Nome"}
    {"type": "state", "p": [x, y, z], "y": yaw, "s": speed}
    {"type": "chat", "text": "..."}
  server → client:
    {"type": "welcome", "id": N, "peers": [{id, name, p, y, s}, ...]}
    {"type": "join", "id": N, "name": "..."}
    {"type": "leave", "id": N}
    {"type": "state", "id": N, "p": [...], "y": yaw, "s": speed}
    {"type": "chat", "id": N, "name": "...", "text": "..."}

Uso: python3 server/server.py [--host 0.0.0.0] [--port 9080]
"""
import argparse
import json
import math
import socket
import struct
import threading
import time

from wsproto import (
    FrameReader,
    OP_PING,
    OP_PONG,
    OP_TEXT,
    accept_handshake,
    read_http_request,
    send_frame,
    send_text,
)

MAX_CLIENTS = 32
MAX_NAME = 24
MAX_CHAT = 200
MAX_COORD = 100000.0
PING_INTERVAL = 15.0
CLIENT_TIMEOUT = 45.0


def _valid_point(value):
    return (
        isinstance(value, list)
        and len(value) == 3
        and all(isinstance(v, (int, float)) and math.isfinite(v) for v in value)
    )


def _clamp(value):
    return max(-MAX_COORD, min(MAX_COORD, float(value)))


class Client(threading.Thread):
    def __init__(self, server, conn, addr, initial_buffer=b""):
        super().__init__(daemon=True)
        self.server = server
        self.conn = conn
        self.addr = addr
        self.reader = FrameReader(conn, initial_buffer)
        self.send_lock = threading.Lock()
        self.id = None
        self.name = "Giocatore"
        self.last_p = None
        self.last_y = 0.0
        self.last_s = 0.0
        self.last_seen = time.time()
        self.alive = True

    def send_json(self, obj):
        payload = json.dumps(obj, separators=(",", ":")).encode("utf-8")
        with self.send_lock:
            try:
                send_frame(self.conn, OP_TEXT, payload)
            except OSError:
                self.alive = False

    def close_quiet(self):
        self.alive = False
        try:
            self.conn.shutdown(socket.SHUT_RDWR)
        except OSError:
            pass
        try:
            self.conn.close()
        except OSError:
            pass

    def roster(self):
        return {
            "id": self.id,
            "name": self.name,
            "p": self.last_p,
            "y": self.last_y,
            "s": self.last_s,
        }

    def run(self):
        fragments = b""
        try:
            while self.alive:
                fin, opcode, payload = self.reader.read_frame()
                self.last_seen = time.time()
                if opcode == OP_PING:
                    with self.send_lock:
                        try:
                            send_frame(self.conn, OP_PONG, payload)
                        except OSError:
                            break
                elif opcode == OP_PONG:
                    pass
                elif opcode == OP_TEXT:
                    fragments = payload
                    if fin:
                        self.server.handle_message(self, fragments.decode("utf-8", "replace"))
                        fragments = b""
                elif opcode == 0x0:  # continuazione
                    fragments += payload
                    if fin:
                        self.server.handle_message(self, fragments.decode("utf-8", "replace"))
                        fragments = b""
                elif opcode == 0x8:  # close
                    break
        except (ConnectionError, OSError, struct.error):
            pass
        finally:
            self.server.remove_client(self)


class Server:
    def __init__(self, host, port):
        self.host = host
        self.port = port
        self.lock = threading.Lock()
        self.clients = []
        self.next_id = 1

    def snapshot(self):
        with self.lock:
            return list(self.clients)

    def broadcast(self, message, exclude=None):
        data = json.dumps(message, separators=(",", ":")).encode("utf-8")
        for client in self.snapshot():
            if client is exclude or client.id is None:
                continue
            with client.send_lock:
                try:
                    send_frame(client.conn, OP_TEXT, data)
                except OSError:
                    client.alive = False

    def handle_message(self, client, text):
        try:
            message = json.loads(text)
        except json.JSONDecodeError:
            return
        if not isinstance(message, dict):
            return
        kind = message.get("type")

        if kind == "hello" and client.id is None:
            with self.lock:
                if len([c for c in self.clients if c.id is not None]) >= MAX_CLIENTS:
                    client.close_quiet()
                    return
                client.id = self.next_id
                self.next_id += 1
            name = str(message.get("name", "")).strip()[:MAX_NAME]
            client.name = name or f"Giocatore{client.id}"
            peers = [c.roster() for c in self.snapshot() if c.id is not None and c is not client]
            client.send_json({"type": "welcome", "id": client.id, "peers": peers})
            self.broadcast({"type": "join", "id": client.id, "name": client.name}, exclude=client)
            print(f"[server] join id={client.id} name={client.name} totale={len(peers) + 1}")

        elif kind == "state" and client.id is not None:
            point = message.get("p")
            if not _valid_point(point):
                return
            client.last_p = [_clamp(point[0]), _clamp(point[1]), _clamp(point[2])]
            client.last_y = float(message.get("y", 0.0) or 0.0)
            client.last_s = float(message.get("s", 0.0) or 0.0)
            self.broadcast(
                {
                    "type": "state",
                    "id": client.id,
                    "p": client.last_p,
                    "y": client.last_y,
                    "s": client.last_s,
                },
                exclude=client,
            )

        elif kind == "chat" and client.id is not None:
            text_value = str(message.get("text", ""))[:MAX_CHAT].strip()
            if text_value:
                self.broadcast(
                    {"type": "chat", "id": client.id, "name": client.name, "text": text_value},
                    exclude=client,
                )

    def remove_client(self, client):
        with self.lock:
            if client in self.clients:
                self.clients.remove(client)
        if client.id is not None:
            self.broadcast({"type": "leave", "id": client.id})
            print(f"[server] leave id={client.id} nome={client.name}")
        client.close_quiet()

    def heartbeat_loop(self):
        while True:
            time.sleep(PING_INTERVAL)
            now = time.time()
            for client in self.snapshot():
                if now - client.last_seen > CLIENT_TIMEOUT:
                    print(f"[server] timeout id={client.id}")
                    client.close_quiet()
                    continue
                with client.send_lock:
                    try:
                        send_frame(client.conn, OP_PING, b"hb")
                    except OSError:
                        client.alive = False

    def serve_forever(self):
        threading.Thread(target=self.heartbeat_loop, daemon=True).start()
        server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server_socket.bind((self.host, self.port))
        server_socket.listen(16)
        print(f"[server] in ascolto su ws://{self.host}:{self.port}")
        while True:
            conn, addr = server_socket.accept()
            conn.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            try:
                headers, rest = read_http_request(conn)
                if not headers or not accept_handshake(conn, headers):
                    conn.close()
                    continue
            except OSError:
                conn.close()
                continue
            client = Client(self, conn, addr, rest)
            with self.lock:
                self.clients.append(client)
            client.start()


def main():
    parser = argparse.ArgumentParser(description="Relay multiplayer RobloxWebEngine")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=9080)
    args = parser.parse_args()
    try:
        Server(args.host, args.port).serve_forever()
    except KeyboardInterrupt:
        print("\n[server] stop")


if __name__ == "__main__":
    main()
