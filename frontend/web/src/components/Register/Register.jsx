import { useState } from 'react';
import { sendRegistrationOtp } from '../../services/registrationService.js';
import OtpVerification from '../OTP/OtpVerification.jsx';
import SignUpForm from '../SignUp/SignUpForm.jsx';

const emptyForm = {
  companyName: '',
  firstName: '',
  lastName: '',
  email: '',
  phoneNumber: '',
  password: '',
  confirmPassword: '',
};

export default function Register() {
  const [step, setStep] = useState('signup');
  const [form, setForm] = useState(emptyForm);

  const setField = (name, value) => {
    setForm((current) => ({ ...current, [name]: value }));
  };

  const continueToOtp = async (submittedForm) => {
    await sendRegistrationOtp(submittedForm.email.trim());
    setStep('otp');
  };

  if (step === 'otp') {
    return <OtpVerification form={form} onChangeEmail={() => setStep('signup')} />;
  }

  return <SignUpForm form={form} setField={setField} onContinue={continueToOtp} />;
}
