# Server multiplayer RobloxWebEngine

Relay WebSocket in puro Python (solo standard library, nessuna dipendenza da installare).

## Avvio

```bash
python3 server/server.py            # ascolta su 0.0.0.0:9080
python3 server/server.py --port 9080 --host 127.0.0.1
```

## Come funziona

- Ogni client invia `hello` (nome), poi `state` (posizione/rotazione ~20 volte al
  secondo) e `chat`.
- Il server inoltra `state`/`chat` agli altri client e notifica `join`/`leave`.
- Il `welcome` iniziale contiene l'id assegnato e l'elenco dei peer già connessi.

Il protocollo è documentato in cima a `server.py`.

## Test

```bash
# in un terminale: server attivo
# in un altro:
python3 server/test_peer.py --name B --send-chat "ciao da B" --expect-chat "risposta"
python3 server/test_peer.py --name A --send-chat "risposta" --timeout 8
```

Oppure il test automatico Godot (con server attivo):

```bash
flatpak run org.godotengine.Godot --headless --path Godot/robloxwebengine \
  --script res://tools/test_network.gd
```

## Nota per il futuro (deploy)

Il server attuale è un relay "fidato": adatto a LAN e sviluppo. Per il deploy
pubblico servirà: TLS (`wss://`), rate limiting, stanze separate per mondo e
autorità server sulla fisica (per ora ogni client è autorità del proprio
personaggio).
