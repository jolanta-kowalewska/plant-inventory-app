/* ============================================================
   Plant Inventory — shared app chrome & helpers
   Auth guard, sidebar rendering (with auto-active state),
   logout and sidebar toggle. Loaded before each page script.
   ============================================================ */

const API = 'https://c072lvqc8i.execute-api.eu-central-1.amazonaws.com/dev';
const USER_ID = localStorage.getItem('user_id');
const USER_NAME = localStorage.getItem('user_name') || 'Gość';

// Auth guard — redirect to login if not signed in.
if (!USER_ID) { window.location.href = 'login.html'; }

const SIDEBAR_LOGO = `
  <svg viewBox="0 0 28 28" aria-hidden="true"><circle cx="14" cy="14" r="13" fill="#2d6e38" stroke="#4ea85c" stroke-width="0.8"/><path d="M14 22 C14 22, 8 16, 8 11 C8 8, 11 6, 14 8 C17 6, 20 8, 20 11 C20 16, 14 22, 14 22Z" fill="#c0e8c8"/><line x1="14" y1="8" x2="14" y2="22" stroke="#2d6e38" stroke-width="1"/></svg>`;

const NAV_ITEMS = [
  { href: 'dashboard.html',  label: 'Planer zadań',  icon: '<rect x="2" y="3" width="12" height="11" rx="2"/><line x1="5" y1="1" x2="5" y2="5"/><line x1="11" y1="1" x2="11" y2="5"/><line x1="2" y1="8" x2="14" y2="8"/>' },
  { href: 'add_plant.html',  label: 'Dodaj roślinę', icon: '<circle cx="8" cy="8" r="6"/><line x1="8" y1="5" x2="8" y2="11"/><line x1="5" y1="8" x2="11" y2="8"/>' },
  { href: 'inventory.html',  label: 'Moje rośliny',  icon: '<path d="M8 2 C5 2, 2 5, 2 8 C2 11, 5 13, 8 14 C11 13, 14 11, 14 8 C14 5, 11 2, 8 2Z"/><line x1="8" y1="2" x2="8" y2="14"/><line x1="2" y1="8" x2="14" y2="8"/>' },
  { href: 'yearly_plan.html', label: 'Plan roczny',  icon: '<rect x="2" y="2" width="12" height="12" rx="2"/><line x1="5" y1="6" x2="11" y2="6"/><line x1="5" y1="9" x2="11" y2="9"/><line x1="5" y1="12" x2="8" y2="12"/>' },
  { href: '#',               label: 'Generuj PDF',   icon: '<path d="M3 12 L6 9 L9 11 L13 6"/><circle cx="13" cy="6" r="1.5" fill="currentColor" stroke="none"/>' },
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
        <span class="sidebar-logo-text">Plant Inventory</span>
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
