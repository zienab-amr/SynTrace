// One theme for the whole app. The choice is saved, applied to <html data-theme>,
// synced across tabs, and every page reads colours from the CSS tokens in index.css.
// Until the user chooses, the system preference is followed.

const STORAGE_KEY = 'st-theme'; // 'dark' | 'light'  (absent = follow system)
const media = window.matchMedia('(prefers-color-scheme: light)');
const listeners = new Set();

function readStored() {
  try {
    const value = localStorage.getItem(STORAGE_KEY);
    return value === 'dark' || value === 'light' ? value : null;
  } catch {
    return null;
  }
}

let stored = readStored();
const resolve = () => stored ?? (media.matches ? 'light' : 'dark');
let current = resolve();

function apply() {
  current = resolve();
  document.documentElement.dataset.theme = current;
  const meta = document.querySelector('meta[name="theme-color"]');
  if (meta) meta.setAttribute('content', current === 'light' ? '#ebf5ff' : '#071329');
  listeners.forEach((listener) => listener({ resolved: current, chosen: stored }));
}

media.addEventListener('change', () => {
  if (stored === null) apply();
});

// Keep several open tabs in sync.
window.addEventListener('storage', (event) => {
  if (event.key === STORAGE_KEY) {
    stored = readStored();
    apply();
  }
});

export const themeController = {
  init: apply,
  get resolved() {
    return current;
  },
  set(next) {
    stored = next === 'light' || next === 'dark' ? next : null;
    try {
      if (stored) localStorage.setItem(STORAGE_KEY, stored);
      else localStorage.removeItem(STORAGE_KEY);
    } catch {
      /* storage can be blocked (private mode): the theme still applies for this session */
    }
    apply();
  },
  toggle() {
    this.set(current === 'dark' ? 'light' : 'dark');
  },
  subscribe(listener) {
    listeners.add(listener);
    return () => listeners.delete(listener);
  },
};
