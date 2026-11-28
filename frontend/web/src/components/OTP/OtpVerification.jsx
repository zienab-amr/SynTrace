import { assetUrl } from '../../lib/assetUrl.js';
import { useEffect, useRef, useState } from 'react';
import ThemeToggle from '../common/ThemeToggle.jsx';
import { Link } from '../../router/router.jsx';
import { getVerificationToken, registerAccount, sendRegistrationOtp, verifyRegistrationOtp } from '../../services/registrationService.js';
import { ArrowIcon, BackIcon, CheckIcon, LockIcon, MailIcon } from '../Login/LoginIcons.jsx';
import '../Login/login.css';
import './otp.css';

const OTP_LENGTH = 6;
const RESEND_SECONDS = 60;
const errorMessage = (error, fallback) => error?.data?.message || error?.data?.title || fallback;
const formatTime = (seconds) => `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`;

function RefreshIcon() {
  return <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="M20 7v5h-5M4 17v-5h5" /><path d="M5.6 9A7 7 0 0 1 18 6.5L20 12M4 12l2 5.5A7 7 0 0 0 18.4 15" /></svg>;
}

function VaultStage({ filled, state }) {
  return (
    <div className={`register-vault register-vault--${state}`} aria-hidden="true">
      <div className="otp-art-frame"><i /><i /><i /><i /></div>
      <div className="otp-art-glow" />
      <div className="otp-art-orbit otp-art-orbit--outer" />
      <div className="otp-art-orbit otp-art-orbit--middle" />
      <div className="otp-art-orbit otp-art-orbit--inner" />
      <div className="otp-art-particle otp-art-particle--one" />
      <div className="otp-art-particle otp-art-particle--two" />
      <div className="otp-art-particle otp-art-particle--three" />
      <div className="otp-art-particle otp-art-particle--four" />
      <div className="otp-art-badge otp-art-badge--mail"><MailIcon /><b>✓</b></div>
      <div className="otp-art-badge otp-art-badge--finger">≋</div>
      <svg className="otp-art-shield" viewBox="0 0 320 360" fill="none">
        <defs>
          <linearGradient id="otp-shield-fill" x1="42" y1="30" x2="272" y2="330" gradientUnits="userSpaceOnUse">
            <stop offset="0" style={{ stopColor: 'var(--st-accent)', stopOpacity: 0.34 }} />
            <stop offset="1" style={{ stopColor: 'var(--st-accent-2)', stopOpacity: 0.12 }} />
          </linearGradient>
          <linearGradient id="otp-shield-edge" x1="45" y1="38" x2="276" y2="325" gradientUnits="userSpaceOnUse">
            <stop offset="0" style={{ stopColor: 'var(--st-accent)' }} />
            <stop offset="1" style={{ stopColor: 'var(--st-accent-2)' }} />
          </linearGradient>
        </defs>
        <path className="otp-art-shield__outer" d="M160 20 282 68v88c0 85-51 143-122 184C89 299 38 241 38 156V68l122-48Z" fill="url(#otp-shield-fill)" stroke="url(#otp-shield-edge)" strokeWidth="4" />
        <path className="otp-art-shield__inner" d="M160 47 255 84v71c0 67-38 114-95 150-57-36-95-83-95-150V84l95-37Z" stroke="var(--st-accent)" strokeOpacity=".48" strokeWidth="2" />
        <path className="otp-art-lock-shackle" d="M117 166v-27a43 43 0 0 1 86 0v27" stroke="var(--st-accent)" strokeWidth="12" strokeLinecap="round" />
        <rect className="otp-art-lock-body" x="94" y="158" width="132" height="111" rx="22" fill="url(#otp-shield-fill)" stroke="url(#otp-shield-edge)" strokeWidth="4" />
        <path className="otp-art-lock-keyhole" d="M160 197a18 18 0 0 0-10 33v16h20v-16a18 18 0 0 0-10-33Z" fill="var(--st-accent)" />
        <circle cx="160" cy="215" r="8" fill="var(--st-ice)" />
        <path className="otp-art-unlock-check" d="m134 214 17 17 36-40" fill="none" stroke="var(--st-accent-2)" strokeWidth="10" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
      <div className="otp-art-platform"><span /><span /><span /></div>
      <div className="otp-art-caption">
        <span>{state === 'success' ? 'IDENTITY VERIFIED' : state === 'error' ? 'CHECK THE CODE' : state === 'verifying' ? 'VERIFYING IDENTITY' : 'SECURE EMAIL VERIFICATION'}</span>
        <b>{filled}<i>/</i>6</b>
        <small>CODE DIGITS ENTERED</small>
      </div>
    </div>
  );
}

