/* ==========================================================================
   PROTOTIPO — logica usa-e-getta (switcher, card finte, menu client)
   NON fa parte del sito di produzione.
   ========================================================================== */

'use strict';

const GAMES = [
  { name: 'Welcome Obby', author: 'RobloxWeb', playing: '1.234', likes: '128', a: '#79c7ea', b: '#245a9e' },
  { name: 'Lava Escape', author: 'RobloxWeb', playing: '2.412', likes: '512', a: '#f0b35a', b: '#a8422a' },
  { name: 'Corsa tra i Cubi', author: 'Blocco99', playing: '862', likes: '74', a: '#9ad1f0', b: '#2a6f9e' },
  { name: 'Torre Infinita', author: 'BuilderMax', playing: '541', likes: '39', a: '#c7a4ff', b: '#5b2d8e' },
  { name: 'Città dei Blocchi', author: 'RobloxWeb', playing: '3.105', likes: '880', a: '#a7d8a0', b: '#316b2e' },
  { name: 'Isola Segreta', author: 'LavaGirl', playing: '233', likes: '21', a: '#7fe0c8', b: '#0b6b62' },
  { name: 'Speed Run 4', author: 'Blocco99', playing: '1.876', likes: '301', a: '#ffd37a', b: '#b56b00' },
  { name: 'Parco Acquatico', author: 'demo', playing: '654', likes: '55', a: '#8fdcff', b: '#0a6fa8' },
  { name: 'Battaglia di Palloni', author: 'BuilderMax', playing: '980', likes: '112', a: '#ff9f9f', b: '#9e1f1f' }
];

const VARIANTS = ['A', 'B', 'C'];

const LABELS = {
  home: {
    A: 'A — Griglia 2014 (970 + sidebar)',
    B: 'B — Home attuale, pelle 2014',
    C: 'C — Vetrina 2014'
  },
  client: {
    A: 'A — Fedele 2014 (no topbar)',
    B: 'B — Ibrido (topbar HTML)',
    C: 'C — HUD attuale, pelle 2014'
  }
};

const page = document.body.dataset.prototype;
let current = normalize(new URLSearchParams(location.search).get('variant'));

function normalize(value) {
  const upper = String(value || '').toUpperCase();
  return VARIANTS.includes(upper) ? upper : 'B';
}

function cardHtml(game) {
  return `
    <a class="game-card" href="#" data-game>
      <div class="thumb" style="--a:${game.a};--b:${game.b}"></div>
      <div class="name">${game.name}</div>
      <div class="meta">di ${game.author}</div>
      <div class="meta">${game.playing} che giocano · <span class="likes">★ ${game.likes}</span></div>
    </a>`;
}

function renderCards(selector, count) {
  const target = document.querySelector(selector);
  if (!target) return;
  target.innerHTML = GAMES.slice(0, count).map(cardHtml).join('');
}

function cloneSidebars() {
  const tpl = document.getElementById('sidebar-tpl');
  if (!tpl) return;
  document.querySelectorAll('.sidebar-slot').forEach((slot) => {
    slot.appendChild(tpl.content.cloneNode(true));
  });
}

function applyVariant(value) {
  current = normalize(value);

  document.querySelectorAll('[data-variant]').forEach((el) => {
    el.hidden = el.dataset.variant !== current;
  });

  const label = document.querySelector('[data-label]');
  if (label) label.textContent = LABELS[page][current];

  const url = new URL(location.href);
  url.searchParams.set('variant', current);
  history.replaceState(null, '', url);

  if (page === 'home') {
    document.body.classList.toggle('wide', current === 'B');
  }

  if (page === 'client') {
    const topbar = document.querySelector('[data-topbar]');
    const hasTopbar = current === 'B';
    if (topbar) topbar.hidden = !hasTopbar;
    document.body.classList.toggle('has-topbar', hasTopbar);
  }
}

function step(direction) {
  const index = VARIANTS.indexOf(current);
  const next = VARIANTS[(index + direction + VARIANTS.length) % VARIANTS.length];
  applyVariant(next);
}

function isEditable(target) {
  const tag = (target.tagName || '').toLowerCase();
  return tag === 'input' || tag === 'textarea' || target.isContentEditable;
}

/* --- switcher ----------------------------------------------------------- */

document.querySelector('[data-prev]')?.addEventListener('click', () => step(-1));
document.querySelector('[data-next]')?.addEventListener('click', () => step(1));

