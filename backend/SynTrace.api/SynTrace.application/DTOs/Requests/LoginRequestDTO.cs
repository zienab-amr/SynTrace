using System.ComponentModel.DataAnnotations;

namespace SynTrace.Application.DTOs.Requests;

public sealed class LoginRequestDTO
{
    [Required, EmailAddress, StringLength(256)] public string Email { get; set; } = string.Empty;
    [Required, StringLength(128)] public string Password { get; set; } = string.Empty;
}
