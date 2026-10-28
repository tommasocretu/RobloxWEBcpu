# RobloxWEBcpu

Stato del progetto basato su [`PLAN.md`](PLAN.md).

## Avanzamento piano (spunte fatto / non fatto)

- [x] **M0 — Piattaforma minima**: server HTTP+WS+SQLite, sito base, client web su place, relay per stanza.
- [x] **M1 — Autori e pubblicazione**: ownership, versioni, pubblicazione da editor, thumbnail, profili, contatori live.
- [x] **M2 — Studio desktop**: build Studio Win/Linux, start screen, login/offline, place browser, publish dialog completo.
- [x] **M3 — Lua sandbox**: VM Lua sandboxata, API Roblox-like, scheduler/limiti, formato livello v2, pannelli Script/Output.
- [ ] **M4 — Scoperta**: ricerca/ordinamento, like, profili/versioni avanzate, rollback/visibilità estesa.
- [ ] **M5 — Robustezza**: hardening pre-deploy (config, backup, rate limit, logging, setup TLS di esempio).

## Stato sintetico

- Stato ufficiale del piano (28 ottobre 2026): **M0, M1, M2 e M3 completati e verificati**.
- Prossima milestone indicata nel piano: **M4 — Scoperta**.
- La place **Demo script** (`levels/scripts_demo.rwl.json`) mostra Lua in azione: porta con
  `Touched`, piattaforma rotante, lava e teletrasporto; in Studio i pannelli **Script** e
  **Output** permettono di modificare ed eseguire gli script.
