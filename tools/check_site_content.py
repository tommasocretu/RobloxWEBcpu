#!/usr/bin/env python3
"""Controlli di contenuto del sito RobloxWeb.

Prima versione della PR 1: inventario pagine, token presenti, font self-hosted,
nessuna risorsa esterna e regole di copy attivabili con ``--strict-copy``.
Nessuna dipendenza esterna.
"""

from __future__ import annotations

import argparse
import html
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WEB = ROOT / "WEBhtml"
ASSETS = WEB / "assets"
CSS_PATH = ASSETS / "site.css"
JS_PATH = ASSETS / "site.js"
FONT_DIR = ASSETS / "fonts" / "source-sans-3"

PAGES = [
    "index.html",
    "place.html",
    "play.html",
    "login.html",
    "profile.html",
    "admin.html",
    "studio.html",
]
FUTURE_PAGES = ["games.html"]

FONT_FILES = {
    300: "SourceSans3-Light.woff2",
    400: "SourceSans3-Regular.woff2",
    600: "SourceSans3-Semibold.woff2",
    700: "SourceSans3-Bold.woff2",
}
PRELOAD_FONTS = [
    "/assets/fonts/source-sans-3/SourceSans3-Regular.woff2",
    "/assets/fonts/source-sans-3/SourceSans3-Semibold.woff2",
]

REQUIRED_TOKENS = [
    "rw-color-header",
    "rw-color-header-divider",
    "rw-color-text",
    "rw-color-link",
    "rw-color-primary",
    "rw-color-neutral",
    "rw-color-negative",
    "rw-color-focus",
    "rw-color-footer",
    "rw-font-sans",
    "rw-font-size-body",
    "rw-line-height-body",
    "rw-header-height",
    "rw-content",
    "rw-content-wide",
    "rw-card-width",
    "rw-card-thumb-width",
    "rw-card-thumb-height",
    "rw-sidebar-width",
    "rw-radius",
    "rw-border-width",
    "rw-space-4",
    "rw-motion-fast",
    "rw-z-modal",
]

COPY_PATTERNS = [
    (re.compile(r"\besperienz", re.IGNORECASE), "“esperienza/esperienze”"),
    (re.compile(r"\blike\b", re.IGNORECASE), "“like”"),
    (re.compile(r"\bonline\b", re.IGNORECASE), "“online”"),
]

LOCAL_HOSTS = ("localhost", "127.0.0.1", "::1")
RESOURCE_TAG_RE = re.compile(
    r"<(script|link|img|iframe|source|video|audio)\b([^>]*)>", re.IGNORECASE
)
ATTR_RE = re.compile(r"\b(?:src|href)\s*=\s*[\"']([^\"']+)[\"']", re.IGNORECASE)
CSS_URL_RE = re.compile(r"url\(\s*[\"']?([^\"')]+)[\"']?\s*\)", re.IGNORECASE)
CSS_IMPORT_RE = re.compile(r"@import\b", re.IGNORECASE)
CSS_TOKEN_RE = re.compile(r"--(rw-[a-z0-9-]+)\s*:\s*([^;]+);")


def is_external(url: str) -> bool:
    if url.startswith(("#", "/", "./", "../")):
        return False
    if url.startswith("data:"):
        return False
    if url.startswith("http://") or url.startswith("https://"):
        host = url.split("://", 1)[1].split("/", 1)[0].split(":", 1)[0].lower()
        return host not in LOCAL_HOSTS
    if url.startswith("//"):
        host = url[2:].split("/", 1)[0].split(":", 1)[0].lower()
        return host not in LOCAL_HOSTS
    return False


def visible_text(markup: str) -> str:
    text = re.sub(r"<(script|style)\b.*?</\1>", " ", markup, flags=re.IGNORECASE | re.DOTALL)
    text = re.sub(r"<[^>]+>", " ", text)
    return re.sub(r"\s+", " ", html.unescape(text)).strip()


def parse_css_tokens(text: str) -> dict[str, str]:
    return {name: value.strip() for name, value in CSS_TOKEN_RE.findall(text)}


def check_pages(errors: list[str]) -> None:
    print("\nPagine:")
    for name in PAGES:
        path = WEB / name
        if not path.exists():
            errors.append(f"pagina mancante: WEBhtml/{name}")
            continue
        markup = path.read_text(encoding="utf-8")
        if 'lang="it"' not in markup:
            errors.append(f"{name}: manca lang=\"it\"")
        if not re.search(r"<title>[^<]+</title>", markup):
            errors.append(f"{name}: manca <title>")
        if 'name="viewport"' not in markup:
            errors.append(f"{name}: manca meta viewport")
        if 'href="/assets/site.css"' not in markup:
            errors.append(f"{name}: non carica /assets/site.css")
        for font in PRELOAD_FONTS:
            if f'href="{font}"' not in markup:
                errors.append(f"{name}: manca il preload di {font}")
        print(f"  - {name}: ok")

    existing = {path.name for path in WEB.glob("*.html")}
    for name in FUTURE_PAGES:
        if name not in existing:
            print(f"  - {name}: prevista, non ancora creata (PR 3)")


