using System.ComponentModel.DataAnnotations;

namespace Vaveyla.Api.Models;

public sealed record PaymentCardDto(
    Guid PaymentCardId,
    string CardholderName,
    string CardNumber,
    string Expiration,
    string CVC,
    string BankName,
    string CardAlias,
    DateTime CreatedAtUtc);

public sealed class CreatePaymentCardRequest
{
    [Required]
    [MaxLength(120)]
    public string CardholderName { get; set; } = string.Empty;

    [Required]
    [MaxLength(32)]
    public string CardNumber { get; set; } = string.Empty;

    [Required]
    [MaxLength(10)]
    public string Expiration { get; set; } = string.Empty;

    [Required]
    [MaxLength(4)]
    public string CVC { get; set; } = string.Empty;

    [MaxLength(120)]
    public string? BankName { get; set; }

    [Required]
    [MaxLength(80)]
    public string CardAlias { get; set; } = string.Empty;
}

public sealed class UpdatePaymentCardRequest
{
    [Required]
    [MaxLength(120)]
    public string CardholderName { get; set; } = string.Empty;

    [Required]
    [MaxLength(32)]
    public string CardNumber { get; set; } = string.Empty;

    [Required]
    [MaxLength(10)]
    public string Expiration { get; set; } = string.Empty;

    [Required]
    [MaxLength(4)]
    public string CVC { get; set; } = string.Empty;

    [MaxLength(120)]
    public string? BankName { get; set; }

    [Required]
    [MaxLength(80)]
    public string CardAlias { get; set; } = string.Empty;
}
