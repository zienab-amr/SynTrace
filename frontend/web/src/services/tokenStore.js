// The API currently returns refreshToken in JSON and does not issue an HttpOnly cookie.
// Until the backend changes to a Secure + HttpOnly + SameSite cookie, keep the rotating
// refresh token in sessionStorage (tab-scoped) and keep the short-lived access token in memory.
// Do not move the refresh token to localStorage.
const REFRESH_KEY = 'syntrace.refresh-token';
let accessToken = null;

function readRefreshToken() {
  try { return sessionStorage.getItem(REFRESH_KEY); } catch { return null; }
}

function writeRefreshToken(token) {
  try {
    if (typeof token === 'string' && token) sessionStorage.setItem(REFRESH_KEY, token);
    else sessionStorage.removeItem(REFRESH_KEY);
  } catch { /* Private browsing/storage restrictions: the current tab can still use the access token. */ }
}

export const tokenStore = {
  get: () => accessToken,
  set: (token) => { accessToken = typeof token === 'string' && token ? token : null; },
  getRefresh: readRefreshToken,
  setRefresh: writeRefreshToken,
  setPair: (tokens) => {
    accessToken = typeof tokens?.accessToken === 'string' && tokens.accessToken ? tokens.accessToken : null;
    writeRefreshToken(tokens?.refreshToken);
  },
  clear: () => {
    accessToken = null;
    writeRefreshToken(null);
  },
};
