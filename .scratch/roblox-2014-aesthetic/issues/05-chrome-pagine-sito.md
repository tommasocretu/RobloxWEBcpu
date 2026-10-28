# Mappatura del sito: chrome, pagine, dialoghi

Type: grilling
Status: resolved
Blocked by: 01, 02, 03, 04

## Question

Mappare il re-skin 2014 dell'intero sito, pagina per pagina e stato per stato, mantenendo le funzioni M1–M5. Vincolo dal prototipo: **home B** (1180, hero, 4 colonne 16:9, senza sidebar); pagine catalogo a **970 + sidebar**; lessico 2014 in italiano. Token approvati in `tokens.md`: usare i token, non valori hardcoded.

- chrome globale: header, nav, ricerca, menu account, footer;
- home: hero, filtri, ordinamento, griglia, badge live;
- pagina gioco: thumbnail, titolo/autore, like, segnala, visite/live;
- play: cornice della pagina e coordinamento con il client (la sorte dell'attuale top bar HTML è decisa nel ticket HUD/widget);
- profilo (proprio e pubblico), login/registrazione, admin, studio.html;
- dialoghi: modifica, versioni/rollback, segnala, conferme;
- stati vuoti, errore, caricamento, 403/404;
- responsive: cosa succede sotto i 1000px.

Decidere anche il lessico 2014 in italiano ("Giochi" vs "Esperienze", "Gioca", "Crea", "Catalogo") e se usare motivi decorativi 2014 non funzionali. Annotare i termini nel `GLOSSARY.md` se cambiano il modello.

Esito: mappa pagina-per-pagina con deviazioni motivate.

## Answer

Approvate tutte e quattro le proposte il 28 ottobre 2026. Mappa completa in [`site-map.md`](../../../docs/roblox-2014/site-map.md).

- **Pagina Giochi:** si crea `games.html` a 970+sidebar (griglia 3×202 con card 192×108, sidebar 300 con “In evidenza”, “Più giocati” e “Crea il tuo gioco”, tutti dati reali). La home B (1180, hero, 4 colonne) resta la landing con 8 giochi e “Vedi tutti” → `games.html`. La ricerca globale esce dall'header e vive nel catalogo: `games.html?q=&sort=`. Niente filtri Tempo/Genere finti e niente paginazione (l'API restituisce tutti i giochi): deviazioni dichiarate.
- **Pagine interne:** login a due colonne 465+484 senza tab; profilo a due colonne (avatar 352 + statistiche `#EEE` a sinistra, tab verticali Giochi/Preferiti a destra, card 2 colonne); admin a tabelle 2014 impilate; conferme con modale 2014 invece di `confirm()`; place 500+240 con box “Accedi per giocare” per gli anonimi; play con barra blu 36 px e barra di caricamento `#D2D400`; studio a box 2014.
- **Vocabolario:** “Giochi/gioco” nell'interfaccia, “Preferiti” (UI) per `like` (API), “N che giocano” per online; “esperienza” resta dominio/marketing, “place” resta API. Glossario creato in [`GLOSSARY.md`](../../../GLOSSARY.md).
- **Chrome:** header blu 36 px senza search globale; nav Home/Giochi/Studio/Profilo(+Moderazione); footer blu con soli link reali e anno 2026; ospite in header e login; niente Tix/Builders Club/catalogo merci/forum/notizie/top creatori finti.
- **Fuori:** nessuna modifica a server/API/DB. `games.html` è una pagina statica che riusa `/api/places`.

Esito: mappa pagina-per-pagina approvata, pronta per HUD (06), media (07), tema Godot (08) e piano (09).
