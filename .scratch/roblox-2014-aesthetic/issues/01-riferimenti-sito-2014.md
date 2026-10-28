# Riferimenti: sito Roblox metà 2014

Type: research
Status: resolved
Blocked by: —

## Question

Ricostruire i valori visivi del sito Roblox di metà 2014, da fonti primarie archiviate, per fondare i token del re-skin:

- palette esatta (hex) di header/nav, sfondo, testo, link, bordi, bottoni, badge;
- tipografia (famiglia, pesi, dimensioni, line-height);
- larghezza pagina/griglia, spaziature, altezze header/footer;
- componenti: nav, search, bottoni primari/secondari, input, card gioco, tabelle, tab, dialoghi/modali, paginazione, badge (Builders Club, Tix/Robux), avatar;
- struttura delle pagine chiave: home, giochi, pagina gioco, login, profilo;
- link a screenshot archiviati e CSS originali (Wayback Machine), con data dello snapshot.

Vincoli: niente asset Roblox da spedire; il deliverable è un documento di riferimento con URL e valori, non un pacchetto di asset. Distinguere ciò che è verificato da ciò che è inferito.

Deliverable: `docs/roblox-2014/research/sito-2014.md`.

## Answer

Ricostruzione completa in [`docs/roblox-2014/research/sito-2014.md`](../../../docs/roblox-2014/research/sito-2014.md) (fonti: snapshot Wayback 13 giu 2014 + CSS originali `FetchCSS`; ogni valore ha URL e data, con marca V/I/U).

**Palette.** Header `#114081` (36 px, fisso, con sprite `bg-rbx_header.png`), footer `#123F83`, canvas bianco `#FFFFFF`, testo `#343434`, link `#0055B3` (hover solo underline), link secondario `#095FB5`, bordi `#CCCCCC` / input `#A7A7A7` / controllo `#777777`, CTA verde `#007001`, blu `#0852B7`, grigia `#565656`, selection `#00A1DA`, Robux `#006600`, Tix `#AA6611`, errore `#FAE5E5` + `#CC0000`.

**Tipografia.** `'Source Sans Pro', Arial, Helvetica, sans-serif` (pesi 300/400/600/700 via Google Fonts); body 14 px / 1.428; h1 32/700/−1 px; h2 30/400/−1 px; h3 15/700; nav 15/600; CTA 14–23 px; modale 27/700.

**Layout.** Colonna 970 px, header 36 px + spacer 36 px, `#Body` padding 5/25, footer blu a 970. Games: 3 card da 192×108 (colonna 202) + sidebar 330. Dettaglio gioco 500+240. Login 465+484. Profilo: avatar 352, blurb 348, tab verticali 35 px.

**Componenti.** Due sistemi di bottoni (`.btn-control` grigio 18/21/25 px e `.btn-small/medium/large` 20/28/39 px); input `.text-box` 18/21/25; card gioco 192×108 con hover box `#888`; tab `#D6D6D6`/`#E9E9E9`/bianco; modali 27 px; pager 27×27; badge Robux/Tix; avatar 352/48/100; tooltip nero.

**Avvertenza chiave.** A giugno 2014 il sito usa l'header **blu** `#114081`, non il grigio `#343434` da 50 px: quel `header-2014` esiste già nel CSS ma non è attivo su nessuna pagina catalogata tra giugno e agosto (diventa la landing diversa a novembre). Non va usato come riferimento «metà 2014».

**Incertezze.** Non campionati i colori di gradienti/hover in sprite PNG (header, hover nav, hover CTA); overlay modali non dichiarato; nessun badge BC autonomo; il profilo è verificato al 18 luglio 2014. Dettagli e link rappresentativi nella §8 del documento.
