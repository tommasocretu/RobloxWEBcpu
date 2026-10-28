# Thumbnail, card e media — regole 2014

> Documento canonico della [specifica consolidata](spec.md).
> Base: `tokens.md`, `site-map.md` §2.3, prototipo client/home (`prototype/`), `research/sito-2014.md` §6.5/§6.11/§7.
> **Approvato il 28 ottobre 2026.** Le decisioni sono chiuse e confluite nella spec.

## 1. Perimetro e principi

1. **Il rapporto è 16:9**, non si discute: thumbnail master **512×288**, card 192×108, home fluida 16:9, dettaglio 500×281, sidebar 300×160 e 64×36, hero 430×230.
2. **Nessuna distorsione.** Tutte le immagini usano `object-fit: cover` con `object-position: center`; il crop è sempre centrale e avviene nella UI, non sul server.
3. **Niente immagini finte.** Se manca la thumbnail si mostra un placeholder originale a stud + iniziale; non si usano screenshot o asset Roblox.
4. **La card è un link unico**: immagine, titolo e meta sono un solo `<a>`; niente link annidati (l'autore nella card non è cliccabile).
5. **Niente ombre, radius o lift.** Bordo 1 px, sfondo bianco, squadrato. L'unica animazione è la barra `Gioca` in hover/focus.
6. **Il colore non è decorazione.** Oro = preferiti, verde = live, warning = Nascosta; tutto il resto è `#343434`/`#666`/`#767676`.
7. **Zero modifiche a server, API, DB o formato thumbnail.** Le thumbnail esistenti sono già 16:9.

## 2. Formato, crop e caricamento

| Elemento | Regola |
|---|---|
| Master | 512×288 PNG, quello che Studio cattura già (`THUMBNAIL_SIZE`) |
| Upload server | max 1 MB, max 1920×1080, PNG; invariato |
| Card | 192×108 esatti (catalogo/profilo); 16:9 fluido (home) |
| Dettaglio | 500×281 (16:9) |
| Hero | 430×230, `cover` center (ritaglio ~12 px verticale da un 16:9) |
| Sidebar featured | 300×160, `cover` center |
| Sidebar “Più giocati” | 64×36, `cover` center |
| Crop | sempre `object-fit: cover; object-position: center`; nessun `object-position` custom |
| Upscale | il 512 copre la card a 2× (384) e dettaglio/hero a 1×; su retina questi ultimi possono essere upscalati, niente `srcset` |
| Loading | card `loading="lazy" decoding="async"`; hero e dettaglio `loading="eager"` |
| Cache | `thumbnail_url` con `?v=<versione>` già fornito dall'API |

- Se l'immagine è più grande di 512×288, viene ridotta dal browser; non si serve una variante.
- Il master 512×288 è sufficiente per le card anche a 2× (384×216); dettaglio (500) e hero (430) sono coperti a 1×. Su schermi 2× possono risultare leggermente morbidi: è il compromesso accettato per non cambiare il formato di Studio.
- Se l'immagine non è 16:9, viene croppata in UI; non viene rifiutata dal server.
- Non si aggiungono formati WebP/AVIF né resize/crop lato server in questo effort.
- `thumbnail_url` resta l'unica fonte; niente placeholder server o endpoint nuovo.

## 3. Card

### 3.1 Struttura e misure

```
┌──────────────────────┐  202 px di colonna
│ thumb 192×108        │  1 px #D2D2D2, cover
│                      │
│         [Gioca]      │  barra hover 22 px
├──────────────────────┤
│ Titolo               │  14/600, una riga, ellissi
│ di autore · 3 che giocano │  12, verde il live
│ 1.234 visite · ★ 12  │  12, stella oro
└──────────────────────┘
```

| Proprietà | Valore |
|---|---|
| Colonna catalogo | 202 px (3 colonne in 610) |
| Thumb catalogo/profilo | 192×108, bordo 1 px `--rw-color-thumb-border` `#D2D2D2` |
| Home | 4 colonne fluide, thumb 16:9, gap 18×16 |
| Profilo | 2 colonne 202, thumb 192×108 |
| Card | nessun bordo/sfondo/ombra/radius; padding `0 10px 8px 0` |
| Titolo | 14/600, `--rw-color-text`, una riga, ellissi |
| Meta | 12 px, due righe fisse da 15 px, `--rw-color-text-secondary` `#666` |
| Riga 1 | `di <autore>` +, se live > 0, ` · <N> che giocano` in `--rw-color-live` `#007001` |
| Riga 2 | `<N> visite · ★ <N>`; stella `--rw-color-like-icon` `#FFD700`, numero `#666` |
| Ellissi | entrambe le righe `nowrap`, `overflow:hidden`, `text-overflow:ellipsis` |
| Autore nella card | testo, non link (la card è già un link) |
| Avatar nella card | **non esiste** |

- La riga live non è una pillola e non sta sopra la thumbnail: è testo nella meta.
- Il live non fa crescere la card: le due righe hanno altezza fissa; se il testo non ci sta, ellissi.
- La stella è decorativa; il numero è leggibile. `aria-label="<N> preferiti"` sul blocco preferiti.
- Se `live_players` è 0, la parte live sparisce e resta `di <autore>`.
- Se la card è nel profilo owner, badge visibilità/versione seguono il ticket 05; la thumb resta 192×108.

### 3.2 Hover e focus

- Hover o `:focus-visible` sul link della card:
  - barra bianca `Gioca` alta **22 px** in fondo alla thumb;
  - bordo superiore 1 px `--rw-color-border-strong` `#777777`;
  - testo `Gioca` 12 px `--rw-color-text-muted` `#767676` (il prototipo usava `#888`, ma il token passa il contrasto);
  - `bottom: -22px → 0`, `opacity: 0 → 1`, 120 ms; con `prefers-reduced-motion` nessuna transizione.
- Il titolo si sottolinea su hover/focus.
- Focus ring 2 px `#00A1DA` con offset 1 sul link della card.
- Nessun `transform`, nessuna ombra, nessun cambio di bordo della card.
- Su touch la barra non compare; il link funziona normalmente.

### 3.3 Griglie

| Contesto | Griglia |
|---|---|
| Home B | `repeat(4, 1fr)`, gap `18px 16px`, thumb fluida 16:9 |
| Giochi (catalogo) | `repeat(3, 202px)`, column-gap 2, row-gap 12 |
| Profilo (Giochi/Preferiti) | 2 colonne 202 nella colonna destra |
| Placeholder | stessa griglia, thumb con placeholder |

- Sotto 1000 px: 2 colonne; sotto 700: 1 colonna (ticket 05).
- La card non ha altezza fissa: thumb + titolo + due righe meta.

### 3.4 HTML di riferimento

```html
<article class="card" data-place-card="42">
  <a class="card-link" href="/place.html?id=42">
    <div class="card-thumb" style="--thumb-a:#7EC8E3;--thumb-b:#2B6CB0">
      <span class="thumb-initial" aria-hidden="true">W</span>
      <img src="/thumbs/42.png?v=3" alt="" loading="lazy" decoding="async"
           onerror="this.remove()">
      <span class="play-hover" aria-hidden="true">Gioca</span>
    </div>
    <h3 class="card-title">Welcome Obby</h3>
    <div class="card-meta">
      <div class="card-meta-line card-author">
        di RobloxWeb <span class="live-count" data-live-text="1">· 3 che giocano</span>
      </div>
      <div class="card-meta-line card-stats">
        1.234 visite · <span class="like-count" aria-label="12 preferiti"><span class="star">★</span> 12</span>
      </div>
    </div>
  </a>
</article>
```

- Se manca la thumbnail, l'`<img>` non viene emesso; il placeholder resta.
- Se l'immagine è rotta, `onerror` la rimuove e il placeholder resta.
- Se live è 0, lo `<span class="live-count">` non viene emesso.
- Il placeholder è sempre sotto l'immagine, così non c'è flash bianco durante il caricamento.

## 4. Placeholder

### 4.1 Strati

1. cielo: gradiente diagonale a due toni, deterministico dal gioco;
2. prato: banda `--rw-color-placeholder-ground` `#3F8F3F` dal 58% in basso;
3. stud: griglia di puntini bianchi `--rw-color-placeholder-studs` `rgba(255,255,255,0.22)`, passo 16 px (18 px hero, 20 px dettaglio);
4. iniziale: primo grafema del titolo, maiuscolo, bianco, `font-weight:700`, ombra dura `2px 2px 0 rgba(0,0,0,0.45)`;
5. immagine reale (se c'è) sopra tutto, tranne la barra `Gioca`.

CSS di riferimento:

```css
.card-thumb {
  position: relative;
  display: grid;
  place-items: center;
  overflow: hidden;
  width: 192px;
  height: 108px;
  border: 1px solid var(--rw-color-thumb-border);
  background:
    radial-gradient(circle, var(--rw-color-placeholder-studs) 1.4px, transparent 1.5px)
      0 0 / 16px 16px,
    linear-gradient(180deg,
      transparent 0%, transparent 58%,
      var(--rw-color-placeholder-ground) 58%, var(--rw-color-placeholder-ground) 100%),
    linear-gradient(160deg, var(--thumb-a, #7EC8E3), var(--thumb-b, #2B6CB0));
}
.card-thumb img {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
  object-position: center;
}
.card-thumb .play-hover {
  position: absolute;
  left: 0;
  right: 0;
  bottom: -22px;
  z-index: 2;
  height: 22px;
  background: #fff;
  border-top: 1px solid var(--rw-color-border-strong);
  color: var(--rw-color-text-muted);
  font: 12px/21px var(--rw-font-sans);
  text-align: center;
  opacity: 0;
  transition: bottom 120ms ease, opacity 120ms ease;
}
.card-link:hover .play-hover,
.card-link:focus-visible .play-hover {
  bottom: 0;
  opacity: 1;
}
```

### 4.2 Palette cielo

Otto coppie 2014, scelte con lo stesso hash stabile di `RW.palette` (id/titolo):

| # | Alto | Basso |
|---|---|---|
| 0 | `#7EC8E3` | `#2B6CB0` |
| 1 | `#F0B35A` | `#B5532B` |
| 2 | `#B480FF` | `#6B327C` |
| 3 | `#4FC28A` | `#27462D` |
| 4 | `#F5CD30` | `#AA6611` |
| 5 | `#DA8541` | `#7A3A3F` |
| 6 | `#9EC3E7` | `#114081` |
| 7 | `#D7C59A` | `#6B5523` |

Il prato resta `#3F8F3F` per tutte le palette. La scelta è deterministica: stesso gioco = stesso placeholder.

### 4.3 Iniziale e misure

| Contesto | Font iniziale |
|---|---|
| Card | 46 px |
| Dettaglio | 84 px |
| Hero | 76 px |
| Sidebar featured | 40 px |
| Mini “Più giocati” | 18 px |

- `Array.from(title)[0]` maiuscolo; se il titolo è vuoto, `?`.
- L'iniziale è `aria-hidden="true"`: il titolo adiacente è già il testo accessibile.
- L'iniziale non è mai l'unico contenuto informativo: la card ha titolo e meta.

### 4.4 Immagine rotta

- `onerror="this.remove()"` sull'`<img>` (forma compatta): il placeholder sottostante resta. La CSP attuale consente `'unsafe-inline'`; questa è la forma scelta.
- Un irrigidimento della CSP che togliesse `'unsafe-inline'` richiederebbe un ticket separato e un listener delegato sull'evento `error` in fase di capture.
- Nessun broken-image icon, nessun salto di layout: il contenitore ha già le dimensioni.
- La thumbnail rotta non viene ritentata; al refresh si riprova.

## 5. Avatar blocky

### 5.1 Scelta

L'avatar del profilo non è più un'iniziale su gradiente: è un **blocky R6 originale** in SVG inline, derivato dal `avatar_color` stabile dell'utente. Nessun asset esterno, nessuna chiamata server aggiuntiva.

### 5.2 Struttura

- Testa e braccia: `--rw-color-avatar-skin` `#F5CD30` con bordo `--rw-color-avatar-skin-dark` `#B38F00`.
- Torso: `avatar_color` dell'utente.
- Gambe: `avatar_color` scurito del 25%.
- Bordi: 2 unità nel viewBox 100×100, colore più scuro del riempimento.
- Fondo: `--rw-color-avatar-bg` `#EEEEEE`, bordo 1 px `--rw-color-border` `#CCCCCC`, nessun radius.
- Personaggio centrato, `width:78%`, `height:88%` del box.
- Faccia minima: due occhi scuri e una bocca; niente capelli/cappelli/oggetti.

SVG di riferimento:

```html
<svg viewBox="0 0 100 100" aria-hidden="true">
  <rect x="37" y="6" width="26" height="25" fill="#F5CD30" stroke="#B38F00" stroke-width="2"/>
  <rect x="23" y="34" width="11" height="29" fill="#F5CD30" stroke="#B38F00" stroke-width="2"/>
  <rect x="66" y="34" width="11" height="29" fill="#F5CD30" stroke="#B38F00" stroke-width="2"/>
  <rect x="36" y="32" width="28" height="31" fill="var(--avatar-color)" stroke="var(--avatar-dark)" stroke-width="2"/>
  <rect x="37" y="64" width="12" height="30" fill="var(--avatar-dark)" stroke="#00000055" stroke-width="1"/>
  <rect x="51" y="64" width="12" height="30" fill="var(--avatar-dark)" stroke="#00000055" stroke-width="1"/>
  <rect x="44" y="16" width="2" height="3" fill="#00000099"/>
  <rect x="54" y="16" width="2" height="3" fill="#00000099"/>
  <rect x="46" y="23" width="8" height="1.5" fill="#00000099"/>
</svg>
```

### 5.3 Misure e contesti

| Contesto | Dimensione | Note |
|---|---|---|
| Autore nella pagina gioco | 48×48 | decorativo, accanto al nome linkato |
| Profilo proprio/pubblico | 352×352 | `role="img"`, `aria-label="Avatar di <nome>"` |
| Profilo sotto 480 px | 200×200 | ticket 05 |

- L'avatar 48 è dentro o accanto al link dell'autore; il nome resta il testo accessibile.
- Il profilo mostra l'avatar nella colonna sinistra, sopra le statistiche.
- Il colore mancante o non valido usa `--rw-color-avatar-fallback` `#9E9E9E`, gambe `#6E6E6E`.
- Non si usa l'iniziale come fallback: il blocky è sempre disponibile.

### 5.4 API client

```js
RW.avatarHTML(user, size, decorative) -> string
```

- `size`: `48` o `352` (o `200` sotto 480).
- `decorative`: se `true`, niente `role`/`aria-label` (il nome è adiacente).
- `RW.shade(hex, -0.25)` calcola il colore delle gambe.
- Il valore `avatar_color` arriva da `/api/users/<id>` e da `/api/me`; nessuna modifica server.

## 6. Hero, featured e sidebar

### 6.1 Hero della home

- Art **430×230** con la thumbnail del gioco più popolare, `cover` center, bordo 1 px `--rw-color-hero-art-border` `rgba(255,255,255,0.5)`.
- Badge in basso a sinistra: `In evidenza · <titolo>`, fondo `rgba(0,0,0,0.65)`, testo bianco 12/600, padding 3×7, max-width `calc(100% - 20px)`, ellissi.
- L'art e il badge sono un unico link alla pagina del gioco; `aria-label="In evidenza: <titolo>"`.
- Se il gioco non ha thumbnail: placeholder con iniziale 76 px e badge.
- Se non ci sono giochi: l'art è **nascosta**, l'hero resta solo testo; nessun featured finto.
- Sotto 1000 px l'hero va in colonna e l'art diventa a piena larghezza con `aspect-ratio: 16/9`; il badge resta in basso a sinistra.
- Niente live count nell'hero: il badge dice solo “In evidenza”.

### 6.2 Sidebar Giochi

| Elemento | Media |
|---|---|
| “In evidenza” | 300×160, `cover` center, bordo 1 px `#CCC`, placeholder 40 px |
| “Più giocati” riga | 64×36, `cover` center, bordo 1 px `#CCC`, placeholder 18 px |
| “Crea il tuo gioco” | nessuna immagine |

- Titolo, autore, visite e CTA `Gioca` seguono il ticket 05.
- Se la sidebar non ha dati, la sezione sparisce; niente placeholder “finto”.

### 6.3 Dettaglio gioco

- Media **500×281**, `cover` center, bordo 1 px `#CCC`, nessun radius/ombra.
- `alt="Anteprima di <titolo>"`.
- Placeholder 84 px se manca la thumbnail o l'immagine è rotta.
- Nessuna galleria, nessun video, nessun carosello: una sola immagine.
- Sotto 1000 px il media va a piena larghezza 16:9.

## 7. Accenti like / live / hidden

| Elemento | Accento | Dove |
|---|---|---|
| Stella preferiti card | `--rw-color-like-icon` `#FFD700` | card, accanto al conteggio |
| Pulsante preferiti place | stella `#FFD700` se attivo, `#767676` se no | pagina gioco |
| Conteggio preferiti | `#666`; `aria-label="<N> preferiti"` | card/place |
| Live | `--rw-color-live` `#007001`, testo `N che giocano` | meta card, “Giocano ora” nella pagina |
| Nascosta | `--rw-color-hidden` `#AA6611`, badge testuale | profilo owner, admin |
| Tutto il resto | `#343434` / `#666` / `#767676` | titoli, autori, visite |

- Niente pillole live sulla thumbnail, niente badge flottanti, niente pallino verde: il live è testo.
- La stella è decorativa, ma il numero è leggibile e l'`aria-label` dice “preferiti”.
- Il badge `Nascosta` non è mai solo colore: ha il testo.
- `--rw-color-like` `#0055B3` resta per i link, non per la stella.

## 8. Copy

| Contesto | Testo |
|---|---|
| Barra hover card | `Gioca` |
| Autore card | `di <autore>` |
| Live card | `<N> che giocano` (solo se > 0) |
| Visite card | `<N> visite` |
| Preferiti card | `★ <N>` (aria `<N> preferiti`) |
| Hero badge | `In evidenza · <titolo>` |
| Place preferiti | `★ <N> preferiti` |
| Place live | `Giocano ora` |
| Placeholder | solo l'iniziale, nessun testo |
| Avatar | nessun testo; `aria-label="Avatar di <nome>"` sul profilo |

- Numeri con `RW.formatNumber` (formato italiano).
- Nessun “like” nell'interfaccia: si dice **preferiti**.
- Nessun “online”: si dice **che giocano**.

## 9. Accessibilità

- Card e sidebar: `alt=""` sulla thumbnail (il titolo adiacente è il testo accessibile); link con nome dal titolo/meta.
- Dettaglio: `alt="Anteprima di <titolo>"`; hero: `alt=""`, perché il link ha `aria-label` e il badge testuale.
- Placeholder: iniziale `aria-hidden="true"`.
- Avatar profilo: `role="img"` + `aria-label`; avatar 48 decorativo.
- Stella: `aria-label="<N> preferiti"`; il numero non è solo colore.
- Live: testo verde, non solo colore; “che giocano” è esplicito.
- Nascosta: badge testuale.
- Focus ring 2 px `#00A1DA` su card e pulsante preferiti; la barra `Gioca` compare anche su `:focus-visible`.
- Contrasto: meta `#666` su bianco 5.74:1; live `#007001` su bianco 6.33:1; hover `#767676` 4.54:1; la stella è decorativa.
- Motion: 120 ms per la barra; `prefers-reduced-motion` la disattiva.

## 10. Server, migrazione e limiti

| Voce | Decisione |
|---|---|
| Server/API/DB | **nessuna modifica** |
| Formato thumbnail | resta PNG 512×288 (editor); upload max 1920×1080, 1 MB |
| Migrazione | **nessuna**: le thumbnail esistenti sono già 16:9 |
| Re-upload | non necessario |
| Crop/resize server | non si fa |
| Validazione 16:9 | non si aggiunge; upload non 16:9 croppati in UI |
| Nuovi formati (WebP/AVIF) | fuori scope in questo effort |
| Immagini rotte | fallback client-side al placeholder |
| `thumbnail_url` | invariato, con `?v=<versione>` |

- La documentazione di pubblicazione dice “16:9 consigliato”; Studio cattura già 16:9.
- Il master 512×288 copre la card anche a 2× (384×216) e il dettaglio/hero a 1×. Per un dettaglio retina a 2× servirebbe un master più grande (almeno 1000×562) o un upload a risoluzione piena: non è richiesto ora.
- Una migrazione a 1280×720 o a un formato moderno è fuori scope; richiederebbe un ticket separato e non fa parte di questo effort.

## 11. Handoff implementativo

| File | Lavoro |
|---|---|
| `WEBhtml/assets/site.js` | `RW.thumbHTML`, `RW.card`, `RW.avatarHTML`, `RW.shade`, palette placeholder, `applyLive` con live testuale |
| `WEBhtml/assets/site.css` | card 202/192×108, placeholder stratificato, hover `Gioca`, avatar blocky, hero/sidebar/dettaglio |
| `WEBhtml/index.html` | hero art 430×230 con featured, badge, fallback “no giochi” |
| `WEBhtml/place.html` | media 500×281, autore con avatar 48 |
| `WEBhtml/profile.html` | avatar 352 blocky, card 2 colonne |
| `WEBhtml/games.html` (ticket 05) | griglia 3×202, sidebar 300×160 / 64×36 |
| `server/` | nessuna modifica |

- `RW.thumbHTML` deve accettare un contesto (`card`, `detail`, `hero`, `sidebar`, `mini`) per scegliere la misura dell'iniziale e l'`alt`.
- `RW.applyLive` aggiorna/rimuove lo `span.live-count` senza ridisegnare la card; non cambia l'altezza.
- `RW.palette` passa alle 8 coppie cielo 2014; `RW.userColor` resta per l'avatar.
- `RW.avatarHTML` sostituisce l'iniziale colorata in `profile.html` e aggiunge l'avatar 48 in `place.html`.

## 12. Verifica

### 12.1 Checklist visuale

- [ ] Card con thumbnail 512×288: nessun crop, bordo 1 px, titolo/meta allineati.
- [ ] Card senza thumbnail: cielo + prato + stud + iniziale, stessa palette per lo stesso gioco.
- [ ] Card con immagine rotta: placeholder, nessuna icona rotta, nessun layout shift.
- [ ] Hover/focus: barra `Gioca` 22 px, titolo sottolineato, focus ring; nessun lift/ombra.
- [ ] Live 0: riga autore senza “che giocano”; live >0: testo verde, nessuna pillola.
- [ ] Preferiti: stella oro + numero; `aria-label`; 0 preferiti visibile.
- [ ] Home: 4 colonne, hero 430×230 con badge e link; nessun gioco → hero senza art.
- [ ] Giochi: 3×202, sidebar 300×160 e 64×36.
- [ ] Place: media 500×281, avatar 48 + nome linkato.
- [ ] Profilo: avatar 352 blocky, card 2 colonne, badge Nascosta testuale.
- [ ] Sotto 1000/700/480: stack, 2/1 colonne, hero art 16:9, avatar 200.
- [ ] Upload 1920×1080 e 512×288: entrambi resi senza distorsione.
- [ ] Upload non 16:9: crop centrale, nessun errore.

### 12.2 Test esistenti

- `server/tests`: invariati; la validazione thumbnail non cambia.
- `tools/test_publish.gd` e `tools/test_studio.gd`: invariati; la cattura 512×288 resta.
- Nuovi controlli consigliati (ticket 09): unit su `RW.palette`/`RW.shade`/`RW.avatarHTML`, screenshot browser dei contesti e degli stati.

## 13. Deviazioni e adattamenti

1. **Placeholder originale** a stud + iniziale: non è un asset 2014, è il nostro fallback coerente.
2. **Avatar blocky SVG**: non è un render 3D; è un'identità originale RobloxWeb, non un avatar Roblox.
3. **Meta card su due righe**: il 2014 ne aveva una; servono autore, live, visite e preferiti senza pillole.
4. **Hover `#767676`** invece di `#888`: contrasto 4.54:1 (ticket 04).
5. **Niente crop lato server**: il 16:9 è già il master; il crop non 16:9 è UI.
6. **Niente galleria/video**: il prodotto ha una thumbnail sola.
7. **Niente avatar nella card**: il 2014 non lo mostrava e il ticket 05 non lo chiede.
8. **Hero 430×230** (1.87:1) e non 430×242: misura fissa del ticket 05, con `cover`.
9. **Live testuale** e non badge: ticket 05.
10. **Nessun asset Roblox**: stud, prato e blocky sono disegnati da noi.

## 14. Decisioni approvate

1. Master 512×288 16:9, upload max 1920×1080, `cover` center in UI, nessun resize server.
2. Card 202/192×108, titolo 14/600, meta due righe, hover `Gioca` 22 px, nessun lift/ombra, live testuale verde e stella oro.
3. Placeholder cielo/prato/stud/iniziale con 8 palette 2014 deterministiche; fallback anche per immagini rotte.
4. Avatar blocky SVG da `avatar_color`, 48 autore e 352 profilo, fondo `#EEE`.
5. Hero 430×230 cover con badge e link; sidebar 300×160 e 64×36; dettaglio 500×281.
6. Oro per i preferiti, verde per il live, warning per Nascosta; nessun altro accento.
7. Zero modifiche a server/API/DB e nessuna migrazione.

Esito: regole media pronte per il piano di implementazione (ticket 09).
