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

function read(raw, ...keys) {
  for (const key of keys) {
    if (raw?.[key] !== undefined && raw?.[key] !== null) return raw[key];
  }
  return undefined;
}

// ASP.NET endpoints may return either the DTO directly or wrap it in a standard
// data/result/employee envelope. Normalize that here so auth does not depend on
// the serializer/envelope shape used by a particular gateway version.
function unwrapPayload(value) {
  let current = value;
  for (let depth = 0; depth < 5; depth += 1) {
    if (!current || typeof current !== 'object') return null;
    if (Array.isArray(current)) return current[0] && typeof current[0] === 'object' ? current[0] : null;

    const nested = read(current, 'data', 'Data', 'employee', 'Employee', 'result', 'Result', 'value', 'Value', 'payload', 'Payload');
    if (!nested || typeof nested !== 'object') return current;
    current = nested;
  }
  return current && typeof current === 'object' && !Array.isArray(current) ? current : null;
}

function normalizeRoles(raw) {
  const roles = read(raw, 'roles', 'Roles');
  const value = Array.isArray(roles) && roles.length === 0 ? read(raw, 'role', 'Role') : roles ?? read(raw, 'role', 'Role');
  const entries = Array.isArray(value) ? value : value == null ? [] : [value];
  return entries
    .map((item) => typeof item === 'string' ? item : read(item, 'name', 'Name', 'roleName', 'RoleName'))
    .filter((item) => typeof item === 'string' && item.trim())
    .map((item) => item.trim());
}

function toUser(response, fallbackEmail) {
  const raw = unwrapPayload(response);
  if (!raw) return null;

  const roles = normalizeRoles(raw);
  const firstName = read(raw, 'firstName', 'FirstName', 'givenName', 'GivenName') || '';
  const lastName = read(raw, 'lastName', 'LastName', 'surname', 'Surname') || '';
  const email = read(raw, 'email', 'Email', 'workEmail', 'WorkEmail') || fallbackEmail || '';
  const fullName = read(raw, 'fullName', 'FullName', 'name', 'Name');
  const company = read(raw, 'company', 'Company');

  return {
    id: read(raw, 'id', 'Id', 'employeeId', 'EmployeeId', 'employeeID', 'EmployeeID', 'userId', 'UserId', 'userID', 'UserID') ?? null,
    name: fullName || `${firstName} ${lastName}`.trim() || email.split('@')[0] || 'Workspace member',
    firstName,
    lastName,
    email,
    phoneNumber: read(raw, 'phoneNumber', 'PhoneNumber', 'mobileNumber', 'MobileNumber'),
    role: roles[0] || 'Workspace member',
    roles,
    // Company is optional for sign-in. Workspace access is authorized by the API,
    // and this field is not required by the frontend auth gate.
    companyId: read(raw, 'companyId', 'CompanyId') ?? read(company, 'id', 'Id', 'companyId', 'CompanyId') ?? null,
  };
}

async function getCurrentUser(fallbackEmail) {
  const response = await request(ENDPOINTS.me);
  const user = toUser(response, fallbackEmail);
  if (!user) throw new Error('The current employee endpoint returned an empty profile.');
  return user;
}

const realAuth = {
  async login(email, password) {
    try {
      const response = await request(ENDPOINTS.login, {
        method: 'POST', auth: false,
        body: { request: { email, password } },
      });
      const tokens = unwrapPayload(response);
      const accessToken = read(tokens, 'accessToken', 'AccessToken');
      const refreshToken = read(tokens, 'refreshToken', 'RefreshToken');
      if (!accessToken || !refreshToken) throw new Error('The login endpoint did not return both tokens.');
      tokenStore.setPair({ accessToken, refreshToken });
      try { return await getCurrentUser(email); }
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
