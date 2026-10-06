using SynTrace.Application.DTOs.Requests;

namespace SynTrace.Domain.Interfaces
{
    public interface IOTPService
    {
        public string GenerateOTP();

        public Task SendOTP(OTPRequestDTO requestDto);

        public Task<bool> VerifyOTP(VerifyOTPRequestDTO requestDto);

        public bool IsEmailVerified(string email);

        public void RemoveEmailVerification(string email);
    }
}
