# RobloxWEBcpu

Stato del progetto basato su [`PLAN.md`](PLAN.md).

## Avanzamento piano (spunte fatto / non fatto)

- [x] **M0 — Piattaforma minima**: server HTTP+WS+SQLite, sito base, client web su place, relay per stanza.
- [x] **M1 — Autori e pubblicazione**: ownership, versioni, pubblicazione da editor, thumbnail, profili, contatori live.
- [x] **M2 — Studio desktop**: build Studio Win/Linux, start screen, login/offline, place browser, publish dialog completo.
- [x] **M3 — Lua sandbox**: VM Lua sandboxata, API Roblox-like, scheduler/limiti, formato livello v2, pannelli Script/Output.
- [x] **M4 — Scoperta**: ricerca/ordinamento, like ed elenco personale, profili autore con avatar/statistiche, storico versioni con rollback, segnalazioni e restrizioni ospite complete.
- [ ] **M5 — Robustezza**: hardening pre-deploy (config, backup, rate limit, logging, setup TLS di esempio).

## Stato sintetico

- Stato ufficiale del piano (28 ottobre 2026): **M0, M1, M2, M3 e M4 completati e verificati**.
- Prossima milestone indicata nel piano: **M5 — Robustezza**.
- La place **Demo script** (`levels/scripts_demo.rwl.json`) mostra Lua in azione: porta con
  `Touched`, piattaforma rotante, lava e teletrasporto; in Studio i pannelli **Script** e
  **Output** permettono di modificare ed eseguire gli script.
- Il sito ora permette di cercare per titolo/autore, ordinare per like, mettere like,
  vedere i profili con avatar e statistiche, ripristinare una versione precedente e
  segnalare un contenuto; gli ospiti restano limitati a giocare.
