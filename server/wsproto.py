"""Primitive WebSocket (RFC 6455) in puro Python — solo standard library.

Usate sia dal server di relay sia dai client di test.
Gestisce handshake HTTP, frame di testo (con frammentazione), ping/pong e close.
I frame client→server sono mascherati, server→client no.
"""
import base64
import hashlib
import os
import socket
import struct

GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

OP_CONT = 0x0
OP_TEXT = 0x1
OP_BIN = 0x2
OP_CLOSE = 0x8
OP_PING = 0x9
OP_PONG = 0xA


def read_http_request(conn):
    """Legge la richiesta HTTP di upgrade. Ritorna (headers, resto_binario)."""
    data = b""
    while b"\r\n\r\n" not in data:
        chunk = conn.recv(1024)
        if not chunk:
            return None, b""
        data += chunk
        if len(data) > 16384:
            return None, b""
    head, _, rest = data.partition(b"\r\n\r\n")
    lines = head.decode("latin-1").split("\r\n")
    headers = {}
    for line in lines[1:]:
        if ":" in line:
            key, value = line.split(":", 1)
            headers[key.strip().lower()] = value.strip()
    return headers, rest


def accept_handshake(conn, headers):
    """Completa l'handshake server→client. Ritorna True se ok."""
    key = headers.get("sec-websocket-key")
    if not key or headers.get("upgrade", "").lower() != "websocket":
        return False
    accept = base64.b64encode(hashlib.sha1((key + GUID).encode()).digest()).decode()
    response = (
        "HTTP/1.1 101 Switching Protocols\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        f"Sec-WebSocket-Accept: {accept}\r\n"
        "\r\n"
    )
    conn.sendall(response.encode())
    return True


def client_handshake(conn, host, port, path="/"):
    """Handshake lato client (per i client di test). Ritorna il resto binario."""
    key = base64.b64encode(os.urandom(16)).decode()
    request = (
        f"GET {path} HTTP/1.1\r\n"
        f"Host: {host}:{port}\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        f"Sec-WebSocket-Key: {key}\r\n"
        "Sec-WebSocket-Version: 13\r\n"
        "\r\n"
    )
    conn.sendall(request.encode())
    data = b""
    while b"\r\n\r\n" not in data:
        chunk = conn.recv(1024)
        if not chunk:
            raise ConnectionError("handshake interrotto")
        data += chunk
    head, _, rest = data.partition(b"\r\n\r\n")
    status = head.split(b"\r\n", 1)[0]
    if b"101" not in status:
        raise ConnectionError(f"handshake rifiutato: {status!r}")
    return rest


class FrameReader:
    """Legge frame WebSocket da un socket, con buffer interno (timeout-safe)."""

    def __init__(self, conn, initial=b"", max_payload=1024 * 1024):
        self.conn = conn
        self.buf = initial
        self.max_payload = max(1, int(max_payload))

    def read_exact(self, n):
        while len(self.buf) < n:
            chunk = self.conn.recv(4096)  # socket.timeout si propaga: il buffer resta valido
            if not chunk:
                raise ConnectionError("connessione chiusa")
            self.buf += chunk
        out, self.buf = self.buf[:n], self.buf[n:]
        return out

    def read_frame(self):
        """Ritorna (fin, opcode, payload). Alza ConnectionError se chiusa."""
        b1, b2 = self.read_exact(2)
        fin = bool(b1 & 0x80)
        opcode = b1 & 0x0F
        masked = bool(b2 & 0x80)
        length = b2 & 0x7F
        if length == 126:
            length = struct.unpack(">H", self.read_exact(2))[0]
        elif length == 127:
            length = struct.unpack(">Q", self.read_exact(8))[0]
        if length > self.max_payload:
            raise ConnectionError("frame troppo grande")
        mask = self.read_exact(4) if masked else None
        payload = self.read_exact(length) if length else b""
        if mask:
            payload = bytes(byte ^ mask[i % 4] for i, byte in enumerate(payload))
        return fin, opcode, payload


def send_frame(conn, opcode, payload, mask=False):
    header = bytes([0x80 | opcode])
    size = len(payload)
    if size < 126:
        header += bytes([0x80 | size]) if mask else bytes([size])
    elif size < 65536:
        header += (bytes([0x80 | 126]) if mask else bytes([126])) + struct.pack(">H", size)
    else:
        header += (bytes([0x80 | 127]) if mask else bytes([127])) + struct.pack(">Q", size)
    if mask:
        key = os.urandom(4)
        header += key
        payload = bytes(byte ^ key[i % 4] for i, byte in enumerate(payload))
    conn.sendall(header + payload)


def send_text(conn, text, mask=False):
    send_frame(conn, OP_TEXT, text.encode("utf-8"), mask=mask)
