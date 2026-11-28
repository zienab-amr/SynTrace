import { useEffect } from 'react';
import { navigate, useLocation } from '../../router/router.jsx';
import StatusPage from '../common/StatusPage.jsx';

// Atlassian redirects to the backend callback first. The backend then sends the
// browser to JiraOAuth:FrontendRedirectUri with status/pendingId query values.
// Preserve those values while returning to the authenticated workspace route.
export default function JiraCallbackRedirect() {
  const { search } = useLocation();

  useEffect(() => {
    const source = new URLSearchParams(search);
    const status = source.get('status');
    const pendingId = source.get('pendingId');
    const params = new URLSearchParams();

    if (status === 'success' || status === 'select-site') params.set('status', status);
    if (status === 'select-site' && pendingId) params.set('pendingId', pendingId);

    navigate(params.size ? `/app?${params.toString()}` : '/app', { replace: true });
  }, [search]);

  return <StatusPage title="Returning from Jira…" message="Completing the company Jira connection." />;
}
