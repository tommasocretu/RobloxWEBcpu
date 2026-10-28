/* RobloxWeb — utilità condivise del sito (vanilla JS, nessun build step). */
(function () {
  "use strict";

  const RW = {};
  const PALETTES = [
    ["#1f4d7a", "#3f8fca"],
    ["#2b5e4a", "#4fc28a"],
    ["#5a3a77", "#a06bd0"],
    ["#7a3a3f", "#d06b73"],
    ["#6b5523", "#d0a94f"],
    ["#244a63", "#4aa7c2"],
    ["#4b3a6b", "#8d6bd0"],
    ["#2d5a2d", "#6bc25a"],
  ];

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
    if (!value || !value.startsWith("/") || value.startsWith("//")) {
      return fallback || "/";
    }
    return value;
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
      return {
        ok: response.ok,
        status: response.status,
        data: data,
        error: (data && data.error) || `Errore HTTP ${response.status}`,
      };
    } catch (err) {
      return { ok: false, status: 0, data: null, error: "Server non raggiungibile." };
    }
  };

  RW.me = async function () {
    const result = await RW.api("/api/me");
    return result.ok && result.data ? result.data.user : null;
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

  RW.thumbStyle = function (place) {
    const colors = RW.palette(place);
    return `background: linear-gradient(135deg, ${colors[0]}, ${colors[1]});`;
  };

  RW.thumbHTML = function (place, extraClass) {
    if (place && place.thumbnail_url) {
      return `<img src="${RW.escape(place.thumbnail_url)}" alt="${RW.escape(place.title)}">`;
    }
    const initial = RW.escape((place && place.title ? place.title : "?").slice(0, 1).toUpperCase());
    const cls = extraClass ? ` ${extraClass}` : "";
    return `<div class="card-thumb${cls}" style="${RW.thumbStyle(place)}">${initial}` +
      `<span class="live">${RW.formatNumber(place && place.live_players)}</span></div>`;
  };

  RW.card = function (place) {
    const live = Number(place.live_players || 0);
    return `
      <article class="card">
        <a href="/place.html?id=${encodeURIComponent(place.id)}">
          ${RW.thumbHTML(place)}
          <div class="card-body">
            <h3 class="card-title">${RW.escape(place.title)}</h3>
            <div class="card-meta">
              di ${RW.escape(place.author)}
              <span class="dot">·</span>${RW.formatNumber(place.visits)} visite
              ${live > 0 ? `<span class="dot">·</span>${live} online` : ""}
            </div>
          </div>
        </a>
      </article>`;
  };

  RW.setAlert = function (element, message, kind) {
    if (!element) return;
    element.className = "alert alert-" + (kind || "error");
    element.textContent = message;
    element.hidden = !message;
  };

  RW.headerHTML = function () {
    const q = RW.qs("q") || "";
    const next = encodeURIComponent(window.location.pathname + window.location.search);
    return `
      <a class="brand" href="/">Roblox<span>Web</span></a>
      <nav class="main-nav">
        <a href="/">Home</a>
        <a href="/studio.html">Studio</a>
      </nav>
      <form class="header-search" action="/" method="get" role="search">
        <input type="search" name="q" value="${RW.escape(q)}" placeholder="Cerca esperienze o autori…" aria-label="Cerca">
      </form>
      <div class="account-nav" id="account-nav">
        <a class="btn btn-ghost" href="/login.html?next=${next}">Accedi</a>
      </div>`;
  };

  let headerPromise = null;

  RW.initHeader = function () {
    if (headerPromise) return headerPromise;
    const header = document.getElementById("site-header");
    if (!header) return Promise.resolve(null);
    headerPromise = (async () => {
      header.innerHTML = RW.headerHTML();
      const nav = document.getElementById("account-nav");
      const user = await RW.me();
      const next = encodeURIComponent(window.location.pathname + window.location.search);
      if (!user) {
        nav.innerHTML =
          `<a class="btn btn-ghost" href="/login.html?next=${next}">Accedi</a>` +
          `<button class="btn" type="button" data-guest>Ospite</button>`;
      } else {
        nav.innerHTML =
          `<a class="who" href="/profile.html" title="${RW.escape(user.name)}">${RW.escape(user.name)}</a>` +
          (user.is_guest ? `<span class="guest-tag">Ospite</span>` : "") +
          `<button class="btn btn-ghost" type="button" data-logout>Esci</button>`;
      }
      const guestButton = nav.querySelector("[data-guest]");
      if (guestButton) {
        guestButton.addEventListener("click", async () => {
          guestButton.disabled = true;
          const result = await RW.startGuest(next);
          if (!result.ok) {
            guestButton.disabled = false;
            alert(result.error);
          }
        });
      }
      const logoutButton = nav.querySelector("[data-logout]");
      if (logoutButton) {
        logoutButton.addEventListener("click", () => RW.logout());
      }
      return user;
    })();
    return headerPromise;
  };

  window.RW = RW;
  document.addEventListener("DOMContentLoaded", () => RW.initHeader());

  // Il client Godot chiede alla pagina play di tornare alla pagina dell'esperienza.
  window.addEventListener("message", (event) => {
    if (event.origin !== window.location.origin) return;
    if (event.data && event.data.type === "rw-leave") {
      const place = RW.qs("id");
      window.location.href = place ? `/place.html?id=${encodeURIComponent(place)}` : "/";
    }
  });
})();
