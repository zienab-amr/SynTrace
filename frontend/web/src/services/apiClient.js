import { API_BASE_URL, ENDPOINTS } from '../config/api.js';
import { tokenStore } from './tokenStore.js';

const TIMEOUT_MS = 15000;

export class HttpError extends Error {
  constructor(status, data, headers) {
    super(`HTTP ${status}`);
    this.name = 'HttpError';
    this.status = status;
    this.data = data;
    this.headers = headers;
  }
}

async function send(path, { method = 'GET', body, auth = true, signal } = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  signal?.addEventListener('abort', () => controller.abort(), { once: true });

  const headers = { Accept: 'application/json', 'X-Requested-With': 'XMLHttpRequest' };
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  const token = tokenStore.get();
  if (auth && token) headers.Authorization = `Bearer ${token}`;

  let response;
  try {
    response = await fetch(`${API_BASE_URL}${path}`, {
      method,
      headers,
      body: body !== undefined ? JSON.stringify(body) : undefined,
      credentials: 'include', // sends the HttpOnly refresh cookie
      cache: 'no-store', // never cache auth responses
      redirect: 'error', // never follow redirects with credentials
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timer);
  }

  const isJson = response.headers.get('content-type')?.includes('application/json');
  const data = isJson ? await response.json().catch(() => null) : null;
  if (!response.ok) throw new HttpError(response.status, data, response.headers);
  return data;
}

// One refresh at a time, even if several requests fail together.
let refreshing = null;
export function refreshSession() {
  if (!refreshing) {
    refreshing = send(ENDPOINTS.refresh, { method: 'POST', auth: false })
      .then((data) => {
        tokenStore.set(data?.accessToken);
        return data;
      })
      .finally(() => {
        refreshing = null;
      });
  }
  return refreshing;
}

// Authenticated request: on 401 refresh once and retry once, otherwise end the session.
export async function request(path, options = {}) {
  try {
    return await send(path, options);
  } catch (error) {
    if (error instanceof HttpError && error.status === 401 && options.auth !== false) {
      try {
        await refreshSession();
      } catch {
        tokenStore.clear();
        window.dispatchEvent(new Event('auth:expired'));
        throw error;
      }
      return send(path, options);
    }
    throw error;
  }
}