export default function OtpVerification({ form, onChangeEmail }) {
  const [otp, setOtp] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [resendIn, setResendIn] = useState(RESEND_SECONDS);
  const [expiresIn, setExpiresIn] = useState(300);
  const [state, setState] = useState('closed');
  const refs = useRef([]);
  const digits = otp.split('');

  useEffect(() => {
    if (!resendIn) return undefined;
    const timer = setInterval(() => setResendIn((value) => Math.max(0, value - 1)), 1000);
    return () => clearInterval(timer);
  }, [resendIn]);

  useEffect(() => {
    if (!expiresIn) return undefined;
    const timer = setInterval(() => setExpiresIn((value) => Math.max(0, value - 1)), 1000);
    return () => clearInterval(timer);
  }, [expiresIn]);

  const changeDigit = (index, value) => {
    const next = digits.slice(0, OTP_LENGTH);
    next[index] = value.replace(/\D/g, '').slice(-1);
    setOtp(next.join(''));
    setError('');
    if (next[index] && index < OTP_LENGTH - 1) refs.current[index + 1]?.focus();
  };

  const keyDown = (index, event) => {
    if (event.key === 'Backspace' && !digits[index] && index > 0) refs.current[index - 1]?.focus();
    if (event.key === 'ArrowLeft' && index > 0) refs.current[index - 1]?.focus();
    if (event.key === 'ArrowRight' && index < OTP_LENGTH - 1) refs.current[index + 1]?.focus();
  };

  const paste = (event) => {
    event.preventDefault();
    const code = event.clipboardData.getData('text').replace(/\D/g, '').slice(0, OTP_LENGTH);
    setOtp(code);
    setError('');
    refs.current[Math.max(0, Math.min(code.length, OTP_LENGTH) - 1)]?.focus();
  };

  const resend = async () => {
    if (resendIn || loading) return;
    setLoading(true);
    setError('');
    try {
      await sendRegistrationOtp(form.email.trim());
      setResendIn(RESEND_SECONDS);
      setExpiresIn(300);
      setOtp('');
    } catch (requestError) {
      setError(errorMessage(requestError, 'We could not resend the code. Please try again.'));
    } finally {
      setLoading(false);
    }
  };

  const verify = async (event) => {
    event.preventDefault();
    if (otp.length !== OTP_LENGTH) return setError('Enter all 6 digits.');
    setLoading(true);
    setState('verifying');
    setError('');
    try {
      const result = await verifyRegistrationOtp(form.email.trim(), otp);
      const verificationToken = getVerificationToken(result);
      if (!verificationToken) throw new Error('No verification token was returned.');
      await registerAccount({
        companyName: form.companyName.trim(),
        firstName: form.firstName.trim(),
        lastName: form.lastName.trim(),
        email: form.email.trim(),
        phoneNumber: form.phoneNumber.trim(),
        password: form.password,
        otp,
        verificationToken,
      });
      setState('success');
    } catch (requestError) {
      setState('error');
      setError(errorMessage(requestError, 'That code is not valid. Please check it and try again.'));
      setTimeout(() => setState('closed'), 650);
    } finally {
      setLoading(false);
    }
  };

  const changeEmail = () => {
    setOtp('');
    setError('');
    setState('closed');
    onChangeEmail();
  };

  return (
    <main className="login register-page register-otp-page" aria-labelledby="register-title">
      <div className="login__bg" aria-hidden="true" />
      <div className="login__tools">
        <Link to="/login" className="login__back"><BackIcon /> Back to sign in</Link>
        <ThemeToggle />
      </div>
      <section className="login__stage register__stage" aria-hidden="true"><VaultStage filled={otp.length} state={state} /></section>
      <section className="login__panel register__panel">
        <header className="login__brand">
          <img src={assetUrl('assets/syntrace-mark.webp')} alt="" height="56" />
          <span className="login__wordmark">SynTrace</span>
          <p>Connect. Understand. Trace.</p>
        </header>
        <div className={`login__card register__card otp-card${state === 'error' ? ' is-shaking' : ''}${state === 'success' ? ' is-success' : ''}`}>
          {state === 'success' ? (
            <div className="register-success">
              <CheckIcon />
              <h1 id="register-title">Email verified successfully</h1>
              <p className="login__sub">Your account is ready. You can now sign in to SynTrace.</p>
              <Link to="/login" className="login__submit success-link"><span className="login__submit-label">Go to sign in <ArrowIcon /></span></Link>
            </div>
          ) : (
            <>
              <p className="register__eyebrow">STEP 2 OF 2 <span>·</span> VERIFY EMAIL</p>
              <h1 id="register-title">Verify your email</h1>
              <p className="login__sub">We&apos;ve sent a verification code to your email address.</p>

              <div className="otp-email-bar">
                <MailIcon />
                <span title={form.email}>{form.email}</span>
                <button type="button" onClick={changeEmail}><RefreshIcon /> Change email</button>
              </div>

              <form onSubmit={verify} noValidate aria-busy={loading}>
                <div className="otp-fields" onPaste={paste} role="group" aria-label="Six-digit verification code">
                  {Array.from({ length: OTP_LENGTH }, (_, index) => (
                    <input
                      className={`otp-digit${digits[index] ? ' is-filled' : ''}${index === otp.length ? ' is-current' : ''}`}
                      key={index}
                      ref={(element) => { refs.current[index] = element; }}
                      value={digits[index] || ''}
                      inputMode="numeric"
                      autoComplete={index === 0 ? 'one-time-code' : 'off'}
                      maxLength={1}
                      aria-label={`Verification digit ${index + 1}`}
                      aria-invalid={Boolean(error)}
                      onChange={(event) => changeDigit(index, event.target.value)}
                      onKeyDown={(event) => keyDown(index, event)}
                    />
                  ))}
                </div>
                <div className="otp-expiry"><span className="otp-clock" aria-hidden="true">◷</span><span>Code expires in</span><b>{formatTime(expiresIn)}</b></div>
                {error && <p className="login__alert register-alert" role="alert">{error}</p>}
                <button className="login__submit" type="submit" disabled={loading || otp.length !== OTP_LENGTH} data-state={loading ? 'loading' : 'idle'}>
                  <span className="login__submit-label">{loading ? <><span className="spinner" aria-hidden="true" /> Verifying…</> : <>Verify &amp; Create Account <ArrowIcon /></>}</span>
                </button>
              </form>

              <div className="otp-divider"><span>or</span></div>
              <div className="otp-actions">
                <button className="otp-resend" type="button" disabled={resendIn > 0 || loading} onClick={resend}>
                  <RefreshIcon />
                  {resendIn > 0 ? <>Resend code in <b>{formatTime(resendIn)}</b></> : 'Resend code'}
                </button>
                <button className="otp-change-email" type="button" onClick={changeEmail}><BackIcon /> Change email</button>
              </div>
            </>
          )}
        </div>
        <p className="login__legal"><LockIcon /> Protected by SynTrace identity security.</p>
      </section>
    </main>
  );
}
