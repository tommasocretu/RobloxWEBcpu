# Deploy con TLS (Caddy) — esempio

Il server resta progettato per girare in locale. Questa cartella contiene un
esempio pronto per esporlo su Internet con **Caddy** come reverse proxy TLS:
il sito e le API restano su `127.0.0.1:9080`, il relay su `127.0.0.1:9081`,
Caddy termina HTTPS e inoltra `/ws*` al relay.

## 1. File

- `Caddyfile`: sito su `https://example.com`, relay su
  `wss://example.com/ws`, HSTS e limite body 4 MB.
- `robloxweb.service`: unit systemd di esempio con `ProtectSystem=strict` e
  `ReadWritePaths=/var/lib/robloxweb`.

## 2. Preparazione

```bash
sudo useradd --system --home /var/lib/robloxweb --shell /usr/sbin/nologin robloxweb
sudo mkdir -p /opt/robloxweb /var/lib/robloxweb /etc/caddy
sudo rsync -a --exclude .git --exclude __pycache__ --exclude server/data \
  --exclude WEBhtml/dev --exclude build ./ /opt/robloxweb/
sudo chown -R robloxweb:robloxweb /var/lib/robloxweb
```

Generare un secret stabile (in alternativa il server usa
`/var/lib/robloxweb/secret.key`):

```bash
openssl rand -base64 48
```

`/etc/robloxweb.env` (permessi `0600`):

```ini
ROBLOXWEB_HOST=127.0.0.1
ROBLOXWEB_DATA_DIR=/var/lib/robloxweb
ROBLOXWEB_WS_URL=wss://example.com/ws
ROBLOXWEB_SECRET=incolla-qui-il-secret-generato
ROBLOXWEB_TRUST_PROXY=1
ROBLOXWEB_ADMIN_USERS=tuo_username
ROBLOXWEB_LOG_LEVEL=INFO
```

`ROBLOXWEB_TRUST_PROXY=1` fa usare `X-Forwarded-For` per i rate limit: attivarlo
**solo** se il server non è raggiungibile direttamente. Caddy imposta da solo
`X-Forwarded-Proto`, quindi i cookie di sessione diventano `Secure`.

## 3. Avvio

```bash
sudo cp deploy/robloxweb.service /etc/systemd/system/
sudo cp deploy/Caddyfile /etc/caddy/Caddyfile   # modificare il dominio
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl daemon-reload
sudo systemctl enable --now robloxweb caddy
curl -fsS https://example.com/api/health
```

Firewall: esporre solo `80/tcp` e `443/tcp`. La `9080` e la `9081` devono
restare in ascolto su `127.0.0.1`.

## 4. Controlli e manutenzione

```bash
curl -fsS https://example.com/api/health   # ok, db, versione, uptime
sudo -u robloxweb python3 server/manage.py check
sudo -u robloxweb python3 server/manage.py backup --keep 14
sudo -u robloxweb python3 server/manage.py prune-backups --keep 14
```

Backup automatico giornaliero con cron (DB + thumbnail + manifest):

```cron
15 4 * * * cd /opt/robloxweb && /usr/bin/python3 server/manage.py backup >> /var/lib/robloxweb/logs/backup.log 2>&1
```

In più il server esegue da solo la pulizia periodica di ospiti inattivi e sessioni
scadute ogni `ROBLOXWEB_MAINTENANCE_HOURS` ore (default 6; `0` la disattiva).

Ripristino (operazione distruttiva, fermare prima il servizio e confermare):

```bash
sudo systemctl stop robloxweb
sudo -u robloxweb python3 server/manage.py restore /var/lib/robloxweb/backups/app-20261028-040000
sudo systemctl start robloxweb
```

## 5. Note sicurezza

- Cambiare la password `demo` o disabilitare il seed (`--no-seed`).
- Non esporre mai `data/` via web: è fuori da `WEBhtml/`.
- Il rate limit è in memoria: con più processi servono limiti al proxy o Redis.
- I log ruotano in `/var/lib/robloxweb/logs/server.log` (2 MB × 3 file).
- Moderazione: `python3 server/manage.py admin <username>`, poi `/admin.html`.
- Per fermare il servizio: `systemctl stop robloxweb` (SIGTERM gestito).
