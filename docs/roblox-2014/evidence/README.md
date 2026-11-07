# Evidenze visuali

> Cartella delle contact sheet finali del re-skin 2014.

## Cosa si committa

- Solo le **contact sheet** ottimizzate (13 PNG) prodotte a fine lavoro.
- Il set completo degli screenshot before/after resta in
  `.scratch/roblox-2014-aesthetic/evidence/` e non viene versionato
  (`.gitignore`: `.scratch/*/evidence/`).
- Le immagini servono alla review umana e alla firma di [`../acceptance.md`](../acceptance.md);
  non sono golden images e non sono un gate automatico.

## File committati

| File | Superficie |
|---|---|
| `site-home-1440.png` | Home 2014 |
| `site-games-1440.png` | Catalogo Giochi |
| `site-place-1440.png` | Dettaglio gioco |
| `site-account-1440.png` | Accedi + Profilo (affiancati) |
| `site-admin-1440.png` | Moderazione (stato vuoto) |
| `site-studio-1440.png` | Studio e download |
| `play-states-1440.png` | `play.html`: caricamento, errore, pronto |
| `play-ready-650x900.png` | `play.html` responsive a 650 px |
| `hud-ready-1680x964.png` | HUD completo |
| `hud-chat-1680x964.png` | HUD con input chat aperto |
| `hud-menu-1680x964.png` | Game Menu |
| `hud-dialogs-1680x964.png` | Leave + Reset |
| `hud-scale-matrix.png` | HUD a 1280×684, 1024×732, 800×564, 640×364 |

Le contact sheet HUD e play sono ridotte per stare in una pagina leggibile:
il fattore è indicato nel titolo dell'immagine (60% per il HUD a 1680×964,
70% per `play.html` a 1440×900). Le dimensioni logiche testate restano quelle
nel nome del file.

## Convenzioni

- Nomi deterministici: `site-<pagina>-<larghezza>-<stato>.png` e
  `hud-<gruppo>-<stato>-<WxH>.png`.
- Le superfici e gli stati da fotografare sono nella matrice di
  [`../implementation-plan.md`](../implementation-plan.md) §8.2–8.3.
- Ogni PR allega gli screenshot delle superfici cambiate; la PR 10 raccoglie le contact
  sheet.
- Le immagini non contengono dati personali reali: le fixture usano account
  `visual_owner`, `visual_viewer`, `visual_admin` e una data dir temporanea.
  Le contact sheet finali sono state prodotte dal server di sviluppo locale con
  l'account demo; nessun dato personale è presente.
