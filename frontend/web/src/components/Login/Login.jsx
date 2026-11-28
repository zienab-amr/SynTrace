import { assetUrl } from '../../lib/assetUrl.js';
import { useEffect, useId, useRef, useState } from 'react';
import ThemeToggle from '../common/ThemeToggle.jsx';
import LoginStage from './LoginStage.jsx';
import { useLoginForm } from './useLoginForm.js';
import { useAuth } from '../../context/AuthContext.jsx';
import { Link, navigate, useLocation } from '../../router/router.jsx';
import { safeRedirect } from '../../lib/safeRedirect.js';
import { EMAIL_MAX, PASSWORD_MAX } from '../../lib/validation.js';
import {
  AlertIcon, ArrowIcon, BackIcon, CheckIcon, EyeIcon, EyeOffIcon, GithubGlyph,
  GoogleGlyph, JiraGlyph, LockIcon, MailIcon,
} from './LoginIcons.jsx';
import './login.css';

const mmss = (seconds) => `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`;

// Messages are deliberately generic: they must never reveal whether an account exists.
function messageFor(code, remaining) {
  switch (code) {
    case 'INVALID_CREDENTIALS': return 'Incorrect email or password.';
    case 'FORBIDDEN': return "We couldn't sign you in. Contact your workspace admin.";
    case 'RATE_LIMITED': return remaining > 0 ? `Too many attempts. Try again in ${mmss(remaining)}.` : 'Too many attempts. Please wait a moment.';
    case 'NETWORK': return "Can't reach SynTrace. Check your connection and try again.";
    default: return 'Something went wrong on our side. Please try again.';
  }
}

// Single sign-on is shown but disabled until the backend supports it (nothing is faked).
const PROVIDERS = [
  { id: 'github', label: 'GitHub', Icon: GithubGlyph },
  { id: 'jira', label: 'Jira (Atlassian)', Icon: JiraGlyph },
  { id: 'google', label: 'Google', Icon: GoogleGlyph },
];

