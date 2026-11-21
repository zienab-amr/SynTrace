using System.ComponentModel.DataAnnotations;

namespace SynTrace.Application.DTOs.Requests;

public sealed class RegisterRequestDTO
{
    [Required, StringLength(200)]
    public string CompanyName { get; set; } = string.Empty;

    [Required, StringLength(100)]
    public string FirstName { get; set; } = string.Empty;

    [Required, StringLength(100)]
    public string LastName { get; set; } = string.Empty;

    [Required, EmailAddress, StringLength(256)]
    public string Email { get; set; } = string.Empty;

    [StringLength(32)]
    public string? PhoneNumber { get; set; }

    [Required, StringLength(128)]
    public string Password { get; set; } = string.Empty;

    [StringLength(64)]
    public string? VerificationToken { get; set; }

    [RegularExpression("[0-9]{6}")]
    public string? OTP { get; set; }
}
