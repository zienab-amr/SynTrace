// The access token lives ONLY in memory: never localStorage / sessionStorage / cookies readable by JS.
// An XSS bug therefore cannot read it from storage, and it disappears when the tab closes.
// The long-lived refresh token must be an HttpOnly + Secure + SameSite cookie set by the backend.
let accessToken = null;

export const tokenStore = {
  get: () => accessToken,
  set: (token) => {
    accessToken = typeof token === 'string' && token ? token : null;
  },
  clear: () => {
    accessToken = null;
  },
};
