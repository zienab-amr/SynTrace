// Resolve files from Vite's public directory under either '/' or '/web/'.
export function assetUrl(path) {
  return `${import.meta.env.BASE_URL}${String(path).replace(/^\/+/, '')}`;
}
