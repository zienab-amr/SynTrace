using System.ComponentModel.DataAnnotations;

namespace SynTrace.Application.DTOs.Requests;

public sealed class OTPRequestDTO
{
    [Required, EmailAddress, StringLength(256)]
    public string Email { get; set; } = string.Empty;

    public string Purpose { get; set; } = "registration";
}
