/* ============================================================
   Plant Inventory — shared app chrome & helpers
   "Kalendarz ogrodnika": auth guard, the seasonal accent engine
   (the page recolors itself by where you are in the gardening
   year), the book-spine sidebar, and the year-band signature.
   Loaded before each page script.
   ============================================================ */

const API = 'https://c072lvqc8i.execute-api.eu-central-1.amazonaws.com/dev';
const USER_ID = localStorage.getItem('user_id');
const USER_NAME = localStorage.getItem('user_name') || 'Gość';

// Auth guard — redirect to login if not signed in.
if (!USER_ID) { window.location.href = 'login.html'; }

/* ---------- The seasons of the gardener's year ---------- */
const SEASONS = {
  winter: { key: 'winter', label: 'Zima',   accent: '#5b7184', wash: '#dde0dd', ink: '#33414c', months: [11, 0, 1]  },
  spring: { key: 'spring', label: 'Wiosna', accent: '#6e8e3f', wash: '#e3e2c6', ink: '#3f5121', months: [2, 3, 4]   },
  summer: { key: 'summer', label: 'Lato',   accent: '#bf8a2c', wash: '#ece1c2', ink: '#4a3712', months: [5, 6, 7]   },
  autumn: { key: 'autumn', label: 'Jesień', accent: '#a65420', wash: '#ecd9c4', ink: '#5a2d11', months: [8, 9, 10]  },
};
const MONTHS_PL  = ['Styczeń','Luty','Marzec','Kwiecień','Maj','Czerwiec','Lipiec','Sierpień','Wrzesień','Październik','Listopad','Grudzień'];
const MONTHS_ABBR = ['Sty','Lut','Mar','Kwi','Maj','Cze','Lip','Sie','Wrz','Paź','Lis','Gru'];

function seasonFor(date) {
  const m = date.getMonth();
  for (const s of Object.values(SEASONS)) if (s.months.includes(m)) return s;
  return SEASONS.summer;
}

// Paint the live accent vars from today's season.
function applySeason(date = new Date()) {
  const s = seasonFor(date);
  const root = document.documentElement.style;
  root.setProperty('--accent', s.accent);
  root.setProperty('--accent-wash', s.wash);
  root.setProperty('--accent-ink', s.ink);
  document.documentElement.dataset.season = s.key;
  return s;
}
const CURRENT_SEASON = applySeason();

/* day-of-year fraction, used to place marks along the year-band */
function yearFraction(date) {
  const start = new Date(date.getFullYear(), 0, 1);
  const next  = new Date(date.getFullYear() + 1, 0, 1);
  return (date - start) / (next - start);
}

/* ---------- The year-band (signature) ----------
   Renders the whole gardening year as an almanac strip: faint
   season zones, month ticks, your tasks plotted in time, and a
   "you are here" marker. tasks: [{date, status|_done}] */
function renderYearBand(mountId, tasks = []) {
  const mount = document.getElementById(mountId);
  if (!mount) return;
  const now = new Date();
  const s = seasonFor(now);
  const nowPct = yearFraction(now) * 100;

  // season zones, in calendar order: winter(Dec-Feb wraps), spring, summer, autumn
  const zones = [
    { label: 'Zima',   start: 0,    end: 2/12,  key: 'winter' },
    { label: 'Wiosna', start: 2/12, end: 5/12,  key: 'spring' },
    { label: 'Lato',   start: 5/12, end: 8/12,  key: 'summer' },
    { label: 'Jesień', start: 8/12, end: 11/12, key: 'autumn' },
    { label: 'Zima',   start: 11/12, end: 1,    key: 'winter' },
  ];
  const zoneHtml = zones.map(z => {
    const left = z.start * 100, w = (z.end - z.start) * 100;
    const tint = SEASONS[z.key].wash;
    const showLabel = (z.end - z.start) > 0.12;
    return `<div class="yb-zone" style="left:${left}%;width:${w}%;background:${tint}">
      ${showLabel ? `<span class="yb-zone-label">${z.label}</span>` : ''}
    </div>`;
  }).join('');

  const taskHtml = tasks.map(t => {
    const d = new Date(t.date);
    if (isNaN(d)) return '';
    const done = t._done ?? (t.status === 'done');
    return `<div class="yb-task ${done ? 'is-done' : ''}" style="left:${yearFraction(d) * 100}%"></div>`;
  }).join('');

  const monthHtml = MONTHS_ABBR.map((m, i) => {
    const pct = ((i + 0.5) / 12) * 100;
    const isNow = i === now.getMonth();
    return `<span class="yb-month ${isNow ? 'is-now' : ''}" style="left:${pct}%">${m}</span>`;
  }).join('');

  const pending = tasks.filter(t => !(t._done ?? (t.status === 'done'))).length;
  const dateLabel = now.toLocaleDateString('pl-PL', { day: 'numeric', month: 'long' });

  mount.innerHTML = `
    <div class="yearband">
      <div class="yearband-head">
        <div class="yearband-season">${s.label}<small>Rok ogrodnika · ${now.getFullYear()}</small></div>
        <div class="yearband-now">${dateLabel}<br><b>${pending} zadań przed Tobą</b></div>
      </div>
      <div class="yb-track">
        ${zoneHtml}
        ${taskHtml}
        <div class="yb-today" style="left:${nowPct}%"></div>
      </div>
      <div class="yb-months">${monthHtml}</div>
    </div>`;
}

