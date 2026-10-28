using System.Net;
using System.Net.Mail;
using Microsoft.Extensions.Configuration;
using SynTrace.Domain.Interfaces;

namespace SynTrace.Infrastructure.ExternalServices
{
    public class EmailService : IEmailService
    {
        private readonly IConfiguration _config;

        public EmailService(IConfiguration config)
        {
            _config = config;
        }

        public async Task SendOTP(string toEmail, string otp)
        {
            using var smtp = new SmtpClient(_config["GmailSMTP:Host"])
            {
                Port = int.Parse(_config["GmailSMTP:Port"]!),
                EnableSsl = true,
                UseDefaultCredentials = false,
                Credentials = new NetworkCredential(
                    _config["GmailSMTP:Email"],
                    _config["GmailSMTP:AppPassword"])
            };

            using var mail = new MailMessage
            {
                From = new MailAddress(
                    _config["GmailSMTP:Email"]!,
                    _config["GmailSMTP:FromName"]),

                Subject = "SynTrace - Your OTP Code",

                Body = $"""
                    <div style='font-family: Arial; text-align: center;'>
                        <h2>مرحباً،</h2>
                        <p>كود التحقق الخاص بك هو:</p>
                        <h1 style='color: #007bff;'>{otp}</h1>
                        <p>الكود صالح لمدة 5 دقائق.</p>
                    </div>
                    """,

                IsBodyHtml = true
            };

            mail.To.Add(toEmail);

            await smtp.SendMailAsync(mail);
        }
    }
}