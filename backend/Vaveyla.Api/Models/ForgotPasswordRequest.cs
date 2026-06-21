using System.ComponentModel.DataAnnotations;

namespace Vaveyla.Api.Models;

public sealed class ForgotPasswordRequest
{
    [Required]
    [EmailAddress]
    [MaxLength(256)]
    public string Email { get; set; } = string.Empty;
}
