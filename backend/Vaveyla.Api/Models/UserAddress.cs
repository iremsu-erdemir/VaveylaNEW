namespace Vaveyla.Api.Models;

public sealed class UserAddress
{
    public Guid AddressId { get; set; }
    public Guid UserId { get; set; }
    public string Label { get; set; } = string.Empty;
    public string AddressLine { get; set; } = string.Empty;
    public string? AddressDetail { get; set; }
    public bool IsSelected { get; set; }
    public DateTime CreatedAtUtc { get; set; }

    public User? User { get; set; }
}
