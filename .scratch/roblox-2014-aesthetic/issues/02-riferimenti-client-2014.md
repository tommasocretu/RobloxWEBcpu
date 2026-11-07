# Riferimenti: client Roblox metà 2014

Type: research
Status: resolved
Blocked by: —

## Question

Ricostruire i valori visivi e la struttura della UI in-game del client Roblox di metà 2014:

- topbar: altezza, colore, logo, voci/pulsanti, player count, "Leave";
- chat: posizione, sfondo, colori, tab, messaggi di sistema;
- player list: posizione, righe, avatar, stati;
- backpack/hotbar: slot, dimensioni, icone, numerazione;
- health bar e indicatori di stato;
- notifiche/toast;
- menu Esc / dialogo "Leave Game?";
- schermata di caricamento, morte/respawn, checkpoint, goal;
- font, dimensioni, spaziature, z-order.

Fonti: screenshot e video ufficiali d'epoca, wiki Roblox, repo di asset client 2014, blog ufficiali archiviati. Citare ogni fonte e distinguere verificato da inferito.

Deliverable: `docs/roblox-2014/research/client-2014.md`.

## Answer

Ricostruzione completa in [`docs/roblox-2014/research/client-2014.md`](../../../docs/roblox-2014/research/client-2014.md), con fonti primarie (CoreScripts del 30/06/2014), screenshot nativi datati e distinzione **verificato / inferito**.

- **Topbar: non esiste nel client di metà 2014.** Nessuna barra, logo, player count o "Leave" in alto. La navigazione è il pulsante a scudo **`Menu` in basso a sinistra** (~92×48, casa + testo, fill trasparente, bordo 1 px). La topbar con 3 icone arriva il **23/04/2015**; l'header scuro 2014 è quello del **sito**, non del client.
- **Chat:** messaggi in **alto a sinistra** (500×120, y=5), nessuno sfondo, font 12 px, testo bianco con outline nero, nomi in 8 BrickColor, admin/system oro `#FFD700`; 20 messaggi, 45 s; **nessuna tab** (safe chat rimossa il 03/04/2014). Input a tutta larghezza in basso, 20 px, nero al 75%, placeholder `To chat click here or press "/" key`.
- **Player list:** **alto a destra**, 150 px (si allarga con leaderstats), header 56 px, righe 20 px, nome `Arial` 14, header `ArialBold` 24, icone BC/amico/admin 16×16, **nessun avatar**, nessun contatore giocatori. Collapse dal chevron in basso.
- **Backpack/hotbar:** contenitore 600×54 a 85 px dal fondo, **9 slot 54×54** con gap 6, numeri 1–9 `ArialBold` 18 in alto a sinistra, nomi `Arial` 14; chevron backpack 120×18. Inventario 600×400 `#202020`, tab `Gear`/`Wardrobe`, search 220×24. Con zero tool è più fedele **non mostrare** l'hotbar.
- **Health:** **170×18** centrata, bottom 22 px, sfondo/bordo nero, gradiente verde (`#25B230`→`#004F00`), rossa sotto il 25%, oro se NaN; label `Health` `SourceSansBold` 14 a destra con outline; hurt overlay rosso su danni ≥5%.
- **Menu Esc / Leave:** Game Menu **525×430** centrato, shield `#333333` al 40%, titolo `ArialBold` 36, pulsanti 340×50 neri con bordo grigio e **default rosso**; `Leave Game` apre **525×300** `Leave this game?` con `Stay` (default) e `Leave` 128×50. Fino al **27/08/2014** è nero/rosso; dopo è grigio/blu.
- **Loading:** nero, spinner bianco a segmenti + `LOADING`; la barra di progresso giallo-verde `#D2D400` è nel wrapper web, non nel client. **Morte/respawn:** nessuna UI core, solo hurt overlay e respawn del server. **Checkpoint/goal:** non sono UI core 2014, vanno resi con chat di sistema oro e banner centrato.
- **Font:** Arial/ArialBold per menu, player list, backpack; Source Sans Pro per health/chat. Per il re-skin: **Source Sans 3** globale, Arial solo per i label legacy.
- **Conseguenza:** niente finta topbar in Godot; barra titolo/autore/player count nell'HTML di `play.html`, Menu in basso a sinistra e Game Menu su Esc nel CanvasLayer.