document.addEventListener('keydown', (event) => {
  if (isEditable(event.target)) return;
  if (event.key === 'ArrowLeft') {
    event.preventDefault();
    step(-1);
  } else if (event.key === 'ArrowRight') {
    event.preventDefault();
    step(1);
  }
});

/* --- home --------------------------------------------------------------- */

if (page === 'home') {
  renderCards('#grid-a', 9);
  renderCards('#grid-b', 8);
  renderCards('#grid-c', 6);
  cloneSidebars();
}

/* --- client ------------------------------------------------------------- */

if (page === 'client') {
  const shield = document.querySelector('[data-shield]');
  const menu = document.querySelector('[data-menu]');
  const leaveDialog = document.querySelector('[data-leave-dialog]');
  const loading = document.querySelector('[data-loading]');
  const toast = document.querySelector('[data-toast]');

  function openMenu() {
    closeLeave();
    menu.classList.add('open');
    shield.classList.add('open');
  }

  function closeMenu() {
    menu.classList.remove('open');
    if (!leaveDialog.classList.contains('open')) shield.classList.remove('open');
  }

  function openLeave() {
    closeMenu();
    leaveDialog.classList.add('open');
    shield.classList.add('open');
  }

  function closeLeave() {
    leaveDialog.classList.remove('open');
    if (!menu.classList.contains('open')) shield.classList.remove('open');
  }

  document.querySelectorAll('[data-open-menu]').forEach((button) => {
    button.addEventListener('click', openMenu);
  });
  document.querySelectorAll('[data-close-menu]').forEach((button) => {
    button.addEventListener('click', closeMenu);
  });
  document.querySelectorAll('[data-leave]').forEach((button) => {
    button.addEventListener('click', openLeave);
  });
  document.querySelectorAll('[data-stay]').forEach((button) => {
    button.addEventListener('click', closeLeave);
  });
  document.querySelectorAll('[data-confirm-leave]').forEach((button) => {
    button.addEventListener('click', () => { location.href = 'home.html'; });
  });
  document.querySelectorAll('[data-noop]').forEach((button) => {
    button.addEventListener('click', () => {});
  });

  shield.addEventListener('click', () => {
    closeLeave();
    closeMenu();
  });

  document.querySelectorAll('[data-collapse]').forEach((header) => {
    header.addEventListener('click', () => {
      header.closest('.playerlist').classList.toggle('collapsed');
    });
  });

  function addChatLine(text) {
    document.querySelectorAll('.chat .log').forEach((log) => {
      const line = document.createElement('div');
      line.className = 'line';
      const name = document.createElement('span');
      name.className = 'name';
      name.style.color = '#c4281c';
      name.textContent = 'tu';
      line.append(name, document.createTextNode(': ' + text));
      log.appendChild(line);
      while (log.children.length > 8) log.removeChild(log.firstElementChild);
    });
  }

  document.querySelectorAll('.chat-bar').forEach((input) => {
    input.addEventListener('keydown', (event) => {
      if (event.key !== 'Enter') return;
      const text = input.value.trim();
      if (!text) return;
      addChatLine(text);
      input.value = '';
      input.blur();
    });
  });

  document.addEventListener('keydown', (event) => {
    if (isEditable(event.target)) return;

    if (event.key === '/') {
      event.preventDefault();
      document.querySelector(`[data-variant="${current}"] .chat-bar`)?.focus();
      return;
    }

    if (event.key === 'Escape') {
      if (leaveDialog.classList.contains('open')) {
        closeLeave();
      } else if (menu.classList.contains('open')) {
        closeMenu();
      } else {
        openMenu();
      }
    }
  });

  document.querySelector('[data-show-game]')?.addEventListener('click', () => {
    loading.classList.remove('open');
    toast.classList.remove('open');
    closeLeave();
    closeMenu();
  });

  document.querySelector('[data-show-loading]')?.addEventListener('click', () => {
    closeLeave();
    closeMenu();
    loading.classList.add('open');
    window.setTimeout(() => loading.classList.remove('open'), 1800);
  });

  document.querySelector('[data-show-toast]')?.addEventListener('click', () => {
    toast.classList.add('open');
    window.setTimeout(() => toast.classList.remove('open'), 5000);
  });
}

/* --- card click (nessuna navigazione) ----------------------------------- */

document.addEventListener('click', (event) => {
  const card = event.target.closest('[data-game]');
  if (card) event.preventDefault();
});

/* --- avvio -------------------------------------------------------------- */

applyVariant(current);
