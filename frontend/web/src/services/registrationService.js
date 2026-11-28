import { ENDPOINTS, USE_MOCK_AUTH } from '../config/api.js';
import { request } from './apiClient.js';

const mockWait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

export async function sendRegistrationOtp(email) {
  if (USE_MOCK_AUTH) {
    await mockWait(450);
    sessionStorage.setItem('st-registration-email', email);
    return { ok: true, developmentCode: '123456' };
  }
  return request(ENDPOINTS.sendOtp, {
    method: 'POST', body: { request: { email, purpose: 'registration' } }, auth: false,
  });
}

export async function verifyRegistrationOtp(email, otp) {
  if (USE_MOCK_AUTH) {
    await mockWait(450);
    if (otp !== '123456' || sessionStorage.getItem('st-registration-email') !== email) {
      const error = new Error('Invalid verification code'); error.data = { message: 'For local development, use code 123456.' }; throw error;
    }
    return { verified: true, verificationToken: 'mock-registration-verification-token' };
  }
  return request(ENDPOINTS.verifyOtp, {
    method: 'POST', body: { request: { email, otp } }, auth: false,
  });
}

export async function registerAccount(payload) {
  if (USE_MOCK_AUTH) {
    await mockWait(450);
    sessionStorage.setItem('st-registration-complete', JSON.stringify({ email: payload.email, name: `${payload.firstName} ${payload.lastName}` }));
    return { ok: true };
  }
  return request(ENDPOINTS.register, { method: 'POST', body: { request: payload }, auth: false });
}

export function getVerificationToken(response) {
  if (!response || typeof response !== 'object') return undefined;
  const verified = response.verified ?? response.Verified ?? response.data?.verified;
  if (verified === false) return undefined;
  return response.verificationToken
    ?? response.VerificationToken
    ?? response.data?.verificationToken
    ?? response.result?.verificationToken;
}


export function sendPasswordResetOtp(email) {
  if (USE_MOCK_AUTH) {
    return Promise.reject(new Error('Password reset requires the real SynTrace backend. Disable mock auth to use this flow.'));
  }
  return request(ENDPOINTS.sendOtp, {
    method: 'POST', body: { request: { email, purpose: 'passwordReset' } }, auth: false,
  });
}

export function resetPassword(payload) {
  if (USE_MOCK_AUTH) {
    return Promise.reject(new Error('Password reset requires the real SynTrace backend. Disable mock auth to use this flow.'));
  }
  return request(ENDPOINTS.resetPassword, {
    method: 'POST', body: { request: payload }, auth: false,
  });
}
