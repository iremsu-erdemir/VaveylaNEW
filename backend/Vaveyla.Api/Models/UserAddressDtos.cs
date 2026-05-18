using System.ComponentModel.DataAnnotations;

namespace Vaveyla.Api.Models;

public sealed record UserAddressDto(
    Guid AddressId,
    string Label,
    AddressLabelType LabelType,
    string AddressLine,
    string? AddressDetail,
    string? Floor,
    string? Apartment,
    string? DirectionsNote,
    double? Latitude,
    double? Longitude,
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

    public AddressLabelType LabelType { get; set; } = AddressLabelType.Other;

    [MaxLength(20)]
    public string? Floor { get; set; }

    [MaxLength(20)]
    public string? Apartment { get; set; }

    [MaxLength(500)]
    public string? DirectionsNote { get; set; }

    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
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

    public AddressLabelType LabelType { get; set; } = AddressLabelType.Other;

    [MaxLength(20)]
    public string? Floor { get; set; }

    [MaxLength(20)]
    public string? Apartment { get; set; }

    [MaxLength(500)]
    public string? DirectionsNote { get; set; }

    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
}

public sealed record DeliveryZoneCheckRequest(
    Guid RestaurantId,
    double Latitude,
    double Longitude);
