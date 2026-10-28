#!/usr/bin/env python3
"""Manutenzione del database e dei dati demo.

Uso:
  python3 server/manage.py seed
  python3 server/manage.py reset [--yes]
  python3 server/manage.py backup [cartella|file.db] [--no-thumbs] [--keep N]
  python3 server/manage.py restore <cartella|file.db> [--yes]
  python3 server/manage.py prune-backups [--keep N]
  python3 server/manage.py cleanup-guests [giorni]
  python3 server/manage.py admin <username> [--revoke]
  python3 server/manage.py check
"""
from __future__ import annotations

import argparse
import sys

import auth
import backup
import config
import db
import logs
import moderation
import places


def _prepare() -> None:
    config.ensure_data_dir()
    logs.setup()
    db.configure(config.db_path())
    db.init()


def cmd_seed(_args) -> int:
    _prepare()
    summary = places.seed_demo()
    print("Seed completato:", summary)
    return 0


def cmd_reset(args) -> int:
    _prepare()
    if not args.yes:
        answer = input("Eliminare database e thumbnail? [y/N] ").strip().lower()
        if answer not in ("y", "yes", "s", "si", "sì"):
            print("Annullato.")
            return 1
    db.reset(delete_thumbs=True)
    print("Database azzerato:", config.db_path())
    if not args.no_seed:
        print("Nuovo seed:", places.seed_demo())
    return 0


def cmd_backup(args) -> int:
    _prepare()
    target = backup.create_backup(
        args.destination,
        include_thumbs=not args.no_thumbs,
        keep=args.keep,
    )
    print("Backup creato:", target)
    return 0


def cmd_restore(args) -> int:
    _prepare()
    if not args.yes:
        answer = input(
            f"Ripristinare {args.source} sopra i dati correnti? [y/N] "
        ).strip().lower()
        if answer not in ("y", "yes", "s", "si", "sì"):
            print("Annullato.")
            return 1
    try:
        result = backup.restore_backup(args.source)
    except backup.BackupError as exc:
        print("Errore:", exc)
        return 1
    print("Ripristinato:", result["db"])
    if result.get("thumbs"):
        print("Thumbnail ripristinate.")
    manifest = result.get("manifest") or {}
    if manifest:
        print(
            "Manifest: schema v%s, utenti %s, place %s"
            % (
                manifest.get("schema_version", "?"),
                manifest.get("users", "?"),
                manifest.get("places", "?"),
            )
        )
    return 0


def cmd_prune_backups(args) -> int:
    _prepare()
    removed = backup.prune_backups(keep=args.keep)
    print(f"Backup rimossi: {len(removed)}")
    for path in removed:
        print(" -", path)
    return 0


def cmd_cleanup_guests(args) -> int:
    _prepare()
    removed = auth.cleanup_guests(args.days)
    auth.cleanup_sessions()
    print(f"Ospiti rimossi: {removed}")
    return 0


def cmd_admin(args) -> int:
    _prepare()
    if moderation.set_admin(args.username, not args.revoke):
        action = "revocato" if args.revoke else "concesso"
        print(f"Ruolo amministratore {action} a {args.username}.")
        return 0
    print(f"Account non trovato (o ospite): {args.username}")
    return 1


def cmd_check(_args) -> int:
    _prepare()
    conn = db.connection()
    integrity = str(conn.execute("PRAGMA integrity_check").fetchone()[0])
    counts = conn.execute(
        "SELECT (SELECT COUNT(*) FROM users) AS users,"
        " (SELECT COUNT(*) FROM places) AS places,"
        " (SELECT COUNT(*) FROM place_versions) AS versions,"
        " (SELECT COUNT(*) FROM reports WHERE status = 'open') AS reports,"
        " (SELECT COUNT(*) FROM places WHERE hidden = 1) AS hidden"
    ).fetchone()
    thumbs = len(list(config.thumbs_dir().glob("*.png")))
    backups = len(list(config.backups_dir().glob("app-*")))
    print(f"integrità DB: {integrity}")
    print(
        "utenti %s · place %s · versioni %s · segnalazioni aperte %s · nascoste %s"
        % (
            counts["users"],
            counts["places"],
            counts["versions"],
            counts["reports"],
            counts["hidden"],
        )
    )
    print(f"thumbnail: {thumbs} · backup: {backups}")
    print(f"log: {config.logs_dir() / 'server.log'}")
    return 0 if integrity.lower() == "ok" else 1


def main() -> int:
    parser = argparse.ArgumentParser(description="Manutenzione RobloxWeb")
    sub = parser.add_subparsers(dest="command", required=True)

    p_seed = sub.add_parser("seed", help="crea utenti e place demo (idempotente)")
    p_seed.set_defaults(func=cmd_seed)

    p_reset = sub.add_parser("reset", help="azzera il database")
    p_reset.add_argument("--yes", action="store_true")
    p_reset.add_argument("--no-seed", action="store_true")
    p_reset.set_defaults(func=cmd_reset)

    p_backup = sub.add_parser("backup", help="backup consistente di DB e thumbnail")
    p_backup.add_argument("destination", nargs="?")
    p_backup.add_argument("--no-thumbs", action="store_true")
    p_backup.add_argument("--keep", type=int, default=None)
    p_backup.set_defaults(func=cmd_backup)

    p_restore = sub.add_parser("restore", help="ripristina DB e thumbnail da un backup")
    p_restore.add_argument("source")
    p_restore.add_argument("--yes", action="store_true")
    p_restore.set_defaults(func=cmd_restore)

    p_prune = sub.add_parser("prune-backups", help="elimina i backup più vecchi")
    p_prune.add_argument("--keep", type=int, default=config.BACKUP_KEEP)
    p_prune.set_defaults(func=cmd_prune_backups)

    p_cleanup = sub.add_parser("cleanup-guests", help="elimina ospiti inattivi")
    p_cleanup.add_argument("days", nargs="?", type=int, default=config.GUEST_CLEANUP_DAYS)
    p_cleanup.set_defaults(func=cmd_cleanup_guests)

    p_admin = sub.add_parser("admin", help="concede o revoca il ruolo amministratore")
    p_admin.add_argument("username")
    p_admin.add_argument("--revoke", action="store_true")
    p_admin.set_defaults(func=cmd_admin)

    p_check = sub.add_parser("check", help="controlla integrità e statistiche")
    p_check.set_defaults(func=cmd_check)

    args = parser.parse_args()
    return int(args.func(args) or 0)


if __name__ == "__main__":
    sys.exit(main())
