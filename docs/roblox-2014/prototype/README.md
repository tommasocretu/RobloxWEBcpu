# Prototipo — estetica Roblox 2014

> Archiviato come riferimento della [specifica consolidata](../spec.md). Non è codice di
> produzione e non va promosso a `WEBhtml/`.

**Domanda che risolve:** che aspetto deve avere il re-skin 2014 di sito e client, e quali strutture reggono meglio dei layout attuali?

## Verdetto (28 ottobre 2026)

- **Home: B** — 1180 px, hero, 4 colonne 16:9, senza sidebar.
- **Catalogo (Giochi, profilo, ecc.): 970 px + sidebar**, densità 2014.
- **Client: B** — topbar HTML blu 36 px (titolo/autore/giocatori/Esci) come chrome del sito, HUD 2014 dentro il canvas.
- **Dettagli:** chat in alto a sinistra, monete come colonna della player list, Game Menu nero/rosso con “Resta” default, nessuna topbar in Godot.
- A e C non sono state scelte: restano solo per confronto. Il prototipo apre su B; usare `?variant=A` o `?variant=C` per rivederle.

Artefatto **usa-e-getta**: non fa parte di `WEBhtml/`, non tocca Godot, non va promosso a produzione. Le decisioni validate finiscono nei ticket della mappa e nella spec.

## Come si avvia

```bash
cd .scratch/roblox-2014-aesthetic/prototype
python3 -m http.server 9090
```

Poi aprire:

- <http://127.0.0.1:9090/index.html> — indice
- <http://127.0.0.1:9090/home.html> — tre home
- <http://127.0.0.1:9090/client.html> — tre HUD

Il selettore in basso cambia variante e aggiorna `?variant=`; funzionano anche ← e →.

## Home — tre strutture

| Variante | Struttura | Cosa testa |
|---|---|---|
| **A — Griglia 2014** | Header blu 36 px, colonna 970, filtri, griglia 3×202 px con card 192×108, sidebar 300 px, footer blu | La fedeltà al modello “Games” di giugno 2014 |
| **B — Home attuale, pelle 2014** | Header blu, colonna 1180, hero, tab di ordinamento, griglia 4 colonne 16:9 | Se la pelle 2014 regge il layout attuale senza sembrare un travestimento |
| **C — Vetrina 2014** | Featured 970×280 + griglia 3 colonne + sidebar | Se serve una fascia “in evidenza” e quanto spazio ruba al catalogo |

Ancore verificate: header `#114081` 36 px, testo `#343434`, link `#0055B3`, CTA verde `#007001` / blu `#0852B7`, Source Sans Pro 14 px/1.428, card 192×108 (16:9, non 4:3), footer `#123F83`.

## Client — tre HUD

| Variante | Struttura | Cosa testa |
|---|---|---|
| **A — Fedele 2014** | Nessuna topbar; chat in alto a sinistra (500×120, 12 px, senza sfondo), player list 200 px in alto a destra con colonna Monete, Menu a scudo in basso a sinistra, health 170×18 in basso al centro | La ricostruzione fedele, con monete e player count spostati dove il 2014 li avrebbe messi |
| **B — Ibrido** | Topbar HTML blu da 36 px (titolo/autore/giocatori/Esci) + HUD 2014 dentro il canvas | Se conviene tenere la barra del sito sopra l'iframe invece di inventare una topbar in Godot |
| **C — HUD attuale, pelle 2014** | Monete in alto a sinistra, “Giocatori: 3” in alto a destra, chat in basso a sinistra, health in basso al centro, nessuna player list | Il percorso a costo minimo: cambiare solo colori/font/misure, non l'architettura |

Interazioni: `Esc` apre il Game Menu; “Esci dall'esperienza” porta al dialogo “Lasciare questa esperienza?” con **Resta** come default; `/` o click sulla barra apre la chat; click sull'header della player list la comprime; i pulsanti `PROTOTIPO` mostrano caricamento e notifica.

Ancore verificate: niente topbar nel client di metà 2014; chat 12 px in alto a sinistra; player list 150 px base, righe 20 px, senza avatar; health 170×18 con gradiente `#25B230`→`#004F00`; Game Menu nero/rosso 525×430; Leave 525×300; loading nero con spinner e `LOADING`.

## Cosa è volutamente non fedele

- Le thumbnail sono gradienti CSS, non screenshot: servono a giudicare densità e composizione, non il contenuto.
- I testi sono in italiano, mentre il sito 2014 era in inglese: il lessico va deciso nel ticket sulla mappatura del sito.
- Le varianti B e C sono esperimenti di prodotto, non ricostruzioni storiche.
- Il responsive sotto i 1000 px è un degrado dignitoso, non una UI mobile 2014.
- Il font viene da Google Fonts per comodità; la produzione usa Source Sans 3 self-hostata come da [`tokens.md`](../tokens.md) §2.2/§5.

## Cosa guardare mentre si prova

1. La home A sembra troppo vuota o giusta? La sidebar serve o è zavorra?
2. La home B sembra 2014 o solo “un sito chiaro con l'header blu”?
3. Nel client A, la chat in alto a sinistra e la player list in alto a destra lasciano respirare il centro?
4. La topbar HTML della variante B è un compromesso accettabile o va eliminata?
5. Il Game Menu nero/rosso è troppo aggressivo? Il flusso a due passi è chiaro?
6. Le monete nella player list bastano, o serve un contatore separato?

Buttare il prototipo quando le risposte sono registrate.