def check_tokens(css_text: str, errors: list[str]) -> None:
    print("\nToken:")
    tokens = parse_css_tokens(css_text)
    for name in REQUIRED_TOKENS:
        if name not in tokens:
            errors.append(f"token mancante in site.css: --{name}")
    print(f"  - {len(tokens)} token --rw-* trovati; {len(REQUIRED_TOKENS)} richiesti")


def check_fonts(css_text: str, errors: list[str]) -> None:
    print("\nFont:")
    for weight, filename in FONT_FILES.items():
        path = FONT_DIR / filename
        if not path.exists():
            errors.append(f"font mancante: {path.relative_to(ROOT)}")
            continue
        if path.read_bytes()[:4] != b"wOF2":
            errors.append(f"{path.name}: non è un WOFF2 valido")
            continue
        print(f"  - {filename}: {path.stat().st_size} byte, wOF2")
        block = re.search(
            rf"@font-face\s*\{{[^}}]*font-weight:\s*{weight};[^}}]*"
            rf"url\(\s*[\"']fonts/source-sans-3/{re.escape(filename)}[\"']\s*\)",
            css_text,
            re.DOTALL,
        )
        if not block:
            errors.append(f"site.css: manca @font-face {weight} per {filename}")

    if CSS_IMPORT_RE.search(css_text):
        errors.append("site.css: @import non consentito")
    for url in CSS_URL_RE.findall(css_text):
        if is_external(url):
            errors.append(f"site.css: risorsa esterna non consentita: {url}")


def check_external_resources(errors: list[str]) -> None:
    print("\nRisorse esterne:")
    for name in PAGES:
        path = WEB / name
        if not path.exists():
            continue
        markup = path.read_text(encoding="utf-8")
        for tag, attrs in RESOURCE_TAG_RE.findall(markup):
            for url in ATTR_RE.findall(attrs):
                if is_external(url):
                    errors.append(f"{name}: <{tag}> carica una risorsa esterna: {url}")
    if JS_PATH.exists():
        for url in re.findall(r"https?://[^\s\"'<>]+", JS_PATH.read_text(encoding="utf-8")):
            if is_external(url):
                errors.append(f"site.js: URL esterno non consentito: {url}")
    print("  - controllati script/link/img/iframe/source/video/audio e site.js")


def check_copy(strict: bool, errors: list[str]) -> None:
    print("\nCopy:")
    findings: list[tuple[str, str, str]] = []
    for name in PAGES:
        path = WEB / name
        if not path.exists():
            continue
        text = visible_text(path.read_text(encoding="utf-8"))
        for pattern, label in COPY_PATTERNS:
            if pattern.search(text):
                findings.append((name, label, text))
    if not findings:
        print("  - nessuna occorrenza dei termini da sostituire")
        return
    pages_with_findings = len({name for name, _label, _text in findings})
    print(f"  - {pages_with_findings} pagine con termini da sostituire (sweep PR 2)")
    if strict:
        for name, label, _text in findings:
            errors.append(f"{name}: termine da sostituire: {label}")
    else:
        print("  - regole attivabili con --strict-copy")


def print_sizes() -> None:
    print("\nDimensioni:")
    for path in [CSS_PATH, JS_PATH, *sorted(FONT_DIR.glob("*.woff2"))]:
        if path.exists():
            print(f"  - {path.relative_to(ROOT)}: {path.stat().st_size} byte")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--strict-copy",
        action="store_true",
        help="tratta i termini di copy da sostituire come errori (PR 2)",
    )
    args = parser.parse_args()

    errors: list[str] = []
    if not CSS_PATH.exists():
        errors.append("WEBhtml/assets/site.css mancante")
    else:
        css_text = CSS_PATH.read_text(encoding="utf-8")
        check_tokens(css_text, errors)
        check_fonts(css_text, errors)
    check_pages(errors)
    check_external_resources(errors)
    check_copy(args.strict_copy, errors)
    print_sizes()

    if errors:
        print("\nErrori:")
        for error in errors:
            print(f"  - {error}")
        print(f"\n{len(errors)} errori di contenuto.")
        return 1
    print("\nOK: pagine, token, font e risorse esterne coerenti.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
