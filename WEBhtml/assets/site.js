/* RobloxWeb — utilità condivise del sito (vanilla JS, nessun build step). */
(function () {
  "use strict";

  const RW = {};
  const FOOTER_YEAR = 2026;
  const AVATAR_FALLBACK = "#9e9e9e";
  const GAMES_URL = "/#giochi";

  // Otto coppie cielo/prato del 2014 (docs/roblox-2014/media-rules.md §4.2).
  const PALETTES = [
    ["#7ec8e3", "#2b6cb0"],
    ["#f0b35a", "#b5532b"],
    ["#b480ff", "#6b327c"],
    ["#4fc28a", "#27462d"],
    ["#f5cd30", "#aa6611"],
    ["#da8541", "#7a3a3f"],
    ["#9ec3e7", "#114081"],
    ["#d7c59a", "#6b5523"],
  ];

  const PAGE_ACTIVE = {
    home: "home",
    place: "games",
    games: "games",
    profile: "profile",
    admin: "admin",
    studio: "studio",
  };

  const THUMB_CONTEXTS = {
    card: { suffix: "", loading: "lazy", play: true },
    detail: { suffix: " thumb-detail", loading: "eager", play: false },
    hero: { suffix: " thumb-hero", loading: "eager", play: false },
    sidebar: { suffix: " thumb-sidebar", loading: "lazy", play: false },
    mini: { suffix: " thumb-mini", loading: "lazy", play: false },
  };

  RW.escape = function (value) {
    return String(value == null ? "" : value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#39;");
  };

  RW.qs = function (name) {
    return new URLSearchParams(window.location.search).get(name);
  };

  RW.safeNext = function (value, fallback) {
    if (
      !value ||
      typeof value !== "string" ||
      !value.startsWith("/") ||
      value.startsWith("//") ||
      value.includes("\\") ||
      /[\u0000-\u001f]/.test(value)
    ) {
      return fallback || "/";
    }
    return value;
  };

  RW.localizeServerMessage = function (message, status) {
    const fallbacks = {
      0: "Server non raggiungibile.",
      401: "Accedi per continuare.",
      403: "Non hai i permessi per questa azione.",
      404: "Gioco non trovato.",
      429: "Troppe richieste. Riprova tra poco.",
      503: "Servizio temporaneamente non disponibile.",
    };
    let text = String(message == null ? "" : message).trim();
    if (!text || /^Errore HTTP \d+$/.test(text)) {
      text = fallbacks[Number(status)] || text;
    }
    if (!text) return "";

    // Frasi intere: il cambio di genere non si può fare a parole singole.
    text = text
      .replace(/Sessione mancante o scaduta\./g, "Accedi per continuare.")
      .replace(/L'esperienza/g, "Il gioco")
      .replace(/l'esperienza/g, "il gioco")
      .replace(/Questa esperienza/g, "Questo gioco")
      .replace(/questa esperienza/g, "questo gioco")
      .replace(/la tua esperienza/g, "il tuo gioco")
      .replace(/La tua esperienza/g, "Il tuo gioco")
      .replace(/Esperienza non trovata/g, "Gioco non trovato")
      .replace(/esperienza non trovata/g, "gioco non trovato")
      .replace(/Esperienza non valida/g, "Gioco non valido")
      .replace(/esperienza non valida/g, "gioco non valido")
      .replace(/Esperienza privata/g, "Gioco privato")
      .replace(/esperienza privata/g, "gioco privato")
      .replace(/Esperienza nascosta/g, "Gioco nascosto")
      .replace(/esperienza nascosta/g, "gioco nascosto")
      .replace(/Esperienza ripristinata/g, "Gioco ripristinato")
      .replace(/esperienza ripristinata/g, "gioco ripristinato")
      .replace(/Esperienza aggiornata/g, "Gioco aggiornato")
      .replace(/esperienza aggiornata/g, "gioco aggiornato")
      .replace(/Esperienza pubblicata/g, "Gioco pubblicato")
      .replace(/esperienza pubblicata/g, "gioco pubblicato")
      .replace(/Esperienza segnalata/g, "Gioco segnalato")
      .replace(/esperienza segnalata/g, "gioco segnalato")
      .replace(/Gli ospiti non possono mettere like\./g, "Gli ospiti non possono aggiungere ai preferiti.")
      .replace(/gli ospiti non possono mettere like\./g, "gli ospiti non possono aggiungere ai preferiti.")
      .replace(/Esperienze/g, "Giochi")
      .replace(/esperienze/g, "giochi")
      .replace(/Esperienza/g, "Gioco")
      .replace(/esperienza/g, "gioco")
      .replace(/\blike\b/g, "preferiti")
      .replace(/\bLike\b/g, "Preferiti")
      .replace(/\bonline\b/g, "che giocano")
      .replace(/\bOnline\b/g, "Che giocano");
    return text;
  };

  RW.api = async function (path, options) {
    const opts = Object.assign({ method: "GET", credentials: "same-origin" }, options || {});
    const headers = Object.assign({ Accept: "application/json" }, opts.headers || {});
    if (opts.body != null && typeof opts.body !== "string") {
      headers["Content-Type"] = "application/json";
      opts.body = JSON.stringify(opts.body);
    }
    opts.headers = headers;
    try {
      const response = await fetch(path, opts);
      let data = null;
      try {
        data = await response.json();
      } catch (_) {
        data = null;
      }
      const rawError = (data && data.error) || `Errore HTTP ${response.status}`;
      return {
        ok: response.ok,
        status: response.status,
        data: data,
        error: RW.localizeServerMessage(rawError, response.status),
      };
    } catch (err) {
      return {
        ok: false,
        status: 0,
        data: null,
        error: RW.localizeServerMessage("Server non raggiungibile.", 0),
      };
    }
  };

  let mePromise = null;

  RW.me = function () {
    if (!mePromise) {
      mePromise = (async () => {
        const result = await RW.api("/api/me");
        return result.ok && result.data ? result.data.user : null;
      })();
    }
    return mePromise;
  };

  RW.requireUser = async function () {
    const user = await RW.me();
    if (!user) {
      const next = encodeURIComponent(window.location.pathname + window.location.search);
      window.location.href = "/login.html?next=" + next;
      return null;
    }
    return user;
  };

  RW.startGuest = async function (next) {
    const result = await RW.api("/api/guest", { method: "POST" });
    if (!result.ok) {
      return result;
    }
    window.location.href = RW.safeNext(next, "/");
    return result;
  };

  RW.logout = async function () {
    await RW.api("/api/logout", { method: "POST" });
    window.location.href = "/";
  };

  RW.formatNumber = function (value) {
    return new Intl.NumberFormat("it-IT").format(Number(value || 0));
  };

  RW.visibilityLabel = function (value) {
    return { public: "Pubblica", unlisted: "Non elencata", private: "Privata" }[value] || value;
  };

  RW.timeAgo = function (iso) {
    if (!iso) return "";
    const date = new Date(iso);
    if (Number.isNaN(date.getTime())) return "";
    const seconds = Math.max(0, Math.floor((Date.now() - date.getTime()) / 1000));
    if (seconds < 60) return "adesso";
    if (seconds < 3600) return Math.floor(seconds / 60) + " min fa";
    if (seconds < 86400) return Math.floor(seconds / 3600) + " h fa";
    if (seconds < 86400 * 30) return Math.floor(seconds / 86400) + " g fa";
    return date.toLocaleDateString("it-IT");
  };

  RW.palette = function (place) {
    const seed = String((place && (place.id || place.title)) || "x");
    let hash = 0;
    for (let i = 0; i < seed.length; i += 1) {
      hash = (hash * 31 + seed.charCodeAt(i)) >>> 0;
    }
    return PALETTES[hash % PALETTES.length];
  };

  RW.shade = function (hex, amount) {
    const match = /^#([0-9a-f]{6})$/i.exec(String(hex || ""));
    if (!match) return hex;
    const value = parseInt(match[1], 16);
    const delta = Number(amount || 0);
    const channels = [(value >> 16) & 255, (value >> 8) & 255, value & 255].map((channel) => {
      const target = delta < 0 ? channel * (1 + delta) : channel + (255 - channel) * delta;
      return Math.max(0, Math.min(255, Math.round(target)));
    });
    return "#" + channels.map((channel) => channel.toString(16).padStart(2, "0")).join("");
  };

  RW.userColor = function (user) {
    const color = user && String(user.avatar_color || "");
    if (/^#[0-9a-f]{6}$/i.test(color)) {
      return color;
    }
    return AVATAR_FALLBACK;
  };

  RW.thumbStyle = function (place) {
    const colors = RW.palette(place);
    return `--thumb-a:${colors[0]};--thumb-b:${colors[1]};`;
  };

  RW.liveBadgeHTML = function (place) {
    const live = Number(place && place.live_players ? place.live_players : 0);
    return `<span class="live-count"${live > 0 ? "" : " hidden"}>${RW.formatNumber(live)}</span>`;
  };

  RW.thumbHTML = function (place, context) {
    const key = THUMB_CONTEXTS[context] ? context : "card";
    const info = THUMB_CONTEXTS[key];
    const title = String((place && place.title) || "");
    const first = Array.from(title.trim())[0] || "?";
    const initial = RW.escape(first.toUpperCase());
    const style = RW.escape(RW.thumbStyle(place));
    const alt = key === "detail" ? `Anteprima di ${title}` : "";
    let html = `<div class="card-thumb${info.suffix}" style="${style}">` +
      `<span class="thumb-initial" aria-hidden="true">${initial}</span>`;
    if (place && place.thumbnail_url) {
      html += `<img src="${RW.escape(place.thumbnail_url)}" alt="${RW.escape(alt)}"` +
        ` loading="${info.loading}" decoding="async" onerror="this.remove()">`;
    }
    if (info.play) {
      html += '<span class="play-hover" aria-hidden="true">Gioca</span>';
    }
    return html + "</div>";
  };

  RW.card = function (place) {
    const live = Number((place && place.live_players) || 0);
    const title = RW.escape(place && place.title);
    const author = RW.escape(place && place.author);
    const likes = Number((place && place.likes) || 0);
    const visits = Number((place && place.visits) || 0);
    const liveHTML = live > 0
      ? `<span class="live-count" data-live-text="1"> · ${RW.formatNumber(live)} che giocano</span>`
      : "";
    const likeHTML =
      `<span class="like-count" aria-label="${RW.formatNumber(likes)} preferiti">` +
      `<span class="star" aria-hidden="true">★</span> ${RW.formatNumber(likes)}</span>`;
    return `
      <article class="card" data-place-card="${RW.escape(place && place.id)}">
        <a class="card-link" href="/place.html?id=${encodeURIComponent(place && place.id)}">
          ${RW.thumbHTML(place, "card")}
          <h3 class="card-title">${title}</h3>
          <div class="card-meta">
            <div class="card-meta-line card-author">di ${author}${liveHTML}</div>
            <div class="card-meta-line card-stats">${RW.formatNumber(visits)} visite · ${likeHTML}</div>
          </div>
        </a>
      </article>`;
  };

  RW.avatarHTML = function (user, size, decorative) {
    const requested = Number(size);
    const pixels = requested === 352 ? 352 : requested === 200 ? 200 : 48;
    const color = RW.userColor(user);
    const dark = RW.shade(color, -0.25);
    const name = RW.escape(user && user.name ? user.name : "utente");
    const label = decorative
      ? ""
      : ` role="img" aria-label="Avatar di ${name}"`;
    return `<span class="avatar avatar-${pixels}"${label} style="--avatar-color:${color};--avatar-dark:${dark}">` +
      '<svg viewBox="0 0 100 100" aria-hidden="true" focusable="false">' +
      '<rect x="37" y="6" width="26" height="25" fill="#F5CD30" stroke="#B38F00" stroke-width="2"/>' +
      '<rect x="23" y="34" width="11" height="29" fill="#F5CD30" stroke="#B38F00" stroke-width="2"/>' +
      '<rect x="66" y="34" width="11" height="29" fill="#F5CD30" stroke="#B38F00" stroke-width="2"/>' +
      '<rect x="36" y="32" width="28" height="31" fill="var(--avatar-color)" stroke="var(--avatar-dark)" stroke-width="2"/>' +
      '<rect x="37" y="64" width="12" height="30" fill="var(--avatar-dark)" stroke="#00000055" stroke-width="1"/>' +
      '<rect x="51" y="64" width="12" height="30" fill="var(--avatar-dark)" stroke="#00000055" stroke-width="1"/>' +
      '<rect x="44" y="16" width="2" height="3" fill="#00000099"/>' +
      '<rect x="54" y="16" width="2" height="3" fill="#00000099"/>' +
      '<rect x="46" y="23" width="8" height="1.5" fill="#00000099"/>' +
      "</svg></span>";
  };

  // Aggiorna il testo live senza ridisegnare le card (niente flicker o scroll perso).
  RW.applyLive = function (items) {
    (items || []).forEach((place) => {
      if (!place || place.id == null) return;
      const live = Number(place.live_players || 0);
      document.querySelectorAll(`[data-place-card="${place.id}"]`).forEach((card) => {
        const author = card.querySelector(".card-author");
        if (!author) return;
        let liveEl = author.querySelector(".live-count");
        if (live > 0) {
          if (!liveEl) {
            liveEl = document.createElement("span");
            liveEl.className = "live-count";
            liveEl.dataset.liveText = "1";
            author.appendChild(liveEl);
          }
          liveEl.textContent = ` · ${RW.formatNumber(live)} che giocano`;
        } else if (liveEl) {
          liveEl.remove();
        }
      });
    });
  };

  // Polling leggero: si ferma quando la scheda è in background.
  RW.pollLive = function (buildUrl, intervalMs) {
    const tick = async () => {
      if (document.hidden) return;
      try {
        const result = await RW.api(buildUrl());
        if (result.ok && result.data) {
          RW.applyLive(result.data.places || (result.data.place ? [result.data.place] : []));
        }
      } catch (_) {
        /* il polling non deve rompere la pagina */
      }
    };
    const timer = setInterval(tick, intervalMs || 10000);
    document.addEventListener("visibilitychange", () => {
      if (!document.hidden) tick();
    });
    return timer;
  };

  RW.setAlert = function (element, message, kind) {
    if (!element) return;
    const type = kind || "error";
    element.className = "alert alert-" + type;
    element.setAttribute("role", type === "error" ? "alert" : "status");
    element.textContent = message;
    element.hidden = !message;
  };

  RW.confirmDialog = function (options) {
    const opts = options || {};
    return new Promise((resolve) => {
      const dialog = document.createElement("dialog");
      dialog.className = "rw-dialog";
      const title = RW.escape(opts.title || "Conferma");
      const message = opts.message ? `<p>${RW.escape(opts.message)}</p>` : "";
      const confirmLabel = RW.escape(opts.confirmLabel || "Conferma");
      const cancelLabel = opts.cancelLabel === null ? null : RW.escape(opts.cancelLabel || "Annulla");
      const confirmClass = opts.danger ? "btn btn-danger" : "btn btn-primary";
      const cancel = cancelLabel
        ? `<button class="btn btn-negative" type="button" data-cancel>${cancelLabel}</button>`
        : "";
      let settled = false;

      dialog.innerHTML =
        `<form method="dialog"><h2>${title}</h2>${message}` +
        `<div class="dialog-actions">${cancel}` +
        `<button class="${confirmClass}" type="button" data-confirm>${confirmLabel}</button>` +
        "</div></form>";
      document.body.appendChild(dialog);

      const finish = (confirmed) => {
        if (settled) return;
        settled = true;
        dialog.close(confirmed ? "confirm" : "cancel");
        dialog.remove();
        resolve(confirmed);
      };

      dialog.querySelector("[data-confirm]").addEventListener("click", () => finish(true));
      const cancelButton = dialog.querySelector("[data-cancel]");
      if (cancelButton) {
        cancelButton.addEventListener("click", () => finish(false));
      }
      dialog.addEventListener("cancel", (event) => {
        event.preventDefault();
        finish(false);
      });
      dialog.addEventListener("close", () => {
        if (settled) return;
        settled = true;
        const confirmed = dialog.returnValue === "confirm";
        dialog.remove();
        resolve(confirmed);
      });

      dialog.showModal();
      const safeButton = dialog.querySelector("[data-cancel]") || dialog.querySelector("[data-confirm]");
      if (safeButton) safeButton.focus();
    });
  };

  RW.alertDialog = function (title, message, confirmLabel) {
    return RW.confirmDialog({
      title: title,
      message: message,
      confirmLabel: confirmLabel || "Chiudi",
      cancelLabel: null,
    });
  };

  RW.headerHTML = function (user) {
    const active = PAGE_ACTIVE[document.body.dataset.page] || "";
    const next = encodeURIComponent(window.location.pathname + window.location.search);
    const navLink = (key, label, href) => {
      const current = key === active ? ' class="active" aria-current="page"' : "";
      return `<a href="${href}" data-nav="${key}"${current}>${label}</a>`;
    };
    const nav = [
      navLink("home", "Home", "/"),
      navLink("games", "Giochi", GAMES_URL),
      navLink("studio", "Studio", "/studio.html"),
    ];
    if (user) {
      nav.push(navLink("profile", "Profilo", "/profile.html"));
      if (user.is_admin) {
        nav.push(navLink("admin", "Moderazione", "/admin.html"));
      }
    }
    const account = user
      ? `<a class="header-who" href="/profile.html" title="${RW.escape(user.name)}">${RW.escape(user.name)}</a>` +
        (user.is_guest ? '<span class="guest-tag">Ospite</span>' : "") +
        '<button class="btn btn-control" type="button" data-logout>Esci</button>'
      : `<a class="header-signup" href="/login.html?next=${next}">Registrati</a>` +
        '<span class="header-or">oppure</span>' +
        `<a class="btn btn-control btn-control-large" href="/login.html?next=${next}">Accedi</a>` +
        '<button class="btn btn-control" type="button" data-guest>Ospite</button>';
    return `<div class="header-inner">
      <a class="brand" href="/"><span class="brand-stud" aria-hidden="true"></span>RobloxWeb</a>
      <nav class="main-nav" aria-label="Navigazione principale">${nav.join("")}</nav>
      <div class="header-account" id="account-nav">${account}</div>
    </div>`;
  };

  RW.footerHTML = function (user) {
    const links = [
      '<a href="/">Home</a>',
      `<a href="${GAMES_URL}">Giochi</a>`,
      '<a href="/studio.html">Studio</a>',
    ];
    if (user) {
      links.push('<a href="/profile.html">Profilo</a>');
    }
    if (user && user.is_admin) {
      links.push('<a href="/admin.html">Moderazione</a>');
    }
    return `<div class="footer-inner">
      <nav class="footer-links" aria-label="Link del sito">${links.join("")}</nav>
      <div class="footer-legal">© ${FOOTER_YEAR} RobloxWeb — piattaforma di giochi creati dagli utenti. Progetto locale in sviluppo.</div>
    </div>`;
  };

  let headerPromise = null;

  RW.initHeader = function () {
    if (headerPromise) return headerPromise;
    headerPromise = (async () => {
      let user = null;
      try {
        user = await RW.me();
      } catch (_) {
        user = null;
      }
      const header = document.getElementById("site-header");
      if (header) {
        header.innerHTML = RW.headerHTML(user);
      }
      const footer = document.getElementById("site-footer");
      if (footer) {
        footer.innerHTML = RW.footerHTML(user);
      }

      const nav = document.getElementById("account-nav");
      const guestButton = nav && nav.querySelector("[data-guest]");
      if (guestButton) {
        guestButton.addEventListener("click", async () => {
          guestButton.disabled = true;
          const result = await RW.startGuest(window.location.pathname + window.location.search);
          if (!result.ok) {
            guestButton.disabled = false;
            RW.alertDialog("Ospite non disponibile", result.error);
          }
        });
      }
      const logoutButton = nav && nav.querySelector("[data-logout]");
      if (logoutButton) {
        logoutButton.addEventListener("click", () => RW.logout());
      }
      return user;
    })();
    return headerPromise;
  };

  window.RW = RW;
  document.addEventListener("DOMContentLoaded", () => RW.initHeader());

  // Il client Godot chiede alla pagina play di tornare alla pagina del gioco.
  window.addEventListener("message", (event) => {
    if (event.origin !== window.location.origin) return;
    if (event.data && event.data.type === "rw-leave") {
      const place = RW.qs("id");
      window.location.href = place ? `/place.html?id=${encodeURIComponent(place)}` : "/";
    }
  });
})();
