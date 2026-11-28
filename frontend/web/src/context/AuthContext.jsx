import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { authService } from '../services/authService.js';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [state, setState] = useState({ status: 'loading', user: null }); // loading | authenticated | anonymous

  useEffect(() => {
    let alive = true;
    authService
      .restoreSession()
      .then((user) => alive && setState({ status: user ? 'authenticated' : 'anonymous', user }))
      .catch(() => alive && setState({ status: 'anonymous', user: null }));

    const onExpired = () => setState({ status: 'anonymous', user: null });
    window.addEventListener('auth:expired', onExpired);
    return () => {
      alive = false;
      window.removeEventListener('auth:expired', onExpired);
    };
  }, []);

  const login = useCallback(async (email, password) => {
    const user = await authService.login(email, password);
    setState({ status: 'authenticated', user });
    return user;
  }, []);

  const logout = useCallback(async () => {
    try { await authService.logout(); }
    finally { setState({ status: 'anonymous', user: null }); }
  }, []);

  const value = useMemo(() => ({ ...state, login, logout }), [state, login, logout]);
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) throw new Error('useAuth must be used inside <AuthProvider>');
  return context;
}
