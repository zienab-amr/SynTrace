import { ENDPOINTS, USE_MOCK_AUTH } from '../config/api.js';
import { HttpError, refreshSession, request } from './apiClient.js';
import { tokenStore } from './tokenStore.js';

// Every failure becomes one of these codes. The UI shows generic messages on purpose:
// it must never reveal whether an email exists.
export class AuthError extends Error {
  constructor(code, { retryAfter } = {}) {
    super(code);
    this.name = 'AuthError';
    this.code = code; // INVALID_CREDENTIALS | FORBIDDEN | RATE_LIMITED | NETWORK | SERVER
    this.retryAfter = retryAfter;
  }
}

function mapError(error) {
  if (error instanceof AuthError) return error;
  if (error instanceof HttpError) {
    if (error.status === 400 || error.status === 401) return new AuthError('INVALID_CREDENTIALS');
    if (error.status === 403) return new AuthError('FORBIDDEN');
    if (error.status === 429) {
      const seconds = Number.parseInt(error.headers?.get('Retry-After') ?? '', 10);
      return new AuthError('RATE_LIMITED', { retryAfter: Number.isFinite(seconds) ? seconds : 60 });
    }
    return new AuthError('SERVER');
  }
  return new AuthError('NETWORK');
}

// Keep only the fields the UI needs.
const toUser = (raw) =>
  raw && typeof raw === 'object'
    ? { id: raw.id, name: raw.name, email: raw.email, role: raw.role, companyId: raw.companyId }
    : null;

/* ------------------------- real backend ------------------------- */
const realAuth = {
  async login(email, password) {
    try {
      const data = await request(ENDPOINTS.login, { method: 'POST', body: { email, password }, auth: false });
      tokenStore.set(data?.accessToken);
      return toUser(data?.user);
    } catch (error) {
      throw mapError(error);
    }
  },
  async restoreSession() {
    try {
      const data = await refreshSession();
      return toUser(data?.user);
    } catch {
      return null;
    }
  },
  async logout() {
    try {
      await request(ENDPOINTS.logout, { method: 'POST' });
    } catch {
      /* the local session is cleared either way */
    } finally {
      tokenStore.clear();
    }
  },
};

/* ---------------------- development mock only ---------------------- */
// Demo account (mock only, never shipped): demo@syntrace.dev / SynTrace#2026
const MOCK_KEY = 'st-mock-session';
let mockFails = [];
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const mockAuth = {
  async login(email, password) {
    await wait(650);
    const now = Date.now();
    mockFails = mockFails.filter((time) => now - time < 60000);
    if (mockFails.length >= 8) throw new AuthError('RATE_LIMITED', { retryAfter: 20 });
    if (email === 'demo@syntrace.dev' && password === 'SynTrace#2026') {
      const user = { id: 'u-demo', name: 'Demo Admin', email, role: 'Admin', companyId: 'c-demo' };
      tokenStore.set('mock-access-token');
      try {
        sessionStorage.setItem(MOCK_KEY, JSON.stringify(user));
      } catch {
        /* ignore */
      }
      return user;
    }
    mockFails.push(now);
    throw new AuthError('INVALID_CREDENTIALS');
  },
  async restoreSession() {
    try {
      const raw = sessionStorage.getItem(MOCK_KEY);
      if (raw) {
        tokenStore.set('mock-access-token');
        return JSON.parse(raw);
      }
    } catch {
      /* ignore */
    }
    return null;
  },
  async logout() {
    tokenStore.clear();
    try {
      sessionStorage.removeItem(MOCK_KEY);
    } catch {
      /* ignore */
    }
  },
};

export const authService = USE_MOCK_AUTH ? mockAuth : realAuth;
