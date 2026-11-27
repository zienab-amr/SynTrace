// Client-side validation is for UX only: the backend must validate everything again.
export const EMAIL_MAX = 254;
export const PASSWORD_MAX = 128;

export const normalizeEmail = (value) => value.trim().toLowerCase();

export function validateEmail(value) {
  const email = normalizeEmail(value);
  if (!email) return 'Enter your work email.';
  if (email.length > EMAIL_MAX || !/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) {
    return 'Enter a valid email address.';
  }
  return '';
}

// Login never enforces a password policy (that belongs to sign-up / reset), it only checks presence.
export function validatePassword(value) {
  if (!value) return 'Enter your password.';
  if (value.length > PASSWORD_MAX) return 'That password is too long.';
  return '';
}
