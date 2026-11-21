using System.ComponentModel.DataAnnotations;

namespace SynTrace.Application.DTOs.Requests;

public sealed class ForgotPasswordRequestDTO
{
    [Required, EmailAddress, StringLength(256)]
    public string Email { get; set; } = string.Empty;

    [Required, RegularExpression("[0-9]{6}")]
    public string OTP { get; set; } = string.Empty;

    [Required, StringLength(128)]
    public string NewPassword { get; set; } = string.Empty;

    [Required, StringLength(128)]
    public string ConfirmPassword { get; set; } = string.Empty;
}
