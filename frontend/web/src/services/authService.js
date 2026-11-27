import { ENDPOINTS, USE_MOCK_AUTH } from '../config/api.js';
import { HttpError, refreshSession, request } from './apiClient.js';
import { tokenStore } from './tokenStore.js';

export class AuthError extends Error {
  constructor(code, { retryAfter, message } = {}) {
    super(message || code);
    this.name = 'AuthError';
    this.code = code;
    this.retryAfter = retryAfter;
  }
}

function mapError(error) {
  if (error instanceof AuthError) return error;
  if (error instanceof HttpError) {
    const message = error.data?.detail || error.data?.message || error.data?.title;
    if (error.status === 400 || error.status === 401) return new AuthError('INVALID_CREDENTIALS', { message });
    if (error.status === 403) return new AuthError('FORBIDDEN', { message });
    if (error.status === 429) {
      const seconds = Number.parseInt(error.headers?.get('Retry-After') ?? '', 10);
      return new AuthError('RATE_LIMITED', { retryAfter: Number.isFinite(seconds) ? seconds : 60, message });
    }
    return new AuthError('SERVER', { message });
  }
  if (error?.name === 'AbortError' || error?.name === 'TimeoutError') return new AuthError('NETWORK', { message: 'The server did not respond in time.' });
  return new AuthError('NETWORK', { message: error?.message });
}

function read(raw, camel, pascal) { return raw?.[camel] ?? raw?.[pascal]; }
function toUser(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const roles = read(raw, 'roles', 'Roles') || [];
  const roleNames = roles.map((item) => item?.name ?? item?.Name).filter(Boolean);
  const firstName = read(raw, 'firstName', 'FirstName') || '';
  const lastName = read(raw, 'lastName', 'LastName') || '';
  return {
    id: read(raw, 'id', 'Id'),
    name: `${firstName} ${lastName}`.trim() || read(raw, 'email', 'Email') || 'Workspace member',
    firstName,
    lastName,
    email: read(raw, 'email', 'Email'),
    phoneNumber: read(raw, 'phoneNumber', 'PhoneNumber'),
    role: roleNames[0] || 'Workspace member',
    roles: roleNames,
    companyId: read(raw, 'companyId', 'CompanyId'),
  };
}

async function getCurrentUser() {
  const raw = await request(ENDPOINTS.me);
  const user = toUser(raw);
  if (!user?.id || !user.companyId) throw new Error('The current employee endpoint returned an incomplete profile.');
  return user;
}

const realAuth = {
  async login(email, password) {
    try {
      const tokens = await request(ENDPOINTS.login, {
        method: 'POST', auth: false,
        body: { request: { email, password } },
      });
      if (!tokens?.accessToken || !tokens?.refreshToken) throw new Error('The login endpoint did not return both tokens.');
      tokenStore.setPair(tokens);
      try { return await getCurrentUser(); }
      catch (error) { tokenStore.clear(); throw error; }
    } catch (error) { throw mapError(error); }
  },
  async restoreSession() {
    if (!tokenStore.getRefresh()) return null;
    try {
      await refreshSession();
      return await getCurrentUser();
    } catch {
      tokenStore.clear();
      return null;
    }
  },
  async logout() {
    const refreshToken = tokenStore.getRefresh();
    try {
      if (refreshToken) await request(ENDPOINTS.logout, { method: 'POST', body: { refreshToken }, auth: false });
    } finally { tokenStore.clear(); }
  },
};

const MOCK_KEY = 'st-mock-session';
let mockFails = [];
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const mockAuth = {
  async login(email, password) {
    await wait(450);
    const now = Date.now();
    mockFails = mockFails.filter((time) => now - time < 60000);
    if (mockFails.length >= 8) throw new AuthError('RATE_LIMITED', { retryAfter: 20 });
    if (email === 'demo@syntrace.dev' && password === 'SynTrace#2026') {
      const user = { id: 'u-demo', name: 'Demo Admin', email, role: 'Admin', roles: ['Admin'], companyId: 'c-demo' };
      tokenStore.set('mock-access-token');
      tokenStore.setRefresh('mock-refresh-token');
      try { sessionStorage.setItem(MOCK_KEY, JSON.stringify(user)); } catch { /* ignore */ }
      return user;
    }
    mockFails.push(now);
    throw new AuthError('INVALID_CREDENTIALS');
  },
  async restoreSession() {
    try {
      const raw = sessionStorage.getItem(MOCK_KEY);
      if (raw) { tokenStore.set('mock-access-token'); tokenStore.setRefresh('mock-refresh-token'); return JSON.parse(raw); }
    } catch { /* ignore */ }
    return null;
  },
  async logout() {
    tokenStore.clear();
    try { sessionStorage.removeItem(MOCK_KEY); } catch { /* ignore */ }
  },
};

export const authService = USE_MOCK_AUTH ? mockAuth : realAuth;
