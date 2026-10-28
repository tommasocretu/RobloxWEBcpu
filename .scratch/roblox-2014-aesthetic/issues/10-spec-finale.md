# Spec finale consolidata

Type: task
Status: resolved
Blocked by: 09

## Question

Assemblare le risoluzioni in `docs/roblox-2014/spec.md`: token, mappa pagine, specifica HUD, regole media, architettura Godot, piano di implementazione e verifica.

La spec include `tokens.md`, `site-map.md` e `GLOSSARY.md` come riferimenti canonici.

Verificare che:

- ogni decisione della mappa sia riflessa;
- non restino domande aperte o "da decidere";
- la spec sia autosufficiente per chi implementa senza rileggere i ticket;
- i riferimenti (screenshot, CSS archiviati) siano linkati.

Esito: spec pronta per l'handoff.

## Answer

Spec pronta e congelata il 28 ottobre 2026 in [`docs/roblox-2014/spec.md`](../../../docs/roblox-2014/spec.md).

**Consegna:**
- Documenti canonici spostati in `docs/roblox-2014/`: `spec.md`, `tokens.md`, `site-map.md`, `hud-client.md`, `media-rules.md`, `godot-theme.md`, `implementation-plan.md`, `acceptance.md`, `research/`, `prototype/`, `evidence/`.
- `GLOSSARY.md` committato alla root.
- La spec è organizzata in 16 sezioni: esito, riferimenti, lessico, token, chrome, pagine, media, tema/scale Godot, HUD/menu, play/handshake, invarianti, piano 10 PR, verifica, tracciabilità, change control, riferimenti.
- Il tracker resta in `.scratch/roblox-2014-aesthetic/`; `map.md` e i ticket puntano ai nuovi path.

**Verifica:**
- **Decisioni della mappa:** tutte le voci D01–D10 sono riflesse nella tabella di tracciabilità §14, con le note della mappa in §14.1.
- **Nessuna domanda aperta:** rimossi i residui “bozza/proposta/decisione del ticket” da token, HUD, tema e media; le incertezze della ricerca sono dichiarate come limiti storici chiusi nella spec. Nessun “da decidere”, TBD o TODO nei documenti canonici.
- **Autosufficienza:** la spec riporta perimetro, lessico, valori non negoziabili, misure, stati, copy, API HUD, handshake, invarianti, sequenza PR e gate; i documenti canonici restano come appendici per le tabelle complete.
- **Riferimenti linkati:** 133 link relativi verificati in 24 file (docs, GLOSSARY, tracker), tutti risolti; fonti esterne Wayback/CoreScripts/Fandom citate in §16.
- **Nessuna modifica a codice/server/API/DB:** il commit tocca solo `docs/` e `GLOSSARY.md`; `git diff cb1b2b6^ cb1b2b6 -- server/ Godot/ WEBhtml/` è vuoto.

**Commit:** `cb1b2b6` — `docs: consolidate Roblox 2014 aesthetic spec`.

Esito: handoff pronto; implementazione dalla PR 1 di [`implementation-plan.md`](../../../docs/roblox-2014/implementation-plan.md).
