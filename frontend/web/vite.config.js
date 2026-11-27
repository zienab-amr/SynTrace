import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Basic hardening headers for dev/preview. Production headers (CSP, HSTS, frame-ancestors)
// belong on the real web server / CDN: see README "Security".
const securityHeaders = {
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'strict-origin-when-cross-origin',
  'Permissions-Policy': 'camera=(), microphone=(), geolocation=()',
};

export default defineConfig({
  plugins: [react()],
  server: { headers: securityHeaders },
  preview: { headers: securityHeaders },
});
