# Estetica Roblox 2014 — sito e client

## Destination

Una specifica di design eseguibile per il re-skin 2014 di sito e client di gioco: token visivi, mappatura superficie-per-superficie, asset/font e piano di implementazione a PR, tale che l'implementazione successiva non richieda altre decisioni di design.

## Notes

- Riferimento canonico: metà 2014, sito desktop + client desktop. L'utente non ha fornito screenshot; può aggiungerne in qualsiasi momento e il riferimento va aggiornato.
- Sito di metà 2014 = header **blu** `#114081` a 36 px, non l'header grigio `#343434` (presente nel CSS ma non attivo nei snapshot giugno–agosto 2014). Vedi il ticket "Riferimenti: sito Roblox metà 2014".
- Client di metà 2014 = **nessuna topbar** (arriva il 23/04/2015): Menu a scudo in basso a sinistra, chat in alto a sinistra, player list in alto a destra, backpack 9 slot, health 170×18, Game Menu nero/rosso fino al 27/08/2014. Vedi il ticket "Riferimenti: client Roblox metà 2014".
- Fedeltà: pelle 2014 sui layout e sulle funzioni attuali (M1–M5 restano). Non è un clone strutturale 1:1 delle pagine 2014.
- Identità: "RobloxWeb" originale in stile 2014. Niente logo o asset Roblox reali; font open source (Source Sans 3 al posto di Source Sans Pro).
- Responsive: densità 2014 sopra i 1000px; sotto, degradazione semplice e dignitosa, senza inventare una UI mobile 2014.
- Il sito resta in italiano: il lessico 2014 va adattato, non tradotto in inglese.
- L'utente ha accettato in blocco i consigli sulla destinazione; continuare a proporre una raccomandazione esplicita a ogni decisione.
- Skill: `grilling` + `domain-modeling` per i ticket di design; `research` per i pacchetti di riferimento; `prototype` per il prototipo. Aggiornare `GLOSSARY.md` se cambia il lessico del dominio.
- Tracker: local markdown. Mappa qui; ticket in `issues/NN-<slug>.md`; frontier = primo ticket aperto, non bloccato, non reclamato.
- Il livello di gioco, il server, le API e il formato livello non cambiano: è un effort di sola UI/UX visiva.

## Decisions so far

- [Riferimenti: sito Roblox metà 2014](issues/01-riferimenti-sito-2014.md): header blu `#114081` 36 px, colonna 970 px, Source Sans Pro 14 px/1.428, link `#0055B3`, CTA verdi/blu; CSS e snapshot citati in `docs/roblox-2014/research/sito-2014.md`.
- [Riferimenti: client Roblox metà 2014](issues/02-riferimenti-client-2014.md): niente topbar (arriva nel 2015), Menu a scudo in basso a sinistra, chat 12 px in alto a sinistra, player list 150 px in alto a destra senza avatar, backpack 9×54 px, health 170×18, Game Menu nero/rosso; dettagli in `docs/roblox-2014/research/client-2014.md`.
- [Prototipo: home e HUD in stile 2014](issues/03-prototipo-home-hud.md): scelte **home B** (1180, hero, 4 colonne, senza sidebar) e **client B** (topbar HTML + HUD 2014 dentro); catalogo a 970 + sidebar; chat in alto a sinistra, monete nella player list, Game Menu nero/rosso; prototipo archiviato in `docs/roblox-2014/prototype/`.
- [Token, tipografia e accessibilità](issues/04-token-tipografia-accessibilita.md): tabella approvata in `docs/roblox-2014/tokens.md` — Source Sans 3 14 px, header `#114081`, 970/1180, squadrato e senza ombre, 7 deviazioni di accessibilità, CSS + mirror GDScript + checker.
- [Mappatura del sito: chrome, pagine, dialoghi](issues/05-chrome-pagine-sito.md): `games.html` 970+sidebar + home B 1180; login 2 colonne, profilo 2 colonne con tab, admin a tabelle, modali 2014; lessico Giochi/Preferiti/che giocano (vedi `GLOSSARY.md`); header senza search globale; nessuna feature 2014 finta.
- [HUD e widget del client](issues/06-hud-widget-client.md): specifica in `docs/roblox-2014/hud-client.md` — barra HTML 36 px, chat 500×120 con 8 righe/45 s, player list 202 px con monete solo locali, salute 170×18, Menu a scudo, Game Menu nero/rosso 525×430, Leave 525×300, Reset 525×370, banner traguardo 525×80, niente backpack/toast, FPS solo su F3, scala `clamp(…, 0.8, 1.0)`.
- [Thumbnail, card e media](issues/07-thumbnail-card-media.md): regole in `docs/roblox-2014/media-rules.md` — master 512×288 16:9, card 202/192×108 con meta a 2 righe, placeholder cielo/prato/stud/iniziale, avatar blocky SVG da `avatar_color`, hero 430×230, sidebar 300×160/64×36, dettaglio 500×281, stella oro/live verde, nessuna modifica server.
- [Architettura del tema Godot](issues/08-architettura-tema-godot.md): specifica in `docs/roblox-2014/godot-theme.md` — `Theme` runtime da `rw_tokens.gd` in `themes/rw_theme.gd`, varianti `Rw*`, font TTF Source Sans 3 + Liberation Sans, `StyleBoxFlat` e scudo in `_draw`, HUD/Game Menu/banner/debug soltanto, client `CONTENT_SCALE_MODE_DISABLED` + design space `viewport/s` e scala 0.8–1.0, test headless strutturali.
- [Piano di implementazione e verifica](issues/09-piano-implementazione-verifica.md): piano in `docs/roblox-2014/implementation-plan.md` + checklist in `docs/roblox-2014/acceptance.md` — 10 PR foundation-first su branch `aesthetic-2014`, merge finale atomico senza flag; gate fast per PR e full finale; harness a iframe + gallery Godot, niente golden images; fixture su data dir temporanea; checker in `tools/`, `tools/verify.sh` e `tools/export_web.sh`; copy server-origin tradotta lato client; docs canoniche in `docs/roblox-2014/`; spec congelata con change control a ticket.
- [Spec finale consolidata](issues/10-spec-finale.md): [`docs/roblox-2014/spec.md`](../../docs/roblox-2014/spec.md) — tutte le decisioni D01–D10 riflesse, nessuna domanda aperta, riferimenti linkati; documenti canonici in `docs/roblox-2014/`, `GLOSSARY.md` alla root.

## Not yet specified

<!-- Nessun punto in sospeso: tutti i ticket sono resolved e la spec è congelata in docs/roblox-2014/spec.md. -->

**Stato:** handoff pronto. La frontier è chiusa; l'implementazione parte dalla PR 1 di
[`docs/roblox-2014/implementation-plan.md`](../../docs/roblox-2014/implementation-plan.md).
**Commit documenti:** `cb1b2b6` (spec, documenti canonici, ricerca, prototipo, `GLOSSARY.md`).

## Out of scope

- Implementare feature 2014 assenti oggi (Tix, Builders Club, catalogo, forum, party): solo estetica, nessuna parità funzionale.
- Studio desktop/editor, start screen di Studio e build nativa dev (`LevelSelect`, `Menu`).
- UI mobile/touch del 2014.
- Modifiche a gameplay, livello, server, API, relay.
- Asset e logo Roblox reali: identità originale RobloxWeb.
