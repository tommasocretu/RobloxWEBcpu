# HUD e widget del client

Type: grilling
Status: resolved
Blocked by: 01, 02, 03, 04

## Question

Definire quali widget del client 2014 esistono, quali no e come sono fatti. Vincolo dal prototipo: **client B** — topbar HTML 36 px (titolo/autore/giocatori/Esci) fuori dal CanvasLayer, HUD 2014 dentro; chat in alto a sinistra, monete nella player list, Game Menu nero/rosso. Token approvati in `tokens.md`: usare i token, non valori hardcoded. La barra HTML è decisa nel ticket 05: brand, titolo, autore, “N che giocano”, Esci; niente nome giocatore. Dentro il CanvasLayer niente topbar. Lessico: “gioco”, “Lasciare questo gioco?” (vedi `GLOSSARY.md`).

- topbar: nel 2014 non esiste. Decidere cosa fare dell'attuale top bar HTML di `play.html` (tenerla come chrome del sito, ridurla, o spostare titolo/autore/giocatori altrove) e come il Game Menu su Esc gestisce l'uscita;
- chat (account) e stato ospite;
- player list;
- health bar, monete, messaggi, notifiche/toast;
- menu Esc / Game Menu e dialogo “Lasciare questo gioco?”;
- caricamento iniziale, morte/respawn, checkpoint, goal;
- FPS: debug nascosto o rimosso;
- backpack/hotbar: esiste un inventario? se no, decorativo o assente.

Per ognuno: layout, ancore, z-order, stati, comportamento a risoluzioni diverse, testi.

Esito: specifica HUD/widget con elenco "esiste / non esiste / decorativo".

## Answer

Approvate tutte e nove le proposte il 28 ottobre 2026. Specifica completa in [`hud-client.md`](../../../docs/roblox-2014/hud-client.md).

- **Barra HTML:** resta chrome del sito, 36 px blu, con brand, titolo, autore linkato al profilo, `N che giocano` via polling API ogni 10 s ed `Esci` diretto; niente nome giocatore. La player list in-game è la fonte autorevole delle righe.
- **Caricamento:** un solo proprietario, l'overlay HTML (nero, `CARICAMENTO`, barra 300×18 `#D2D400`/`#8C8C8C`). Handshake `rw-ready`/`rw-error`, timeout 30 s; `_show_boot` sparisce nel wrapper embedded.
- **Chat:** 500×120 in alto a sinistra, senza sfondo, 8 righe visibili su 20, 45 s, nomi con palette 2014 deterministica, system oro; input full-width 20 px in basso, `/` o Invio, Esc chiude, movimento bloccato mentre si scrive; ospite disabilitato con avviso oro.
- **Player list:** 202 px (150 nome + 52 monete) in alto a destra, header 56, righe 20, niente avatar, locale in grassetto, ordine alfabetico, collapse a 24 px. Monete solo sulla riga locale (`3/10`), `—` sugli altri: il relay non sincronizza le monete e resta fuori scope.
- **Salute e morte:** 170×18, gradiente verde, rossa sotto 25%, label `Salute`; hurt overlay per danni ≥5 HP; nessuna schermata di morte, respawn immediato.
- **Menu:** pulsante a scudo 92×48 in basso a sinistra; Game Menu 525×430 nero/rosso con `Riprendi` (default), `Reimposta personaggio`, `Esci dal gioco` e blocco `Comandi`; Leave 525×300 con `Resta` default; Reset 525×370 con `Annulla` default (deviazione di sicurezza); nessuna pausa, si rilascia il mouse e si blocca il movimento. Solo nel client web in place mode.
- **Eventi:** niente toast; chat oro per benvenuto, ospite, checkpoint, monete, connessione ed errori script; banner 525×80 `GIOCO COMPLETATO!` + riga oro per il traguardo.
- **FPS/backpack/mirino:** FPS solo su F3; backpack e Lock Mouse assenti; mirino 4×4 solo in shift lock.
- **Scala:** `clamp(min(w/1280, h/720), 0.8, 1.0)`, input chat a piena larghezza, minimo supportato 640×400.

Esito: specifica HUD/widget pronta per il piano (09).
