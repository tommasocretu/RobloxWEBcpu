# Prototipo: home e HUD in stile 2014

Type: prototype
Status: resolved
Blocked by: 01, 02

## Question

Costruire un prototipo usa-e-getta, ad alta fedeltà solo quanto basta, per far reagire l'umano al look 2014 prima di fissare i token:

- una home statica (HTML/CSS, dati finti) con header, ricerca, griglia giochi, card, footer;
- un mock del client con menu a scudo in basso a sinistra, chat in alto a sinistra, player list in alto a destra, health/monete, notifica e Game Menu su Esc (senza topbar: nel 2014 non esiste);
- varianti strutturali a confronto: home A (griglia 2014 + sidebar), B (home attuale 1180 con pelle 2014), C (vetrina + griglia); client A (fedele, senza topbar), B (ibrido con topbar HTML), C (HUD attuale ridipinto).

Il prototipo non entra in produzione e non tocca `WEBhtml/` né le scene reali: vive in `docs/roblox-2014/prototype/` (archiviato come riferimento). Serve a decidere palette, tipografia, densità e iconografia con l'umano.

Prototipo costruito: [`docs/roblox-2014/prototype/`](../../../docs/roblox-2014/prototype/README.md) (`index.html`, `home.html`, `client.html`), servito con `python3 -m http.server 9090`. Le varianti di header scuro e card 4:3 sono state scartate dalla ricerca: metà 2014 è header blu e card 16:9.

## Answer

Prototipo costruito, aperto nel browser e provato su tutte e tre le varianti. Apre sulla variante B; A e C restano per confronto.

**Scelte dell'utente:**
- **Home: B** — 1180 px, hero, 4 colonne 16:9, senza sidebar. La densità 970 + sidebar resta per le pagine catalogo (Giochi), non per la home.
- **Client: B** — topbar HTML blu 36 px (titolo/autore/giocatori/Esci) come chrome del sito, più HUD 2014 dentro il canvas.
- **Dettagli confermati:** chat in alto a sinistra (500×120, 12 px, senza sfondo), monete come colonna della player list, Game Menu nero/rosso 525×430 con “Resta” come default e flusso a due passi Esc → Esci → conferma.
- **Vincolo di fedeltà:** la topbar in-game 2014 non esiste; la B la tiene solo fuori dal CanvasLayer, nell'HTML di `play.html`. Dentro il gioco niente topbar finta.

**Cosa ha funzionato:** header blu 36 px, card 192×108, player list senza avatar, chat con outline e nomi colorati, menu nero/rosso, due passi per uscire.

**Punti chiusi dai ticket 04–09:** thumbnail e placeholder in [`media-rules.md`](../../../docs/roblox-2014/media-rules.md), scaling HUD e topbar HTML in [`hud-client.md`](../../../docs/roblox-2014/hud-client.md), self-host del font in [`tokens.md`](../../../docs/roblox-2014/tokens.md); il backpack non si mostra perché non esistono tool.

**Verdetto:** il prototipo risponde alla domanda; A e C non sono scelte. La spec userà B come base per home e client.

Esito: prototipo linkato + note su cosa ha funzionato e cosa no.