export default function Login() {
  const uid = useId();
  const { params } = useLocation();
  const redirectTo = safeRedirect(params.get('redirect'));
  const { status } = useAuth();
  const form = useLoginForm({ redirectTo });
  const [showPassword, setShowPassword] = useState(false);
  const cardRef = useRef(null);

  // Already signed in: skip the form (but let the success animation finish first).
  useEffect(() => {
    if (status === 'authenticated' && !form.submitting && !form.success) navigate(redirectTo, { replace: true });
  }, [status, form.submitting, form.success, redirectTo]);

  // Re-trigger the shake animation on every failed attempt.
  useEffect(() => {
    const card = cardRef.current;
    if (!form.shakeKey || !card) return;
    card.classList.remove('is-shaking');
    void card.offsetWidth;
    card.classList.add('is-shaking');
  }, [form.shakeKey]);

  const ids = { email: `${uid}-email`, password: `${uid}-password`, emailErr: `${uid}-email-err`, passErr: `${uid}-pass-err`, caps: `${uid}-caps`, alert: `${uid}-alert` };
  const banner = form.locked ? messageFor('RATE_LIMITED', form.remaining) : form.formError ? messageFor(form.formError.code, form.remaining) : '';
  const disabled = form.submitting || form.success || form.locked;

  return (
    <main className="login" aria-labelledby={`${uid}-title`}>
      <div className="login__bg" aria-hidden="true" />

      <div className="login__tools">
        <Link to="/" className="login__back"><BackIcon /> Back to intro</Link>
        <ThemeToggle />
      </div>

      <section className="login__stage" aria-hidden="true"><LoginStage /></section>

      <section className="login__panel">
        <header className="login__brand">
          <img src={assetUrl('assets/syntrace-mark.webp')} alt="" height="56" />
          <span className="login__wordmark">SynTrace</span>
          <p>Connect. Understand. Trace.</p>
        </header>

        <div className={`login__card${form.success ? ' is-success' : ''}`} ref={cardRef}>
          <h1 id={`${uid}-title`}>Welcome back</h1>
          <p className="login__sub">Sign in to your account</p>

          <form noValidate onSubmit={form.submit} aria-busy={form.submitting}>
            <div className="field" style={{ '--i': 0 }}>
              <label htmlFor={ids.email}>Work email</label>
              <div className="field__control">
                <span className="field__icon"><MailIcon /></span>
                <input
                  id={ids.email} ref={form.emailRef} type="email" inputMode="email" name="email"
                  placeholder="you@company.com" autoComplete="username" autoCapitalize="none" spellCheck={false}
                  maxLength={EMAIL_MAX} value={form.values.email} readOnly={disabled}
                  onChange={(e) => form.setField('email', e.target.value)} onBlur={() => form.values.email && form.validateField('email')}
                  aria-invalid={Boolean(form.errors.email)} aria-describedby={form.errors.email ? ids.emailErr : undefined}
                />
              </div>
              <p className="field__error" id={ids.emailErr} role={form.errors.email ? 'alert' : undefined}>{form.errors.email}</p>
            </div>

            <div className="field" style={{ '--i': 1 }}>
              <label htmlFor={ids.password}>Password</label>
              <div className="field__control">
                <span className="field__icon"><LockIcon /></span>
                <input
                  id={ids.password} ref={form.passwordRef} type={showPassword ? 'text' : 'password'} name="password"
                  placeholder="Your password" autoComplete="current-password" autoCapitalize="none" spellCheck={false}
                  maxLength={PASSWORD_MAX} value={form.values.password} readOnly={disabled}
                  onChange={(e) => form.setField('password', e.target.value)}
                  onKeyDown={form.trackCapsLock} onKeyUp={form.trackCapsLock} onBlur={() => form.trackCapsLock({})}
                  aria-invalid={Boolean(form.errors.password)}
                  aria-describedby={[form.errors.password ? ids.passErr : '', form.capsLock ? ids.caps : ''].filter(Boolean).join(' ') || undefined}
                />
                <button
                  type="button" className="field__toggle" onClick={() => setShowPassword((v) => !v)}
                  onMouseDown={(e) => e.preventDefault()} aria-pressed={showPassword}
                  aria-label={showPassword ? 'Hide password' : 'Show password'}
                >
                  {showPassword ? <EyeOffIcon /> : <EyeIcon />}
                </button>
              </div>
              <p className="field__error" id={ids.passErr} role={form.errors.password ? 'alert' : undefined}>{form.errors.password}</p>
              {form.capsLock && <p className="field__hint" id={ids.caps}><AlertIcon /> Caps Lock is on</p>}
            </div>

            <div className="login__row" style={{ '--i': 2 }}>
              <Link to="/forgot-password" className="login__link">Forgot password?</Link>
            </div>

            <div className="login__alert" id={ids.alert} role="alert" hidden={!banner}>
              <AlertIcon /><span>{banner}</span>
            </div>

            <button type="submit" className="login__submit" disabled={disabled && !form.success && !form.submitting} data-state={form.success ? 'success' : form.submitting ? 'loading' : form.locked ? 'locked' : 'idle'} style={{ '--i': 3 }}>
              <span className="login__submit-label">
                {form.success ? (<><CheckIcon /> Signed in</>) : form.submitting ? (<><span className="spinner" aria-hidden="true" /> Signing in…</>) : form.locked ? `Try again in ${mmss(form.remaining)}` : (<>Sign in <ArrowIcon /></>)}
              </span>
            </button>
          </form>

          <div className="login__divider" style={{ '--i': 4 }}><span>or continue with</span></div>
          <div className="login__social" style={{ '--i': 5 }}>
            {PROVIDERS.map(({ id, label, Icon }) => (
              <button key={id} type="button" className="login__sso" disabled aria-label={`${label} sign-in (coming soon)`} title="Coming soon"><Icon /></button>
            ))}
          </div>
          <p className="login__soon">Single sign-on is coming soon.</p>

          <p className="login__signup">Don&apos;t have an account? <Link to="/register" className="login__link">Sign up</Link></p>
        </div>

        <p className="login__legal">
          <LockIcon /> Sessions are encrypted. Your password is never stored in this browser.
        </p>
      </section>
    </main>
  );
}
