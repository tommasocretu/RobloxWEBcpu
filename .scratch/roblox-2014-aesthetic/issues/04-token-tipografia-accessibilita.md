# Token, tipografia e accessibilità

Type: grilling
Status: resolved
Blocked by: 01, 02, 03

## Question

Fissare il sistema visivo canonico del re-skin. Base scelta dal prototipo: **home B** (1180, hero, 4 colonne) e **client B** (topbar HTML + HUD 2014); i token devono coprire entrambi.

- palette e ruoli colore (surface, text, muted, link, primary, danger, success, warning, border, overlay);
- type scale (famiglia, pesi, px/rem, line-height) per sito e client;
- spaziature, bordi, radii, ombre, densità;
- stati hover/active/focus/disabled e focus ring;
- font: Source Sans 3 self-hosted (woff2) per il web e TTF per Godot; fallback;
- contrasto e target minimi, senza tradire il look 2014;
- dove vivono i token (CSS custom properties + Godot Theme) e come restano sincronizzati.

Esito: tabella token definitiva + policy font/accessibilità.

## Answer

Tabella approvata il 28 ottobre 2026 in [`tokens.md`](../../../docs/roblox-2014/tokens.md).

**Scelte:**
- **Font legacy client:** Liberation Sans (OFL, metric-compatibile con Arial) per Game Menu, player list e backpack; Source Sans 3 per chat, health, messaggi e tutto il sito.
- **Accessibilità:** tutte e 7 le deviazioni approvate — testo attenuato `#767676`, footer `#C7CFDD` / legalese `#AFC0D8`, focus ring 2 px `#00A1DA`, link sottolineati solo nei paragrafi, target minimo 24×24, `prefers-reduced-motion`, badge con testo. Hover 120 ms, nessun transform.
- **Sincronizzazione:** `:root` in `WEBhtml/assets/site.css` come fonte canonica, `rw_tokens.gd` come mirror Godot, `tools/check_design_tokens.py` confronta il sottoinsieme condiviso e fallisce con un diff.
- **Resto della tabella confermato:** palette 2014, type scale, 970 catalogo + sidebar 300, home 1180, header 36, angoli squadrati, niente ombre.

**Valori chiave:** header `#114081`, footer `#123F83`, testo `#343434`, link `#0055B3`, primario `#007001`, neutro `#0852B7`, focus `#00A1DA`; Source Sans 3 body 14/1.428, h1 32/700, h2 30/400, nav 15/600; client chat 12, health 14, menu 36/24/18; health `#25B230`→`#004F00`; menu default `#C1272D`.

**Font:** Source Sans 3 woff2 300/400/600/700 self-hosted per il web e TTF per Godot; Liberation Sans Regular/Bold solo per i label legacy del client. Includere le licenze OFL.

Esito: tabella token definitiva + policy font/accessibilità, pronta per i ticket 05/06/08.
