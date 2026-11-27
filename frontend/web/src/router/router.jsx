import { useMemo, useSyncExternalStore } from 'react';

// Tiny history router (no dependency). When the app grows, swap it for react-router-dom:
// the same three things exist there: <Link>, navigate(), useLocation().
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

const snapshot = () => window.location.pathname + window.location.search;

export function navigate(to, { replace = false } = {}) {
  const url = new URL(to, window.location.origin);
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
      pathname: url.pathname.replace(/\/+$/, '') || '/',
      search: url.search,
      params: new URLSearchParams(url.search),
    };
  }, [raw]);
}

export function Link({ to, replace = false, onClick, children, ...rest }) {
  const handleClick = (event) => {
    onClick?.(event);
    if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    event.preventDefault();
    navigate(to, { replace });
  };
  return (
    <a href={to} onClick={handleClick} {...rest}>
      {children}
    </a>
  );
}
