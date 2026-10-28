#!/usr/bin/env python3
"""Manutenzione del database e dei dati demo.

Uso:
  python3 server/manage.py seed
  python3 server/manage.py reset [--yes]
  python3 server/manage.py backup [destinazione]
  python3 server/manage.py cleanup-guests [giorni]
"""
from __future__ import annotations

import argparse
import shutil
import sys
from datetime import datetime

import auth
import config
import db
import places


def _prepare() -> None:
    config.ensure_data_dir()
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
    if args.destination:
        destination = args.destination
    else:
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        destination = config.DATA_DIR / "backups" / f"app-{stamp}.db"
    target = db.backup(destination)
    print("Backup creato:", target)
    thumbs = config.thumbs_dir()
    if args.with_thumbs and thumbs.exists():
        target_dir = target.parent / (target.stem + "-thumbs")
        if target_dir.exists():
            shutil.rmtree(target_dir)
        shutil.copytree(thumbs, target_dir)
        print("Thumbnail copiate in:", target_dir)
    return 0


def cmd_cleanup_guests(args) -> int:
    _prepare()
    removed = auth.cleanup_guests(args.days)
    print(f"Ospiti rimossi: {removed}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Manutenzione RobloxWeb")
    sub = parser.add_subparsers(dest="command", required=True)

    p_seed = sub.add_parser("seed", help="crea utenti e place demo (idempotente)")
    p_seed.set_defaults(func=cmd_seed)

    p_reset = sub.add_parser("reset", help="azzera il database")
    p_reset.add_argument("--yes", action="store_true")
    p_reset.add_argument("--no-seed", action="store_true")
    p_reset.set_defaults(func=cmd_reset)

    p_backup = sub.add_parser("backup", help="copia consistente del database")
    p_backup.add_argument("destination", nargs="?")
    p_backup.add_argument("--with-thumbs", action="store_true")
    p_backup.set_defaults(func=cmd_backup)

    p_cleanup = sub.add_parser("cleanup-guests", help="elimina ospiti inattivi")
    p_cleanup.add_argument("days", nargs="?", type=int, default=config.GUEST_CLEANUP_DAYS)
    p_cleanup.set_defaults(func=cmd_cleanup_guests)

    args = parser.parse_args()
    return int(args.func(args) or 0)


if __name__ == "__main__":
    sys.exit(main())
