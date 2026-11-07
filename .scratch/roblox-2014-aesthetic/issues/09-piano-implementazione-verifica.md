# Piano di implementazione e verifica

Type: grilling
Status: resolved
Blocked by: 04, 05, 06, 07, 08

## Question

Decidere come si arriva dalla spec al codice:

- sequenza di PR (sito, client, asset, docs) e dimensioni;
- cosa è riusabile subito vs cosa richiede migrazione (thumbnail, topbar);
- checklist di accettazione per pagina/stato e per widget;
- harness di verifica visiva: browser tool + screenshot manuali, golden images, o altro;
- test esistenti da preservare (`server/tests`, `tools/test_*.gd`) e nuovi controlli;
- rollback/feature flag, se servono.

Esito: piano PR-sized + checklist di verifica.

Vincolo dal ticket 04: il piano include `tools/check_design_tokens.py` e la verifica di contrasto/focus. Dal ticket 05: il piano include `games.html` e le ristrutturazioni di login/profilo/admin, i modali 2014 e il glossario; nessuna modifica a server/API/DB.

## Answer

Piano approvato il 28 ottobre 2026 in [`implementation-plan.md`](../../../docs/roblox-2014/implementation-plan.md), con la checklist in [`acceptance.md`](../../../docs/roblox-2014/acceptance.md).

**Scelte:**
- **Consegna:** foundation-first in 10 PR su un branch di integrazione `aesthetic-2014`, PR reali su GitHub con base quel branch, merge finale atomico `aesthetic-2014` → `main` con merge commit; nessun feature flag. Rollback = revert del merge.
- **Ordine:** fondamenta sito (token/font/checker) → design system (chrome, card/media, avatar, dialoghi) → home + `games.html` → dettaglio → pagine account → fondamenta tema Godot → HUD → Game Menu/Leave/Reset → barra `play.html`/handshake/export → documentazione e chiusura.
- **Gate:** fast su ogni PR (test Python, `check_design_tokens.py`, `check_site_content.py`, test Godot toccati, screenshot delle superfici cambiate); full solo sull'integrazione finale (tutti i test Godot, `test_network`/`test_publish`/`test_studio`, export Web, matrice completa, smoke `play.html`).
- **Verifica visiva:** harness del sito con iframe a larghezza fissa in `WEBhtml/dev/visual-matrix.html` e screenshot browser; gallery Godot dev-only `tools/hud_gallery.gd` con PNG generati; **niente golden images**. Fixture deterministiche su data dir temporanea (`tools/visual_fixtures.py`).
- **Matrice:** pagine a 1440/700, breakpoint mirati a 1180/1000/480; HUD a 1680×964 e 640×364 per tutti gli stati, HUD base anche a 1280/1024/800.
- **Evidenze:** screenshot before/after nelle PR; set completo in `.scratch/.../evidence/` non versionato; contact sheet finali in `docs/roblox-2014/evidence/`; sign-off umano su contact sheet + acceptance.
- **Test e tooling:** checker Python in `tools/` alla root; `tools/verify.sh --fast|--full`; `tools/export_web.sh`; `tools/visual_fixtures.py`; `tools/test_theme.gd` e `tools/test_hud.gd`. Nessun runner Node e nessuna CI nuova.
- **Client:** scene HUD/Game Menu/Banner/Debug scritte a mano; `tools/generate_scenes.gd` smette di rigenerare l'HUD. Tema runtime `RwTheme`, `RwLayout`, font TTF preloadati, content scaling disabilitato solo nel client.
- **Copy:** server intatto; `RW.localizeServerMessage()` traduce lato client i messaggi noti (“esperienze” → “giochi”, “like” → “preferiti”) con fallback per status.
- **Accessibilità:** gate Lighthouse solo su audit oggettivi (contrasto, label, link/button name, lang, title, viewport), non sul punteggio; verifica da tastiera manuale.
- **Docs:** documenti canonici in `docs/roblox-2014/`, `GLOSSARY.md` alla root, tracker in `.scratch/`; `AGENTS.md` aggiornato nella PR finale; nessun M6 in `PLAN.md`, nessuna modifica a `server/README.md`.
- **Change control:** spec congelata; ogni scostamento visivo/UX passa da un nuovo ticket in `issues/` e da un aggiornamento di `map.md`.

**Rischi principali gestiti:** la PR 2 è la più ampia (split interno se >~1200 righe); `play.html` non aspetta `rw-ready` prima della PR 9; il generatore scene non sovrascrive più l'HUD; i font sono preloadati per l'export Web; le fixture usano data dir temporanea.

Esito: piano PR-sized e checklist di verifica pronti per il ticket 10.
