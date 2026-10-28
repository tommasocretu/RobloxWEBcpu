"""Logging centralizzato con rotazione su file.

Tutti i componenti usano `logs.get("nome")`; `logs.setup()` viene chiamato una
volta da `run.py` (e dai test con `quiet=True`). I log finiscono in
`data/logs/server.log`, con rotazione configurabile via ambiente.
"""
from __future__ import annotations

import logging
from logging.handlers import RotatingFileHandler
from pathlib import Path

import config

LOGGER_NAME = "robloxweb"
_MARK = "_robloxweb_handler"
_current: tuple[str, str, bool] | None = None


def setup(
    *,
    quiet: bool = False,
    level: str | None = None,
    log_dir: str | Path | None = None,
) -> logging.Logger:
    """Configura il logger applicativo (idempotente)."""
    global _current
    level_name = str(level or config.LOG_LEVEL or "INFO").upper()
    if level_name not in logging.getLevelNamesMapping():
        level_name = "INFO"
    target = Path(log_dir) if log_dir is not None else config.logs_dir()
    signature = (str(target), level_name, bool(quiet))
    logger = logging.getLogger(LOGGER_NAME)
    if _current == signature:
        return logger

    target.mkdir(parents=True, exist_ok=True)
    logger.setLevel(level_name)
    logger.propagate = False
    for handler in list(logger.handlers):
        if getattr(handler, _MARK, False):
            logger.removeHandler(handler)
            try:
                handler.close()
            except Exception:
                pass

    formatter = logging.Formatter(
        "%(asctime)s %(levelname)s [%(name)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    file_handler = RotatingFileHandler(
        target / "server.log",
        maxBytes=max(64 * 1024, int(config.LOG_MAX_BYTES)),
        backupCount=max(1, int(config.LOG_BACKUP_COUNT)),
        encoding="utf-8",
    )
    file_handler.setFormatter(formatter)
    setattr(file_handler, _MARK, True)
    logger.addHandler(file_handler)

    if not quiet:
        console = logging.StreamHandler()
        console.setFormatter(formatter)
        setattr(console, _MARK, True)
        logger.addHandler(console)

    _current = signature
    return logger


def get(component: str) -> logging.Logger:
    """Logger di un componente (`robloxweb.http`, `robloxweb.relay`, ...)."""
    return logging.getLogger(f"{LOGGER_NAME}.{component}")


def reset() -> None:
    """Chiude e rimuove gli handler (usato dai test)."""
    global _current
    logger = logging.getLogger(LOGGER_NAME)
    for handler in list(logger.handlers):
        if getattr(handler, _MARK, False):
            logger.removeHandler(handler)
            try:
                handler.close()
            except Exception:
                pass
    _current = None
