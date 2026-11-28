import { useMemo, useSyncExternalStore } from 'react';

// Tiny history router (no dependency). Routes are always expressed without the deployment
// prefix (for example '/login'); this adapter adds/removes Vite's configured base path.
const BASE_PATH = import.meta.env.BASE_URL.replace(/\/$/, '');
const listeners = new Set();
const notify = () => listeners.forEach((listener) => listener());

function subscribe(listener) {
  listeners.add(listener);
  window.addEventListener('popstate', listener);
  return () => {
    listeners.delete(listener);
    window.removeEventListener('popstate', listener);
  };
}

function withBasePath(to) {
  if (typeof to !== 'string' || !to.startsWith('/') || !BASE_PATH) return to;
  if (to === BASE_PATH || to.startsWith(`${BASE_PATH}/`) || to.startsWith(`${BASE_PATH}?`) || to.startsWith(`${BASE_PATH}#`)) return to;
  return `${BASE_PATH}${to}`;
}

function withoutBasePath(pathname) {
  if (!BASE_PATH) return pathname;
  if (pathname === BASE_PATH || pathname === `${BASE_PATH}/`) return '/';
  if (pathname.startsWith(`${BASE_PATH}/`)) return pathname.slice(BASE_PATH.length) || '/';
  return pathname;
}

const snapshot = () => window.location.pathname + window.location.search;

export function navigate(to, { replace = false } = {}) {
  const destination = withBasePath(to);
  const url = new URL(destination, window.location.origin);
  if (url.origin !== window.location.origin) return; // in-app navigation only
  const next = url.pathname + url.search + url.hash;
  const current = window.location.pathname + window.location.search + window.location.hash;
  if (next !== current) window.history[replace ? 'replaceState' : 'pushState']({}, '', next);
  notify();
  window.scrollTo(0, 0);
}

export function useLocation() {
  const raw = useSyncExternalStore(subscribe, snapshot);
  return useMemo(() => {
    const url = new URL(raw, window.location.origin);
    return {
      pathname: withoutBasePath(url.pathname).replace(/\/+$/, '') || '/',
      search: url.search,
      params: new URLSearchParams(url.search),
    };
  }, [raw]);
}

export function Link({ to, replace = false, onClick, children, ...rest }) {
  const href = withBasePath(to);
  const handleClick = (event) => {
    onClick?.(event);
    if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    event.preventDefault();
    navigate(to, { replace });
  };
  return (
    <a href={href} onClick={handleClick} {...rest}>
      {children}
    </a>
  );
}
