namespace Vaveyla.Api.Models;

public enum AddressLabelType : byte
{
    Home = 1,
    Work = 2,
    Other = 3,
}

public sealed class UserAddress
{
    public Guid AddressId { get; set; }
    public Guid UserId { get; set; }
    public string Label { get; set; } = string.Empty;
    public AddressLabelType LabelType { get; set; } = AddressLabelType.Other;
    public string AddressLine { get; set; } = string.Empty;
    public string? AddressDetail { get; set; }
    public string? Floor { get; set; }
    public string? Apartment { get; set; }
    public string? DirectionsNote { get; set; }
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public bool IsSelected { get; set; }
    public DateTime CreatedAtUtc { get; set; }

    public User? User { get; set; }
}
