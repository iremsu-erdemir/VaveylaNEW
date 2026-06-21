using System.ComponentModel.DataAnnotations;

namespace Vaveyla.Api.Models;

public sealed class LoginRequest
{
    [Required(ErrorMessage = "Lütfen e-posta adresinizi giriniz.")]
    [EmailAddress(ErrorMessage = "Geçerli bir e-posta adresi giriniz.")]
    [MaxLength(256)]
    public string Email { get; set; } = string.Empty;

    [Required(ErrorMessage = "Lütfen şifrenizi giriniz.")]
    [MinLength(6, ErrorMessage = "Şifre en az 6 karakter olmalıdır.")]
    [MaxLength(100)]
    public string Password { get; set; } = string.Empty;
}
