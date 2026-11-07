# Thumbnail, card e media

Type: grilling
Status: resolved
Blocked by: 04, 05

## Question

Decidere il trattamento delle immagini nel look 2014. Accenti like/live/hidden approvati in `tokens.md`; qui si decide dove usarli.

Vincoli dal ticket 05: card 192×108 nel catalogo e 16:9 fluida nella home; media del dettaglio 500×281; hero 430×230; avatar 48 (autore) e 352 (profilo); placeholder a studs + iniziale; “N che giocano” testuale, niente pill live flottante; stella per i preferiti.

- rapporto card: **16:9** (verificato nel 2014; card 192×108, thumbnail attuali 512×288). Decidere composizione e crop, non il rapporto;
- composizione card: immagine, titolo, autore, visite/like, badge live;
- placeholder per chi non ha thumbnail;
- avatar: blocky 2014 ricreato in CSS/SVG vs colore attuale;
- immagini hero/featured e loro crop;
- eventuale piano di migrazione (ricrop lato server? nuovo formato thumbnail?).

Esito: regole media + impatto su server/thumbnail.

## Answer

Approvate tutte e sette le proposte il 28 ottobre 2026. Specifica completa in [`media-rules.md`](../../../docs/roblox-2014/media-rules.md).

- **Formato e crop:** master **512×288 16:9** (quello che Studio cattura già); upload max 1920×1080, 1 MB, PNG invariato. Tutti i contenitori usano `object-fit: cover` con centro; nessun crop server, nessuna `srcset`, niente WebP/AVIF.
- **Card:** colonna 202, thumb 192×108 bordo `#D2D2D2`, titolo 14/600 su una riga, meta su due righe fisse (autore + live verde; visite + stella oro), hover/focus con barra bianca `Gioca` 22 px, nessun lift/ombra. Live testuale, niente pillola; niente avatar nella card.
- **Placeholder:** cielo 2014 a due toni + prato `#3F8F3F` + stud bianchi + iniziale; 8 palette deterministiche; iniziale 46/84/76/40/18 px; fallback anche per immagini rotte. Niente placeholder server.
- **Avatar:** blocky R6 SVG derivato da `avatar_color` (testa/braccia gialle, torso colore utente, gambe scurite), fondo `#EEE` bordo `#CCC`; 48×48 autore e 352×352 profilo (200 sotto 480). Niente asset esterni.
- **Hero/sidebar/dettaglio:** hero 430×230 cover con badge `In evidenza · <titolo>` e link, nascosto se non ci sono giochi; sidebar 300×160 e 64×36; media dettaglio 500×281. Tutti con lo stesso placeholder.
- **Accenti:** stella preferiti oro `#FFD700`, live verde `#007001` testuale, badge Nascosta `#AA6611`; nessun altro accento, niente pillole.
- **Server/migrazione:** zero modifiche a server/API/DB; le thumbnail esistenti sono già 16:9, nessun re-upload; upload non 16:9 croppati in UI; immagini rotte gestite lato client.

Esito: regole media pronte per il piano (09).
