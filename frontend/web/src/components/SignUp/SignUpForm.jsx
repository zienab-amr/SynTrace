import { useId, useState } from 'react';
import ThemeToggle from '../common/ThemeToggle.jsx';
import LoginStage from '../Login/LoginStage.jsx';
import { Link } from '../../router/router.jsx';
import { BackIcon, EyeIcon, EyeOffIcon, LockIcon, MailIcon } from '../Login/LoginIcons.jsx';
import '../Login/login.css';
import './signup.css';

function PasswordField({ id, name, label, value, onChange, order }) {
  const [visible, setVisible] = useState(false);
  return (
    <div className="field" style={{ '--i': order }}>
      <label htmlFor={id}>{label}</label>
      <div className="field__control">
        <span className="field__icon"><LockIcon /></span>
        <input
          id={id}
          name={name}
          type={visible ? 'text' : 'password'}
          placeholder={label}
          autoComplete={name === 'password' ? 'new-password' : 'off'}
          value={value}
          onChange={(event) => onChange(event.target.value)}
          required
        />
        <button
          type="button"
          className="field__toggle"
          onClick={() => setVisible((current) => !current)}
          onMouseDown={(event) => event.preventDefault()}
          aria-pressed={visible}
          aria-label={visible ? `Hide ${label}` : `Show ${label}`}
        >
          {visible ? <EyeOffIcon /> : <EyeIcon />}
        </button>
      </div>
    </div>
  );
}

function TextField({ id, name, label, type = 'text', value, onChange, order, icon, autoComplete, optional = false }) {
  return (
    <div className="field" style={{ '--i': order }}>
      <label htmlFor={id}>{label}{optional && <small className="register-optional">Optional</small>}</label>
      <div className="field__control">
        {icon && <span className="field__icon">{icon}</span>}
        <input
          id={id}
          name={name}
          type={type}
          placeholder={label}
          autoComplete={autoComplete}
          value={value}
          onChange={(event) => onChange(event.target.value)}
          required={!optional}
        />
      </div>
    </div>
  );
}

export default function SignUpForm({ form, setField, onContinue }) {
  const uid = useId();
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const updateField = (name, value) => {
    setField(name, value);
    setError('');
  };

  const submit = async (event) => {
    event.preventDefault();
    const required = ['companyName', 'firstName', 'lastName', 'email', 'password'];
    if (required.some((key) => !form[key].trim())) return setError('Please complete all required fields.');
    if (!/^\S+@\S+\.\S+$/.test(form.email)) return setError('Enter a valid work email.');
    if (form.password !== form.confirmPassword) return setError('Passwords do not match.');
    setLoading(true);
    setError('');
    try {
      await onContinue(form);
    } catch (requestError) {
      setError(requestError?.data?.message || requestError?.data?.title || 'We could not send the verification code. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <main className="login register-page" aria-labelledby={`${uid}-title`}>
      <div className="login__bg" aria-hidden="true" />
      <div className="login__tools">
        <Link to="/login" className="login__back"><BackIcon /> Back to sign in</Link>
        <ThemeToggle />
      </div>
      <section className="login__stage" aria-hidden="true"><LoginStage /></section>
      <section className="login__panel register__panel">
        <header className="login__brand">
          <img src="/assets/syntrace-mark.webp" alt="" height="56" />
          <span className="login__wordmark">SynTrace</span>
          <p>Connect. Understand. Trace.</p>
        </header>
        <div className="login__card register__card">
          <p className="register__eyebrow">CREATE YOUR WORKSPACE</p>
          <h1 id={`${uid}-title`}>Create your account</h1>
          <p className="login__sub">Start connecting your engineering ecosystem.</p>
          <form onSubmit={submit} noValidate aria-busy={loading}>
            <TextField id={`${uid}-company`} name="companyName" label="Company name" value={form.companyName} onChange={(value) => updateField('companyName', value)} autoComplete="organization" order={0} icon={<LockIcon />} />
            <div className="register-row" style={{ '--i': 1 }}>
              <TextField id={`${uid}-first-name`} name="firstName" label="First name" value={form.firstName} onChange={(value) => updateField('firstName', value)} autoComplete="given-name" order={1} />
              <TextField id={`${uid}-last-name`} name="lastName" label="Last name" value={form.lastName} onChange={(value) => updateField('lastName', value)} autoComplete="family-name" order={1} />
            </div>
            <div className="register-row" style={{ '--i': 2 }}>
              <TextField id={`${uid}-email`} name="email" label="Work email" type="email" value={form.email} onChange={(value) => updateField('email', value)} autoComplete="email" order={2} icon={<MailIcon />} />
              <TextField id={`${uid}-phone`} name="phoneNumber" label="Phone number" type="tel" value={form.phoneNumber} onChange={(value) => updateField('phoneNumber', value)} autoComplete="tel" order={2} optional />
            </div>
            <div className="register-row" style={{ '--i': 3 }}>
              <PasswordField id={`${uid}-password`} name="password" label="Password" value={form.password} onChange={(value) => updateField('password', value)} order={3} />
              <PasswordField id={`${uid}-confirm-password`} name="confirmPassword" label="Confirm password" value={form.confirmPassword} onChange={(value) => updateField('confirmPassword', value)} order={3} />
            </div>
            {error && <p className="login__alert register-alert" role="alert">{error}</p>}
            <button className="login__submit" type="submit" disabled={loading} data-state={loading ? 'loading' : 'idle'} style={{ '--i': 4 }}>
              <span className="login__submit-label">
                {loading ? <><span className="spinner" aria-hidden="true" /> Sending code…</> : <>Continue</>}
              </span>
            </button>
          </form>
          <p className="login__signup">Already have an account? <Link to="/login" className="login__link">Sign in</Link></p>
        </div>
        <p className="login__legal"><LockIcon /> Sessions are encrypted. Your password is never stored in this browser.</p>
      </section>
    </main>
  );
}
