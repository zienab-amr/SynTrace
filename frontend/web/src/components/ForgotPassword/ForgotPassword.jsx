import { assetUrl } from '../../lib/assetUrl.js';
import { useEffect, useState } from 'react';
import ThemeToggle from '../common/ThemeToggle.jsx';
import LoginStage from '../Login/LoginStage.jsx';
import { Link } from '../../router/router.jsx';
import { sendPasswordResetOtp, resetPassword } from '../../services/registrationService.js';
import { EMAIL_MAX, PASSWORD_MAX, normalizeEmail, validateEmail } from '../../lib/validation.js';
import { AlertIcon, ArrowIcon, BackIcon, CheckIcon, LockIcon, MailIcon } from '../Login/LoginIcons.jsx';
import '../Login/login.css';
import './forgot-password.css';

const COOLDOWN_SECONDS = 60;

function messageOf(error, fallback) {
  return error?.data?.detail || error?.data?.message || error?.data?.title || error?.message || fallback;
}

export default function ForgotPassword() {
  const [email, setEmail] = useState('');
  const [otp, setOtp] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [step, setStep] = useState('email');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [resendIn, setResendIn] = useState(0);

  useEffect(() => {
    if (resendIn <= 0) return undefined;
    const timer = window.setTimeout(() => setResendIn((value) => Math.max(0, value - 1)), 1000);
    return () => window.clearTimeout(timer);
  }, [resendIn]);

  const requestCode = async (event) => {
    event.preventDefault();
    const validation = validateEmail(email);
    if (validation) { setError(validation); return; }
    setBusy(true); setError(''); setNotice('');
    try {
      await sendPasswordResetOtp(normalizeEmail(email));
      setStep('reset');
      setResendIn(COOLDOWN_SECONDS);
      setNotice('If this email is registered, a password reset code has been sent.');
    } catch (cause) {
      setError(messageOf(cause, 'We could not send a reset code. Please try again.'));
    } finally { setBusy(false); }
  };

  const resendCode = async () => {
    if (busy || resendIn > 0) return;
    setBusy(true); setError('');
    try {
      await sendPasswordResetOtp(normalizeEmail(email));
      setResendIn(COOLDOWN_SECONDS);
      setNotice('If this email is registered, a new reset code has been sent.');
    } catch (cause) {
      setError(messageOf(cause, 'We could not resend the code. Please try again.'));
    } finally { setBusy(false); }
  };

  const submitReset = async (event) => {
    event.preventDefault();
    setError(''); setNotice('');
    if (!/^\d{6}$/.test(otp)) { setError('Enter the six-digit code from your email.'); return; }
    if (!password || password.length > PASSWORD_MAX) { setError('Enter a valid new password (up to 128 characters).'); return; }
    if (password !== confirmPassword) { setError('The password confirmation does not match.'); return; }
    setBusy(true);
    try {
      await resetPassword({ email: normalizeEmail(email), otp, newPassword: password, confirmPassword });
      setStep('success');
    } catch (cause) {
      setError(messageOf(cause, 'The code may be invalid or expired. Request a new code and try again.'));
    } finally { setBusy(false); }
  };

  return (
    <main className="login" aria-labelledby="forgot-title">
      <div className="login__bg" aria-hidden="true" />
      <div className="login__tools">
        <Link to="/login" className="login__back"><BackIcon /> Back to sign in</Link>
        <ThemeToggle />
      </div>
      <section className="login__stage" aria-hidden="true"><LoginStage /></section>
      <section className="login__panel">
        <header className="login__brand">
          <img src={assetUrl('assets/syntrace-mark.webp')} alt="" height="56" />
          <span className="login__wordmark">SynTrace</span>
          <p>Connect. Understand. Trace.</p>
        </header>

        <div className="login__card forgot-card" aria-busy={busy}>
          {step === 'success' ? (
            <div className="forgot-success">
              <span className="forgot-success__icon"><CheckIcon /></span>
              <h1 id="forgot-title">Password updated</h1>
              <p className="login__sub">Your password has been changed. Sign in with your new password.</p>
              <Link to="/login" className="login__submit forgot-submit"><span className="login__submit-label">Continue to sign in <ArrowIcon /></span></Link>
            </div>
          ) : (
            <>
              <span className="forgot-eyebrow">ACCOUNT RECOVERY</span>
              <h1 id="forgot-title">{step === 'email' ? 'Reset your password' : 'Create a new password'}</h1>
              <p className="login__sub">{step === 'email' ? 'Enter your work email and we’ll send a reset code.' : `Enter the six-digit code sent to ${email}.`}</p>

              {step === 'email' ? (
                <form onSubmit={requestCode} noValidate>
                  <div className="field">
                    <label htmlFor="reset-email">Work email</label>
                    <div className="field__control"><span className="field__icon"><MailIcon /></span><input id="reset-email" type="email" inputMode="email" autoComplete="email" autoCapitalize="none" spellCheck={false} maxLength={EMAIL_MAX} value={email} onChange={(event) => setEmail(event.target.value)} placeholder="you@company.com" disabled={busy}/></div>
                  </div>
                  {error && <div className="login__alert" role="alert"><AlertIcon/><span>{error}</span></div>}
                  <button type="submit" className="login__submit forgot-submit" disabled={busy}><span className="login__submit-label">{busy ? <><span className="spinner"/> Sending code…</> : <>Send reset code <ArrowIcon/></>}</span></button>
                </form>
              ) : (
                <form onSubmit={submitReset} noValidate>
                  <div className="field">
                    <label htmlFor="reset-otp">Email verification code</label>
                    <div className="field__control"><span className="field__icon"><MailIcon /></span><input id="reset-otp" type="text" inputMode="numeric" autoComplete="one-time-code" pattern="[0-9]{6}" maxLength={6} value={otp} onChange={(event) => setOtp(event.target.value.replace(/\D/g, '').slice(0, 6))} placeholder="6-digit code" disabled={busy}/></div>
                  </div>
                  <div className="field">
                    <label htmlFor="reset-password">New password</label>
                    <div className="field__control"><span className="field__icon"><LockIcon /></span><input id="reset-password" type="password" autoComplete="new-password" maxLength={PASSWORD_MAX} value={password} onChange={(event) => setPassword(event.target.value)} placeholder="Enter a new password" disabled={busy}/></div>
                  </div>
                  <div className="field">
                    <label htmlFor="reset-confirm">Confirm new password</label>
                    <div className="field__control"><span className="field__icon"><LockIcon /></span><input id="reset-confirm" type="password" autoComplete="new-password" maxLength={PASSWORD_MAX} value={confirmPassword} onChange={(event) => setConfirmPassword(event.target.value)} placeholder="Enter it again" disabled={busy}/></div>
                  </div>
                  {notice && <p className="forgot-notice" role="status">{notice}</p>}
                  {error && <div className="login__alert" role="alert"><AlertIcon/><span>{error}</span></div>}
                  <button type="submit" className="login__submit forgot-submit" disabled={busy}><span className="login__submit-label">{busy ? <><span className="spinner"/> Updating password…</> : <>Update password <ArrowIcon/></>}</span></button>
                  <div className="forgot-actions"><button type="button" className="login__link" onClick={resendCode} disabled={busy || resendIn > 0}>{resendIn > 0 ? `Resend code in ${resendIn}s` : 'Resend code'}</button><button type="button" className="login__link" onClick={() => { setStep('email'); setOtp(''); setPassword(''); setConfirmPassword(''); setError(''); setNotice(''); }} disabled={busy}>Change email</button></div>
                </form>
              )}
              {step === 'email' && notice && <p className="forgot-notice" role="status">{notice}</p>}
              <p className="login__signup"><Link to="/login" className="login__link">Return to sign in</Link></p>
            </>
          )}
        </div>
        <p className="login__legal"><LockIcon /> Your password is sent directly to the SynTrace API over your configured connection.</p>
      </section>
    </main>
  );
}
