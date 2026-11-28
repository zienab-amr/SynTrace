import { API_BASE_URL, ENDPOINTS } from '../config/api.js';
import { tokenStore } from './tokenStore.js';

const TIMEOUT_MS = 20000;

export class HttpError extends Error {
  constructor(status, data, headers) {
    super(data?.detail || data?.message || data?.title || `HTTP ${status}`);
    this.name = 'HttpError';
    this.status = status;
    this.data = data;
    this.headers = headers;
  }
}

async function send(path, { method = 'GET', body, auth = true, signal, timeoutMs = TIMEOUT_MS } = {}) {
  // An empty API_BASE_URL is intentional in production: fetch('/api/...')
  // reaches the shared domain root, independently of the React '/web/' mount.

  const controller = new AbortController();
  const abortFromCaller = () => controller.abort(signal?.reason);
  const timer = window.setTimeout(() => controller.abort(new DOMException('Request timed out', 'TimeoutError')), timeoutMs);
  signal?.addEventListener('abort', abortFromCaller, { once: true });
  if (signal?.aborted) abortFromCaller();

  const headers = { Accept: 'application/json', 'X-Requested-With': 'XMLHttpRequest' };
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  const token = tokenStore.get();
  if (auth && token) headers.Authorization = `Bearer ${token}`;

  try {
    const response = await fetch(`${API_BASE_URL}${path}`, {
      method,
      headers,
      body: body !== undefined ? JSON.stringify(body) : undefined,
      // The current API returns refresh tokens in JSON, not cookies. Omitting credentials
      // also matches the API's non-credentialed CORS policy.
      credentials: 'omit',
      cache: 'no-store',
      redirect: 'error',
      signal: controller.signal,
    });

    if (response.status === 204) return null;
    const contentType = response.headers.get('content-type') || '';
    let data = null;
    if (contentType.includes('json')) data = await response.json().catch(() => null);
    else {
      const text = await response.text().catch(() => '');
      data = text ? { message: text } : null;
    }
    if (!response.ok) throw new HttpError(response.status, data, response.headers);
    return data;
  } finally {
    window.clearTimeout(timer);
    signal?.removeEventListener('abort', abortFromCaller);
  }
}

let refreshing = null;
export function refreshSession() {
  if (!refreshing) {
    const refreshToken = tokenStore.getRefresh();
    if (!refreshToken) return Promise.reject(new HttpError(401, { message: 'No refresh token is available.' }, null));
    refreshing = send(ENDPOINTS.refresh, {
      method: 'POST',
      auth: false,
      body: { refreshToken },
    }).then((data) => {
      if (!data?.accessToken || !data?.refreshToken) throw new Error('The refresh endpoint returned an incomplete token response.');
      tokenStore.setPair(data);
      return data;
    }).finally(() => { refreshing = null; });
  }
  return refreshing;
}

export async function request(path, options = {}) {
  try {
    return await send(path, options);
  } catch (error) {
    if (error instanceof HttpError && error.status === 401 && options.auth !== false) {
      try {
        await refreshSession();
      } catch (refreshError) {
        tokenStore.clear();
        window.dispatchEvent(new Event('auth:expired'));
        throw refreshError instanceof HttpError ? refreshError : error;
      }
      return send(path, options);
    }
    throw error;
  }
}
