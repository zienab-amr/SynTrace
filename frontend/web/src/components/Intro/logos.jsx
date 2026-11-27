import React from 'react';

export function BrandMark({ className = '' }) {
  return (
    <svg className={`brand-mark ${className}`} viewBox="0 0 48 52" fill="none" aria-hidden="true">
      <path d="M38 8 24 2 10 9v12l14 6 14 7v9l-14 7-14-7" stroke="url(#syntrace-gradient)" strokeWidth="6" strokeLinejoin="round" strokeLinecap="round" />
      <defs>
        <linearGradient id="syntrace-gradient" x1="6" y1="6" x2="42" y2="48">
          <stop stopColor="#34B9FF" />
          <stop offset=".52" stopColor="#2172FF" />
          <stop offset="1" stopColor="#20E0A0" />
        </linearGradient>
      </defs>
    </svg>
  );
}

export function JiraMark() {
  return <svg viewBox="0 0 32 32" aria-hidden="true"><rect width="32" height="32" rx="9" fill="#1877F2" /><path d="M9 9h14v4H13v3h8v4h-8v3H9z" fill="white" /></svg>;
}

export function GitHubMark() {
  return <svg viewBox="0 0 32 32" aria-hidden="true"><circle cx="16" cy="16" r="15" fill="#f5f7ff" /><path d="M16 6.5a9.5 9.5 0 0 0-3 18.5c.5.1.7-.2.7-.5v-1.8c-2.8.6-3.4-1.2-3.4-1.2-.5-1.1-1.1-1.4-1.1-1.4-.9-.6.1-.6.1-.6 1 .1 1.5 1 1.5 1 .9 1.5 2.3 1.1 2.9.9.1-.7.4-1.1.6-1.3-2.2-.2-4.5-1.1-4.5-4.8 0-1.1.4-2 1-2.7-.1-.2-.4-1.3.1-2.7 0 0 .8-.3 2.8 1a9.8 9.8 0 0 1 5.1 0c2-1.3 2.8-1 2.8-1 .5 1.4.2 2.5.1 2.7.7.7 1 1.6 1 2.7 0 3.7-2.3 4.6-4.5 4.8.4.3.7.9.7 1.8v2.6c0 .3.2.6.7.5A9.5 9.5 0 0 0 16 6.5z" fill="#111a2d" /></svg>;
}

export function NotesMark() {
  return <svg viewBox="0 0 32 32" fill="none" aria-hidden="true"><rect x="5" y="3" width="22" height="26" rx="5" stroke="currentColor" strokeWidth="2.4" /><path d="M10 11h12M10 16h12M10 21h8" stroke="currentColor" strokeWidth="2.3" strokeLinecap="round" /></svg>;
}

export function TeamMark() {
  return <svg viewBox="0 0 32 32" fill="none" aria-hidden="true"><circle cx="12" cy="10" r="4" stroke="currentColor" strokeWidth="2.2" /><circle cx="23" cy="12" r="3" stroke="currentColor" strokeWidth="2.2" /><path d="M4 26v-2a8 8 0 0 1 16 0v2H4Zm16-8a6 6 0 0 1 8 5.7V26h-5" stroke="currentColor" strokeWidth="2.2" strokeLinejoin="round" /></svg>;
}

export function GraphMark() {
  return <svg viewBox="0 0 32 32" fill="none" aria-hidden="true"><path d="m8 9 16 1-8 14L8 9Z" stroke="currentColor" strokeWidth="2" /><circle cx="8" cy="9" r="3" fill="currentColor" /><circle cx="24" cy="10" r="3" fill="currentColor" /><circle cx="16" cy="24" r="3" fill="currentColor" /></svg>;
}
