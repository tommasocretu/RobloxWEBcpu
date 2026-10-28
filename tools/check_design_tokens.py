#!/usr/bin/env python3
"""Verifica che i token CSS e GDScript restino allineati.

Confronta il sottoinsieme condiviso di `WEBhtml/assets/site.css` con
`Godot/robloxwebengine/scripts/ui/rw_tokens.gd` e calcola il contrasto WCAG
dei token di testo. Nessuna dipendenza esterna.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CSS_PATH = ROOT / "WEBhtml" / "assets" / "site.css"
GD_PATH = ROOT / "Godot" / "robloxwebengine" / "scripts" / "ui" / "rw_tokens.gd"

CSS_TOKEN_RE = re.compile(r"--(rw-[a-z0-9-]+)\s*:\s*([^;]+);")
GD_CONST_RE = re.compile(r"^\s*const\s+([A-Z][A-Z0-9_]*)\s*:=\s*(.+?)\s*$", re.MULTILINE)
HEX_RE = re.compile(r"^#([0-9a-fA-F]{3,8})$")
RGB_RE = re.compile(r"^rgba?\(([^)]+)\)$")

# Token CSS -> costante GDScript per le misure non coperte da prefissi.
SPECIAL_NAMES = {
    "rw-content": "SIZE_CONTENT",
    "rw-content-wide": "SIZE_CONTENT_WIDE",
    "rw-page-pad-y": "SIZE_PAGE_PAD_Y",
    "rw-page-pad-x": "SIZE_PAGE_PAD_X",
    "rw-header-height": "SIZE_HEADER_HEIGHT",
    "rw-footer-pad": "SIZE_FOOTER_PAD",
    "rw-card-width": "SIZE_CARD_WIDTH",
    "rw-card-thumb-width": "SIZE_CARD_THUMB_WIDTH",
    "rw-card-thumb-height": "SIZE_CARD_THUMB_HEIGHT",
    "rw-sidebar-width": "SIZE_SIDEBAR_WIDTH",
    "rw-radius": "SIZE_RADIUS",
    "rw-radius-tooltip": "SIZE_RADIUS_TOOLTIP",
    "rw-border-width": "SIZE_BORDER_WIDTH",
    "rw-line-height-body": "LINE_HEIGHT_BODY",
    "rw-z-header": "Z_HEADER",
    "rw-z-dropdown": "Z_DROPDOWN",
    "rw-z-modal": "Z_MODAL",
    "rw-z-toast": "Z_TOAST",
}

STRING_NAMES = {
    "rw-font-sans": "FONT_SANS",
    "rw-shadow": "SHADOW",
}

# Coppie di testo verificate a WCAG AA (4.5:1).
CONTRAST_PAIRS = [
    ("testo su canvas", "rw-color-text", "rw-color-canvas", 4.5),
    ("testo secondario su canvas", "rw-color-text-secondary", "rw-color-canvas", 4.5),
    ("testo attenuato su canvas", "rw-color-text-muted", "rw-color-canvas", 4.5),
    ("link su canvas", "rw-color-link", "rw-color-canvas", 4.5),
    ("bianco su CTA primaria", "rw-color-on-dark", "rw-color-primary", 4.5),
    ("bianco su CTA neutra", "rw-color-on-dark", "rw-color-neutral", 4.5),
    ("bianco su CTA negativa", "rw-color-on-dark", "rw-color-negative", 4.5),
    ("nav su header", "rw-color-nav-text", "rw-color-header", 4.5),
    ("“oppure” su header", "rw-color-or", "rw-color-header", 4.5),
    ("testo footer su footer", "rw-color-text-footer", "rw-color-footer", 4.5),
    ("legale footer su footer", "rw-color-text-footer-legal", "rw-color-footer", 4.5),
    ("errore su sfondo errore", "rw-color-danger", "rw-color-danger-bg", 4.5),
    ("info su sfondo info", "rw-color-info-border", "rw-color-info-bg", 4.5),
]

# Indicatore di focus: non è testo, quindi si riporta ma non è un gate AA testo.
FOCUS_PAIR = ("focus su canvas", "rw-color-focus", "rw-color-canvas")


def fail(message: str) -> None:
    print(f"ERRORE: {message}")


def parse_css_tokens(text: str) -> dict[str, str]:
    return {name: value.strip() for name, value in CSS_TOKEN_RE.findall(text)}


def parse_gd_constants(text: str) -> dict[str, str]:
    return {name: value.strip() for name, value in GD_CONST_RE.findall(text)}


def first_font_family(value: str) -> str:
    match = re.match(r'\s*(["\'])(.*?)\1', value)
    if match:
        return match.group(2)
    return value.split(",", 1)[0].strip().strip("\"'")


def parse_css_color(value: str) -> tuple[float, float, float, float] | None:
    value = value.strip().lower()
    hex_match = HEX_RE.match(value)
    if hex_match:
        raw = hex_match.group(1)
        if len(raw) == 3:
            raw = "".join(ch * 2 for ch in raw)
        if len(raw) == 4:
            raw = "".join(ch * 2 for ch in raw)
        if len(raw) == 6:
            raw += "ff"
        if len(raw) != 8:
            return None
        return (
            round(int(raw[0:2], 16) / 255, 3),
            round(int(raw[2:4], 16) / 255, 3),
            round(int(raw[4:6], 16) / 255, 3),
            round(int(raw[6:8], 16) / 255, 3),
        )
    rgb_match = RGB_RE.match(value)
    if rgb_match:
        parts = [part.strip() for part in rgb_match.group(1).split(",")]
        if len(parts) not in (3, 4):
            return None
        try:
            numbers = [float(part) for part in parts]
        except ValueError:
            return None
        alpha = numbers[3] if len(numbers) == 4 else 1.0
        return (
            round(numbers[0] / 255, 3),
            round(numbers[1] / 255, 3),
            round(numbers[2] / 255, 3),
            round(alpha, 3),
        )
    return None


def parse_gd_color(value: str) -> tuple[float, float, float, float] | None:
    value = value.strip()
    hex_match = re.fullmatch(r'Color\(\s*"(#[0-9A-Fa-f]{3,8})"\s*\)', value)
    if hex_match:
        return parse_css_color(hex_match.group(1))
    call_match = re.fullmatch(r"Color\(\s*([^)]+)\)", value)
    if not call_match:
        return None
    parts = [part.strip() for part in call_match.group(1).split(",")]
    if len(parts) not in (3, 4):
        return None
    try:
        numbers = [float(part) for part in parts]
    except ValueError:
        return None
    alpha = numbers[3] if len(numbers) == 4 else 1.0
    return (
        round(numbers[0] / 255 if numbers[0] > 1.0 else numbers[0], 3),
        round(numbers[1] / 255 if numbers[1] > 1.0 else numbers[1], 3),
        round(numbers[2] / 255 if numbers[2] > 1.0 else numbers[2], 3),
        round(alpha if alpha <= 1.0 else alpha / 255, 3),
    )


def parse_number(value: str) -> float | None:
    match = re.fullmatch(r"\s*(-?\d+(?:\.\d+)?)\s*(?:px|rem|em)?\s*", value)
    if not match:
        return None
    return float(match.group(1))


def gd_name_for_css(name: str) -> str | None:
    if name.startswith("rw-color-"):
        return "COLOR_" + name[len("rw-color-"):].upper().replace("-", "_")
    if name.startswith("rw-font-size-"):
        return "FONT_SIZE_" + name[len("rw-font-size-"):].upper().replace("-", "_")
    if name.startswith("rw-space-"):
        return "SIZE_SPACE_" + name[len("rw-space-"):].upper().replace("-", "_")
    return SPECIAL_NAMES.get(name)


def relative_luminance(color: tuple[float, float, float, float]) -> float:
    def channel(value: float) -> float:
        return value / 12.92 if value <= 0.03928 else ((value + 0.055) / 1.055) ** 2.4

    r, g, b, _ = color
    return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)


def contrast_ratio(
    foreground: tuple[float, float, float, float],
    background: tuple[float, float, float, float],
) -> float:
    light, dark = sorted(
        (relative_luminance(foreground), relative_luminance(background)),
        reverse=True,
    )
    return (light + 0.05) / (dark + 0.05)


def main() -> int:
    if not CSS_PATH.exists():
        fail(f"file CSS mancante: {CSS_PATH.relative_to(ROOT)}")
        return 2
    if not GD_PATH.exists():
        fail(f"file GDScript mancante: {GD_PATH.relative_to(ROOT)}")
        return 2

    css_tokens = parse_css_tokens(CSS_PATH.read_text(encoding="utf-8"))
    gd_constants = parse_gd_constants(GD_PATH.read_text(encoding="utf-8"))
    errors: list[str] = []
    checked = 0

    css_colors = {name: value for name, value in css_tokens.items() if name.startswith("rw-color-")}
    gd_colors = {name: value for name, value in gd_constants.items() if name.startswith("COLOR_")}

    for name in sorted(css_colors):
        gd_name = gd_name_for_css(name)
        checked += 1
        if gd_name not in gd_constants:
            errors.append(f"{name}: manca la costante GDScript {gd_name}")
            continue
        css_color = parse_css_color(css_colors[name])
        gd_color = parse_gd_color(gd_constants[gd_name])
        if css_color is None:
            errors.append(f"{name}: valore CSS non riconosciuto: {css_colors[name]}")
        elif gd_color is None:
            errors.append(f"{name}: valore GDScript non riconosciuto: {gd_constants[gd_name]}")
        elif css_color != gd_color:
            errors.append(
                f"{name}: CSS {css_colors[name]} != GDScript {gd_constants[gd_name]} "
                f"({css_color} vs {gd_color})"
            )

    for name in sorted(gd_colors):
        if name not in {gd_name_for_css(css_name) for css_name in css_colors}:
            errors.append(f"{name}: costante GDScript senza token CSS corrispondente")
            checked += 1

    for name, value in sorted(css_tokens.items()):
        gd_name = gd_name_for_css(name)
        if gd_name is None:
            continue
        if gd_name not in gd_constants:
            errors.append(f"{name}: manca la costante GDScript {gd_name}")
            checked += 1
            continue
        if name.startswith("rw-color-"):
            continue
        checked += 1
        if name in STRING_NAMES:
            css_string = first_font_family(value) if name == "rw-font-sans" else value
            gd_string = gd_constants[gd_name].strip().strip("\"'")
            if css_string != gd_string:
                errors.append(f"{name}: CSS {css_string!r} != GDScript {gd_string!r}")
            continue
        css_number = parse_number(value)
        gd_number = parse_number(gd_constants[gd_name])
        if css_number is None or gd_number is None:
            errors.append(f"{name}: valore numerico non riconosciuto")
        elif abs(css_number - gd_number) > 1e-6:
            errors.append(f"{name}: CSS {css_number} != GDScript {gd_number}")

    print(f"Token controllati: {checked}")
    print("Contrasto WCAG:")
    contrast_failed = False
    for label, fg_name, bg_name, minimum in CONTRAST_PAIRS:
        fg = parse_css_color(css_tokens.get(fg_name, ""))
        bg = parse_css_color(css_tokens.get(bg_name, ""))
        if fg is None or bg is None:
            errors.append(f"contrasto: token mancante per {label}")
            continue
        ratio = contrast_ratio(fg, bg)
        status = "OK" if ratio >= minimum else "FAIL"
        if ratio < minimum:
            contrast_failed = True
            errors.append(f"contrasto {label}: {ratio:.2f}:1 < {minimum:.1f}:1")
        print(f"  {label:<30} {ratio:>5.2f}:1  {status}")

    focus_fg = parse_css_color(css_tokens.get(FOCUS_PAIR[1], ""))
    focus_bg = parse_css_color(css_tokens.get(FOCUS_PAIR[2], ""))
    if focus_fg and focus_bg:
        ratio = contrast_ratio(focus_fg, focus_bg)
        print(f"  {FOCUS_PAIR[0]:<30} {ratio:>5.2f}:1  info (indicatore non testuale)")

    if errors:
        print("\nMismatch:")
        for error in errors:
            print(f"  - {error}")
        print(f"\n{len(errors)} errori: token CSS/GDScript non allineati.")
        return 1

    print("\nOK: token CSS e GDScript allineati, contrasto del testo AA.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
