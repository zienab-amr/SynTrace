// Small inline icons for the login page (no icon library needed).
const base = { viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', strokeWidth: 1.7, strokeLinecap: 'round', strokeLinejoin: 'round', 'aria-hidden': true };

export const MailIcon = () => (<svg {...base}><rect x="3" y="5" width="18" height="14" rx="3" /><path d="m4 8 8 6 8-6" /></svg>);
export const LockIcon = () => (<svg {...base}><rect x="5" y="11" width="14" height="9" rx="3" /><path d="M8 11V8a4 4 0 0 1 8 0v3" /></svg>);
export const EyeIcon = () => (<svg {...base}><path d="M2.5 12s3.6-6.5 9.5-6.5S21.5 12 21.5 12 17.9 18.5 12 18.5 2.5 12 2.5 12z" /><circle cx="12" cy="12" r="2.8" /></svg>);
export const EyeOffIcon = () => (<svg {...base}><path d="M3 3l18 18" /><path d="M10.6 6a9.6 9.6 0 0 1 1.4-.1c5.9 0 9.5 6.1 9.5 6.1a16 16 0 0 1-3 3.6M6.7 7.4A16 16 0 0 0 2.5 12S6.1 18.1 12 18.1c1.2 0 2.3-.2 3.3-.6" /><path d="M9.9 9.9a3 3 0 0 0 4.2 4.2" /></svg>);
export const AlertIcon = () => (<svg {...base}><path d="M12 4 2.8 19.5h18.4L12 4z" /><path d="M12 10v4.2M12 17.2v.1" /></svg>);
export const ArrowIcon = () => (<svg {...base} strokeWidth={2}><path d="M5 12h14M13 6l6 6-6 6" /></svg>);
export const CheckIcon = () => (<svg {...base} strokeWidth={2.2}><path d="m5 12.5 4.5 4.5L19 7.5" /></svg>);
export const BackIcon = () => (<svg {...base}><path d="M19 12H5M11 6l-6 6 6 6" /></svg>);

export const GithubGlyph = () => (
  <svg viewBox="0 0 16 16" fill="currentColor" aria-hidden="true">
    <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0 0 16 8c0-4.42-3.58-8-8-8z" />
  </svg>
);
export const JiraGlyph = () => (
  <svg viewBox="0 0 32 32" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinejoin="round" aria-hidden="true">
    <path d="M16 2.8 29.2 16 16 29.2 2.8 16z" /><path d="M16 9.4 22.6 16 16 22.6 9.4 16z" fill="currentColor" stroke="none" />
  </svg>
);
export const GoogleGlyph = () => (
  <svg viewBox="0 0 24 24" aria-hidden="true">
    <path fill="#4285F4" d="M23.52 12.27c0-.85-.08-1.66-.22-2.45H12v4.64h6.46a5.52 5.52 0 0 1-2.4 3.62v3h3.88c2.27-2.09 3.58-5.17 3.58-8.81z" />
    <path fill="#34A853" d="M12 24c3.24 0 5.96-1.07 7.94-2.91l-3.88-3a7.2 7.2 0 0 1-10.7-3.78H1.34v3.09A12 12 0 0 0 12 24z" />
    <path fill="#FBBC05" d="M5.36 14.31a7.2 7.2 0 0 1 0-4.62V6.6H1.34a12 12 0 0 0 0 10.8l4.02-3.09z" />
    <path fill="#EA4335" d="M12 4.75c1.76 0 3.34.61 4.58 1.8l3.43-3.43A11.96 11.96 0 0 0 12 0 12 12 0 0 0 1.34 6.6l4.02 3.09A7.2 7.2 0 0 1 12 4.75z" />
  </svg>
);
