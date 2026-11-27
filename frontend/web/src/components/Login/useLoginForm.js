import { useCallback, useEffect, useRef, useState } from 'react';
import { useAuth } from '../../context/AuthContext.jsx';
import { useLoginThrottle } from '../../hooks/useLoginThrottle.js';
import { navigate } from '../../router/router.jsx';
import { normalizeEmail, validateEmail, validatePassword } from '../../lib/validation.js';

const MIN_FEEDBACK_MS = 600; // same wait for every outcome: no timing hints about the account
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

export function useLoginForm({ redirectTo }) {
  const { login } = useAuth();
  const throttle = useLoginThrottle();
  const emailRef = useRef(null);
  const passwordRef = useRef(null);
  const mounted = useRef(true);

  const [values, setValues] = useState({ email: '', password: '' });
  const [errors, setErrors] = useState({ email: '', password: '' });
  const [formError, setFormError] = useState(null); // { code }
  const [submitting, setSubmitting] = useState(false);
  const [success, setSuccess] = useState(false);
  const [shakeKey, setShakeKey] = useState(0);
  const [capsLock, setCapsLock] = useState(false);

  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
    };
  }, []);

  const setField = useCallback((name, value) => {
    setValues((prev) => ({ ...prev, [name]: value }));
    setErrors((prev) => (prev[name] ? { ...prev, [name]: '' } : prev));
    setFormError(null);
  }, []);

  const validateField = useCallback((name) => {
    setErrors((prev) => ({
      ...prev,
      [name]: name === 'email' ? validateEmail(values.email) : validatePassword(values.password),
    }));
  }, [values]);

  const trackCapsLock = useCallback((event) => {
    if (typeof event.getModifierState === 'function') setCapsLock(event.getModifierState('CapsLock'));
  }, []);

  const submit = useCallback(async (event) => {
    event.preventDefault();
    if (submitting || success || throttle.locked) return;

    const next = { email: validateEmail(values.email), password: validatePassword(values.password) };
    setErrors(next);
    if (next.email || next.password) {
      setShakeKey((key) => key + 1);
      (next.email ? emailRef : passwordRef).current?.focus();
      return;
    }

    setSubmitting(true);
    setFormError(null);
    const startedAt = performance.now();
    try {
      await login(normalizeEmail(values.email), values.password);
      await wait(Math.max(0, MIN_FEEDBACK_MS - (performance.now() - startedAt)));
      throttle.reset();
      if (!mounted.current) return;
      setSuccess(true);
      await wait(750); // let the success animation play
      navigate(redirectTo, { replace: true });
    } catch (error) {
      await wait(Math.max(0, MIN_FEEDBACK_MS - (performance.now() - startedAt)));
      if (!mounted.current) return;
      const code = error?.code ?? 'SERVER';
      if (code === 'INVALID_CREDENTIALS' || code === 'FORBIDDEN') throttle.recordFailure();
      if (code === 'RATE_LIMITED') throttle.lockFor(error.retryAfter ?? 60);
      setValues((prev) => ({ ...prev, password: '' })); // never keep a failed password in memory
      setFormError({ code });
      setShakeKey((key) => key + 1);
      passwordRef.current?.focus();
    } finally {
      if (mounted.current) setSubmitting(false);
    }
  }, [login, redirectTo, submitting, success, throttle, values]);

  return {
    values, errors, formError, submitting, success, shakeKey, capsLock,
    locked: throttle.locked, remaining: throttle.remaining,
    emailRef, passwordRef, setField, validateField, trackCapsLock, submit,
  };
}
