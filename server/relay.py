"""Relay WebSocket multi-giocatore con stanze per place e ticket HMAC."""
from __future__ import annotations

import json
import math
import socket
import struct
import threading
import time

import auth
import config
import logs
from wsproto import (
    FrameReader,
    OP_CLOSE,
    OP_PING,
    OP_PONG,
    OP_TEXT,
    accept_handshake,
    read_http_request,
    send_frame,
)

MAX_NAME = 40
MAX_CHAT = 200
MAX_COORD = 100000.0
PING_INTERVAL = 15.0
CLIENT_TIMEOUT = 45.0

_log = logs.get("relay")


def _clean_text(value: str, limit: int) -> str:
    """Rimuove caratteri di controllo e limita la lunghezza."""
    cleaned = "".join(ch for ch in str(value) if ch.isprintable())
    return cleaned[:limit].strip()


def _rate_ok(stamps: list[float], limit: int, window: float) -> bool:
    """Finestra scorrevole in-place: True se l'azione è consentita."""
    now = time.monotonic()
    cutoff = now - max(0.1, float(window))
    stamps[:] = [stamp for stamp in stamps if stamp > cutoff]
    if len(stamps) >= max(1, int(limit)):
        return False
    stamps.append(now)
    return True


def _valid_point(value) -> bool:
    return (
        isinstance(value, list)
        and len(value) == 3
        and all(isinstance(v, (int, float)) and math.isfinite(v) for v in value)
    )


def _clamp(value: float) -> float:
    return max(-MAX_COORD, min(MAX_COORD, float(value)))


class Client(threading.Thread):
    def __init__(self, server: "RelayServer", conn, addr, initial_buffer=b""):
        super().__init__(daemon=True)
        self.server = server
        self.conn = conn
        self.addr = addr
        self.reader = FrameReader(conn, initial_buffer, max_payload=config.MAX_WS_MESSAGE)
        self.send_lock = threading.Lock()
        self.id: int | None = None
        self.place_id: int | None = None
        self.name = "Giocatore"
        self.is_guest = False
        self.last_p = None
        self.last_y = 0.0
        self.last_s = 0.0
        self.last_seen = time.time()
        self.chat_times: list[float] = []
        self.state_times: list[float] = []
        self.alive = True

    def send_json(self, obj: dict) -> None:
        payload = json.dumps(obj, separators=(",", ":")).encode("utf-8")
        with self.send_lock:
            try:
                send_frame(self.conn, OP_TEXT, payload)
            except OSError:
                self.alive = False

    def close_quiet(self) -> None:
        self.alive = False
        try:
            self.conn.shutdown(socket.SHUT_RDWR)
        except OSError:
            pass
        try:
            self.conn.close()
        except OSError:
            pass

    def roster(self) -> dict:
        return {
            "id": self.id,
            "name": self.name,
            "p": self.last_p,
            "y": self.last_y,
            "s": self.last_s,
        }

    def run(self) -> None:
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
                    if len(fragments) > config.MAX_WS_MESSAGE:
                        raise ConnectionError("messaggio troppo grande")
                    if fin:
                        self.server.handle_message(self, fragments.decode("utf-8", "replace"))
                        fragments = b""
                elif opcode == OP_CLOSE:
                    break
        except (ConnectionError, OSError, struct.error):
            pass
        finally:
            self.server.remove_client(self)


