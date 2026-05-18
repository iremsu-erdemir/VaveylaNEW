using System.ComponentModel.DataAnnotations;

namespace Vaveyla.Api.Models;

public sealed record UserAddressDto(
    Guid AddressId,
    string Label,
    string AddressLine,
    string? AddressDetail,
    bool IsSelected,
    DateTime CreatedAtUtc);

public sealed class CreateUserAddressRequest
{
    [Required]
    [MaxLength(64)]
    public string Label { get; set; } = string.Empty;

    [Required]
    [MaxLength(320)]
    public string AddressLine { get; set; } = string.Empty;

    [MaxLength(320)]
    public string? AddressDetail { get; set; }

    public bool IsSelected { get; set; } = true;
}

public sealed class UpdateUserAddressRequest
{
    [Required]
    [MaxLength(64)]
    public string Label { get; set; } = string.Empty;

    [Required]
    [MaxLength(320)]
    public string AddressLine { get; set; } = string.Empty;

    [MaxLength(320)]
    public string? AddressDetail { get; set; }

    public bool IsSelected { get; set; }
}