/* ---------- Sidebar (the book spine) ---------- */
const SIDEBAR_LOGO = `
  <svg viewBox="0 0 30 30" aria-hidden="true">
    <rect x="1.5" y="2" width="27" height="26" rx="2.5" fill="#1c160e" stroke="#5a4a2c" stroke-width="1"/>
    <line x1="9" y1="2" x2="9" y2="28" stroke="#5a4a2c" stroke-width="1"/>
    <path d="M19 21 C19 21, 13.5 16, 13.5 11.5 C13.5 8.8, 16.2 7, 19 8.6 C21.8 7, 24.5 8.8, 24.5 11.5 C24.5 16, 19 21, 19 21Z" fill="#bf8a2c"/>
    <line x1="19" y1="8.6" x2="19" y2="21" stroke="#1c160e" stroke-width="1"/>
  </svg>`;

const NAV_ITEMS = [
  { href: 'dashboard.html',  label: 'Planer zadań',  icon: '<rect x="2" y="3" width="12" height="11" rx="1"/><line x1="5" y1="1" x2="5" y2="5"/><line x1="11" y1="1" x2="11" y2="5"/><line x1="2" y1="8" x2="14" y2="8"/>' },
  { href: 'add_plant.html',  label: 'Dodaj roślinę', icon: '<circle cx="8" cy="8" r="6"/><line x1="8" y1="5" x2="8" y2="11"/><line x1="5" y1="8" x2="11" y2="8"/>' },
  { href: 'inventory.html',  label: 'Moje rośliny',  icon: '<path d="M8 2 C5 2, 2 5, 2 8 C2 11, 5 13, 8 14 C11 13, 14 11, 14 8 C14 5, 11 2, 8 2Z"/><line x1="8" y1="2" x2="8" y2="14"/><line x1="2" y1="8" x2="14" y2="8"/>' },
  { href: 'yearly_plan.html', label: 'Plan roczny',  icon: '<rect x="2" y="2" width="12" height="12" rx="1"/><line x1="5" y1="6" x2="11" y2="6"/><line x1="5" y1="9" x2="11" y2="9"/><line x1="5" y1="12" x2="8" y2="12"/>' },
  { href: 'print.html',      label: 'Generuj PDF',   icon: '<path d="M4 2 H10 L13 5 V14 H4 Z"/><path d="M10 2 V5 H13"/><line x1="6" y1="8" x2="11" y2="8"/><line x1="6" y1="11" x2="11" y2="11"/>' },
];

function renderSidebar() {
  const mount = document.getElementById('sidebar-mount');
  if (!mount) return;
  const current = (location.pathname.split('/').pop() || 'dashboard.html');
  const navHtml = NAV_ITEMS.map(item => {
    const active = item.href !== '#' && item.href === current ? ' active' : '';
    return `<a class="nav-item${active}" href="${item.href}">
      <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" aria-hidden="true">${item.icon}</svg>
      ${item.label}
    </a>`;
  }).join('');

  mount.innerHTML = `
    <div class="sidebar-overlay" id="sidebar-overlay" onclick="toggleSidebar()"></div>
    <div class="sidebar" id="sidebar">
      <div class="sidebar-logo">
        ${SIDEBAR_LOGO}
        <span class="sidebar-logo-text">Plant Inventory<span class="sidebar-logo-sub">Kalendarz ogrodnika</span></span>
      </div>
      <nav class="sidebar-nav">${navHtml}</nav>
      <div class="sidebar-bottom" id="user-email-display">${USER_ID || ''}</div>
      <button class="btn-logout" onclick="logout()">Wyloguj się</button>
    </div>`;
}

function logout() {
  if (!confirm('Czy na pewno chcesz się wylogować?')) return;
  localStorage.clear();
  window.location.href = 'login.html';
}

function toggleSidebar() {
  const sidebar = document.getElementById('sidebar');
  const overlay = document.getElementById('sidebar-overlay');
  if (!sidebar) return;
  if (window.innerWidth <= 768) {
    sidebar.classList.toggle('open');
    if (overlay) overlay.classList.toggle('visible');
  } else {
    sidebar.classList.toggle('collapsed');
  }
}

document.addEventListener('DOMContentLoaded', () => {
  renderSidebar();
  const greet = document.getElementById('user-greet');
  if (greet) greet.textContent = USER_NAME;
});
