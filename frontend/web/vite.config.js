import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';

// VITE_BASE_PATH is '/' locally and '/web/' when React is hosted below the edge gateway.
function normalizeBasePath(value) {
  const path = String(value || '/').trim();
  if (!path.startsWith('/') || path.startsWith('//') || path.includes('..')) {
    throw new Error('VITE_BASE_PATH must be a site-relative path such as "/" or "/web/".');
  }
  return path === '/' ? '/' : `/${path.split('/').filter(Boolean).join('/')}/`;
}

// Basic hardening headers for dev/preview. Production headers (CSP, HSTS, frame-ancestors)
// belong on the real web server / CDN: see README "Security".
const securityHeaders = {
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'strict-origin-when-cross-origin',
  'Permissions-Policy': 'camera=(), microphone=(), geolocation=()',
};

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '');
  const base = normalizeBasePath(env.VITE_BASE_PATH || '/');

  const apiProxyTarget = (env.VITE_API_PROXY_TARGET || 'http://localhost:8081').trim();
  const proxy = !env.VITE_API_URL?.trim() && apiProxyTarget
    ? { '/api': { target: apiProxyTarget, changeOrigin: true, secure: true } }
    : undefined;

  return {
    base,
    plugins: [react()],
    server: { headers: securityHeaders, ...(proxy ? { proxy } : {}) },
    preview: { headers: securityHeaders, ...(proxy ? { proxy } : {}) },
  };
});
