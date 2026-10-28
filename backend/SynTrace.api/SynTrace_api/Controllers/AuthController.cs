using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using SynTrace.Application.Contracts.Auth;
using SynTrace.Application.Features.Auth.Commands.ForgotPassword;
using SynTrace.Application.Features.Auth.Commands.Login;
using SynTrace.Application.Features.Auth.Commands.Logout;
using SynTrace.Application.Features.Auth.Commands.RefreshToken;
using SynTrace.Application.Features.Auth.Commands.Register;
using SynTrace.Application.Features.Auth.Commands.SendOTP;

namespace SynTrace_api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AuthController : ControllerBase
    {
        private readonly IMediator _mediator;
        public AuthController(IMediator mediator)
        {
            _mediator = mediator;
        }

        [HttpPost("register")]
        public async Task<IActionResult> Register(RegisterCommand command)
        {
            var employee = await _mediator.Send(command);
            return Ok(employee);
        }

        [HttpPost("login")]
        public async Task<IActionResult> Login(LoginCommand command)
        {
            var token = await _mediator.Send(command);
            return Ok(token);
        }

        [HttpPost("send-otp")]
        public async Task<IActionResult> SendOTP(SendOTPCommand command)
        {
            await _mediator.Send(command);
            return Ok();
        }

        [HttpPost("verify-otp")]
        public async Task<IActionResult> VerifyOTP(VerifyOTPCommand command)
        {
            var isValid = await _mediator.Send(command);
            return Ok(isValid);
        }

        [HttpPost("reset-password")]
        public async Task<IActionResult> ResetPassword(ForgotPasswordCommand command)
        {
            await _mediator.Send(command);
            return Ok();
        }

        [HttpPost("refresh-token")]
        public async Task<IActionResult> RefreshToken(RefreshTokenCommand command)
        {
            var refreshToken = await _mediator.Send(command);
            return Ok(refreshToken);
        }

        [HttpPost("logout")]
        public async Task<IActionResult> Logout(LogoutCommand command)
        {
            await _mediator.Send(command);
            return Ok();
        }
    }
}
