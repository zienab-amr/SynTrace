using System;
using System.Collections.Generic;
using System.Text;

namespace SynTrace.Domain.Interfaces
{
    public interface IEmailService
    {
        public Task SendOTP(string toEmail, string otp);
    }
}
