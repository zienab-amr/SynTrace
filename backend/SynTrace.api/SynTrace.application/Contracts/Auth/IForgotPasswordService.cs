using SynTrace.Application.DTOs.Requests;

namespace SynTrace.Application.Contracts.Auth
{
    public interface IForgotPasswordService
    {
        public Task ForgotPasswordAsync(ForgotPasswordRequestDTO forgotPassword);

    }
}
