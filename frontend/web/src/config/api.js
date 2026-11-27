// Backend connection. Values come from .env files (see .env.example), never hard-coded.
// IMPORTANT: confirm paths and response shapes with the backend team (Zeinab) and edit ENDPOINTS only here.

export const API_BASE_URL = (import.meta.env.VITE_API_URL ?? '').replace(/\/+$/, '');

// Mock auth lets you build the UI without the backend. It is OFF in production builds.
export const USE_MOCK_AUTH =
  !import.meta.env.PROD &&
  (import.meta.env.VITE_USE_MOCK_AUTH === 'true' || !import.meta.env.VITE_API_URL);

export const ENDPOINTS = {
  login: '/api/auth/login', //   POST {email,password} -> {accessToken, expiresIn, user}  + refresh cookie
  refresh: '/api/auth/refresh', // POST (refresh cookie) -> {accessToken, expiresIn, user}
  logout: '/api/auth/logout', //  POST
  sendOtp: '/api/Auth/send-otp',
  verifyOtp: '/api/Auth/verify-otp',
  register: '/api/Auth/register',
};