class RelayServer:
    """Relay con una stanza per `place_id`; il ticket firmato decide la stanza."""

    def __init__(self, host: str, port: int):
        self.host = host
        self.port = port
        self.lock = threading.RLock()
        self.clients: list[Client] = []
        self.next_id = 1
        self._socket: socket.socket | None = None
        self._running = False
        self._ready = threading.Event()
        self._thread: threading.Thread | None = None

    # --- lifecycle ---------------------------------------------------------

    def bind(self) -> None:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.bind((self.host, self.port))
        sock.listen(32)
        self._socket = sock
        self.port = int(sock.getsockname()[1])
        self._ready.set()

    def start(self) -> None:
        self._thread = threading.Thread(target=self.serve_forever, daemon=True)
        self._thread.start()
        self._ready.wait(5.0)

    def stop(self) -> None:
        self._running = False
        if self._socket is not None:
            try:
                self._socket.close()
            except OSError:
                pass
        for client in self.snapshot():
            client.close_quiet()

    def serve_forever(self) -> None:
        if self._socket is None:
            self.bind()
        assert self._socket is not None
        self._running = True
        threading.Thread(target=self.heartbeat_loop, daemon=True).start()
        _log.info("in ascolto su ws://%s:%s", self.host, self.port)
        while self._running:
            try:
                conn, addr = self._socket.accept()
            except OSError:
                break
            conn.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            if not self._accept_allowed(addr):
                _log.warning("connessione rifiutata (cap): %s", addr)
                conn.close()
                continue
            conn.settimeout(10.0)
            try:
                headers, rest = read_http_request(conn)
                if not headers or not accept_handshake(conn, headers):
                    conn.close()
                    continue
            except OSError:
                conn.close()
                continue
            conn.settimeout(None)
            client = Client(self, conn, addr, rest)
            with self.lock:
                self.clients.append(client)
            client.start()

    # --- registry ----------------------------------------------------------

    def snapshot(self) -> list[Client]:
        with self.lock:
            return list(self.clients)

    def live_players(self, place_id: int) -> int:
        with self.lock:
            return sum(1 for c in self.clients if c.place_id == int(place_id))

    def total_players(self) -> int:
        with self.lock:
            return sum(1 for c in self.clients if c.id is not None)

    def _accept_allowed(self, addr) -> bool:
        with self.lock:
            if len(self.clients) >= config.MAX_WS_CONNECTIONS:
                return False
            ip = addr[0] if addr else ""
            if sum(1 for c in self.clients if c.addr and c.addr[0] == ip) >= config.MAX_WS_PER_IP:
                return False
        return True

    def room_clients(self, place_id: int) -> list[Client]:
        with self.lock:
            return [c for c in self.clients if c.place_id == int(place_id) and c.id is not None]

    def _joined_count(self) -> int:
        with self.lock:
            return sum(1 for c in self.clients if c.id is not None)

    def broadcast(self, place_id: int, message: dict, exclude: Client | None = None) -> None:
        data = json.dumps(message, separators=(",", ":")).encode("utf-8")
        for client in self.room_clients(place_id):
            if client is exclude:
                continue
            with client.send_lock:
                try:
                    send_frame(client.conn, OP_TEXT, data)
                except OSError:
                    client.alive = False

    # --- protocollo --------------------------------------------------------

    def _reject(self, client: Client, message: str) -> None:
        client.send_json({"type": "error", "code": "rejected", "message": message})
        client.close_quiet()

    def handle_message(self, client: Client, text: str) -> None:
        try:
            message = json.loads(text)
        except json.JSONDecodeError:
            return
        if not isinstance(message, dict):
            return
        kind = message.get("type")

        if kind == "hello":
            self._handle_hello(client, message)
            return
        if client.id is None or client.place_id is None:
            return

        if kind == "state":
            if not _rate_ok(client.state_times, config.WS_STATE_PER_SECOND, 1.0):
                return
            point = message.get("p")
            if not _valid_point(point):
                return
            try:
                yaw = float(message.get("y", 0.0) or 0.0)
                speed = float(message.get("s", 0.0) or 0.0)
            except (TypeError, ValueError):
                return
            if not math.isfinite(yaw) or not math.isfinite(speed):
                return
            client.last_p = [_clamp(point[0]), _clamp(point[1]), _clamp(point[2])]
            client.last_y = yaw
            client.last_s = speed
            self.broadcast(
                client.place_id,
                {
                    "type": "state",
                    "id": client.id,
                    "p": client.last_p,
                    "y": client.last_y,
                    "s": client.last_s,
                },
                exclude=client,
            )

        elif kind == "chat":
            if client.is_guest:
                client.send_json(
                    {
                        "type": "error",
                        "code": "guest_chat",
                        "message": "Gli ospiti non possono chattare. Accedi per usare la chat.",
                    }
                )
                return
            if not _rate_ok(client.chat_times, config.WS_CHAT_PER_MINUTE, 60.0):
                client.send_json(
                    {
                        "type": "error",
                        "code": "rate_limited",
                        "message": "Stai scrivendo troppo velocemente. Attendi un momento.",
                    }
                )
                return
            value = _clean_text(message.get("text", ""), MAX_CHAT)
            if value:
                self.broadcast(
                    client.place_id,
                    {
                        "type": "chat",
                        "id": client.id,
                        "name": client.name,
                        "text": value,
                    },
                    exclude=client,
                )

    def _handle_hello(self, client: Client, message: dict) -> None:
        if client.id is not None:
            return
        ticket = message.get("ticket")
        if not isinstance(ticket, str) or not ticket:
            self._reject(client, "Ticket mancante.")
            return
        try:
            payload = auth.parse_ticket(ticket)
        except auth.TicketError as exc:
            _log.warning("ticket rifiutato da %s: %s", client.addr, exc)
            self._reject(client, "Ticket non valido o scaduto.")
            return
        place_id = int(payload["place_id"])
        with self.lock:
            room_count = len([c for c in self.clients if c.place_id == place_id and c.id is not None])
            if room_count >= config.MAX_PLAYERS_PER_ROOM:
                over_room = True
            else:
                over_room = False
            if self._joined_count() >= config.MAX_WS_CLIENTS:
                over_global = True
            else:
                over_global = False
            if over_room or over_global:
                client.send_json(
                    {
                        "type": "error",
                        "code": "full",
                        "message": "Stanza piena, riprova tra poco.",
                    }
                )
                client.close_quiet()
                return
            client.id = self.next_id
            self.next_id += 1
            client.place_id = place_id
            client.name = _clean_text(payload["name"], MAX_NAME) or f"Giocatore{client.id}"
            client.is_guest = bool(payload["is_guest"])
        peers = [
            c.roster()
            for c in self.room_clients(place_id)
            if c is not client and c.id is not None
        ]
        client.send_json(
            {
                "type": "welcome",
                "id": client.id,
                "place_id": place_id,
                "peers": peers,
            }
        )
        self.broadcast(
            place_id,
            {"type": "join", "id": client.id, "name": client.name},
            exclude=client,
        )
        print_join = (
            f"join place={place_id} id={client.id} name={client.name}"
            f" guest={client.is_guest} room={len(peers) + 1}"
        )
        _log.info(print_join)

    def remove_client(self, client: Client) -> None:
        place_id = client.place_id
        with self.lock:
            if client in self.clients:
                self.clients.remove(client)
        if client.id is not None and place_id is not None:
            self.broadcast(place_id, {"type": "leave", "id": client.id})
            _log.info("leave place=%s id=%s name=%s", place_id, client.id, client.name)
        client.close_quiet()

    def heartbeat_loop(self) -> None:
        while self._running:
            time.sleep(PING_INTERVAL)
            now = time.time()
            for client in self.snapshot():
                if now - client.last_seen > CLIENT_TIMEOUT:
                    _log.info("timeout id=%s", client.id)
                    client.close_quiet()
                    continue
                with client.send_lock:
                    try:
                        send_frame(client.conn, OP_PING, b"hb")
                    except OSError:
                        client.alive = False


def main() -> None:  # compatibilità: avvio del solo relay
    import argparse

    parser = argparse.ArgumentParser(description="Relay WebSocket RobloxWeb")
    parser.add_argument("--host", default=config.HOST)
    parser.add_argument("--port", type=int, default=config.WS_PORT)
    args = parser.parse_args()
    api = auth  # import usato per rendere esplicita la dipendenza dai ticket
    del api
    try:
        RelayServer(args.host, args.port).serve_forever()
    except KeyboardInterrupt:
        print("\n[relay] stop")


if __name__ == "__main__":
    main()
