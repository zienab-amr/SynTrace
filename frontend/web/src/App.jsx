import { useEffect } from 'react';
import { AuthProvider, useAuth } from './context/AuthContext.jsx';
import { Link, navigate, useLocation } from './router/router.jsx';
import Intro from './components/Intro/Intro';
import Login from './components/Login/Login';
import Register from './components/Register/Register.jsx';
import StatusPage from './components/common/StatusPage.jsx';
import WorkspacePlaceholder from './components/Workspace/WorkspacePlaceholder.jsx';
import './App.css';

// Sends anonymous visitors to /login and brings them back after signing in.
function RequireAuth({ children }) {
  const { status } = useAuth();
  const { pathname, search } = useLocation();

  useEffect(() => {
    if (status === 'anonymous') navigate(`/login?redirect=${encodeURIComponent(pathname + search)}`, { replace: true });
  }, [status, pathname, search]);

  if (status !== 'authenticated') return <StatusPage title="Checking your session…" message="One moment please." actionLabel="Back to intro" actionTo="/" />;
  return children;
}

function Routes() {
  const { pathname } = useLocation();

  if (pathname === '/') return <Intro onLogin={() => navigate('/login')} />;
  if (pathname === '/login') return <Login />;
  if (pathname === '/register') {
    return <Register />;
  }
  if (pathname === '/forgot-password') {
    return <StatusPage title="Reset your password" message="Password reset is coming to the web app soon." />;
  }
  if (pathname === '/app' || pathname.startsWith('/app/')) {
    return <RequireAuth><WorkspacePlaceholder /></RequireAuth>;
  }
  return <StatusPage title="Page not found" message="That page doesn’t exist." actionLabel="Go to start" actionTo="/" />;
}

export default function App() {
  return (
    <AuthProvider>
      <WorkspacePlaceholder />
    </AuthProvider>
  );
}
