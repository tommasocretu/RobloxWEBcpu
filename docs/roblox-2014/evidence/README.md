# Evidenze visuali

> Cartella delle contact sheet finali del re-skin 2014.

## Cosa si committa

- Solo le **contact sheet** ottimizzate (circa 10–14 immagini) prodotte a fine lavoro.
- Il set completo degli screenshot before/after resta in
  `.scratch/roblox-2014-aesthetic/evidence/` e non viene versionato.
- Le immagini servono alla review umana e alla firma di [`../acceptance.md`](../acceptance.md);
  non sono golden images e non sono un gate automatico.

## Convenzioni

- Nomi deterministici: `site-<pagina>-<larghezza>-<stato>.png` e
  `hud-<gruppo>-<stato>-<WxH>.png`.
- Le superfici e gli stati da fotografare sono nella matrice di
  [`../implementation-plan.md`](../implementation-plan.md) §8.2–8.3.
- Ogni PR allega gli screenshot delle superfici cambiate; la PR 10 raccoglie le contact
  sheet.
- Le immagini non contengono dati personali reali: le fixture usano account
  `visual_owner`, `visual_viewer`, `visual_admin` e una data dir temporanea.
