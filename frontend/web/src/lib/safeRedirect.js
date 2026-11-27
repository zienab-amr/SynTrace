// "?redirect=" must never become an open redirect. Only same-site absolute paths are allowed.
export function safeRedirect(value, fallback = '/app') {
  if (typeof value !== 'string' || value.length === 0 || value.length > 512) return fallback;
  if (!value.startsWith('/') || value.startsWith('//') || value.includes('\\')) return fallback;
  if (/[\u0000-\u001f\u007f]/.test(value)) return fallback;
  try {
    const url = new URL(value, window.location.origin);
    if (url.origin !== window.location.origin) return fallback;
    if (url.pathname === '/login' || url.pathname === '/') return fallback;
    return url.pathname + url.search + url.hash;
  } catch {
    return fallback;
  }
}
