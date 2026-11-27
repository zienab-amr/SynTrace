import ThemeToggle from './ThemeToggle.jsx';
import { Link } from '../../router/router.jsx';
import './status-page.css';

// Simple themed page for routes that are not built yet (and 404).
export default function StatusPage({ title, message, actionLabel = 'Back to sign in', actionTo = '/login' }) {
  return (
    <main className="status">
      <div className="status__tools"><ThemeToggle /></div>
      <div className="status__card">
        <img src="/assets/syntrace-mark.webp" alt="" height="48" />
        <h1>{title}</h1>
        <p>{message}</p>
        <Link to={actionTo} className="status__action">{actionLabel}</Link>
      </div>
    </main>
  );
}
