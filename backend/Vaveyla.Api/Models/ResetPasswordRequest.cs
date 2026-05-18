using System.ComponentModel.DataAnnotations;

namespace Vaveyla.Api.Models;

public sealed class ResetPasswordRequest
{
    [Required]
    [EmailAddress]
    [MaxLength(256)]
    public string Email { get; set; } = string.Empty;

    [Required]
    [MinLength(4)]
    [MaxLength(10)]
    public string Code { get; set; } = string.Empty;

    [Required]
    [MinLength(6)]
    [MaxLength(100)]
    public string NewPassword { get; set; } = string.Empty;
}
