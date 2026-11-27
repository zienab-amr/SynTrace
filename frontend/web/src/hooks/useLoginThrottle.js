import { useCallback, useEffect, useState } from 'react';

// UX brake only (a determined attacker ignores the browser): the REAL rate limit and lockout
// must be enforced by the backend. This just slows honest mistakes and shows the server's Retry-After.
const KEY = 'st-login-throttle';
const FREE_ATTEMPTS = 5;
const BASE_SECONDS = 30;
const MAX_SECONDS = 900;

function read() {
  try {
    const value = JSON.parse(sessionStorage.getItem(KEY) || 'null');
    if (value && Number.isFinite(value.fails) && Number.isFinite(value.until)) return value;
  } catch {
    /* ignore */
  }
  return { fails: 0, until: 0 };
}

function write(value) {
  try {
    sessionStorage.setItem(KEY, JSON.stringify(value));
  } catch {
    /* ignore */
  }
}

export function useLoginThrottle() {
  const [state, setState] = useState(read);
  const [now, setNow] = useState(() => Date.now());

  useEffect(() => {
    if (state.until <= Date.now()) return undefined;
    const id = setInterval(() => setNow(Date.now()), 500);
    return () => clearInterval(id);
  }, [state.until]);

  const remaining = Math.max(0, Math.ceil((state.until - now) / 1000));

  const recordFailure = useCallback(() => {
    const current = read();
    const fails = current.fails + 1;
    const over = fails - FREE_ATTEMPTS;
    const seconds = over >= 0 ? Math.min(MAX_SECONDS, BASE_SECONDS * 2 ** over) : 0;
    const next = { fails, until: seconds ? Date.now() + seconds * 1000 : 0 };
    write(next);
    setState(next);
    setNow(Date.now());
  }, []);

  const lockFor = useCallback((seconds) => {
    const next = { ...read(), until: Date.now() + Math.min(MAX_SECONDS, Math.max(1, seconds)) * 1000 };
    write(next);
    setState(next);
    setNow(Date.now());
  }, []);

  const reset = useCallback(() => {
    const next = { fails: 0, until: 0 };
    write(next);
    setState(next);
  }, []);

  return { locked: remaining > 0, remaining, recordFailure, lockFor, reset };
}
