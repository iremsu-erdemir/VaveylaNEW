namespace Vaveyla.Api.Models;

public enum RestaurantOrderStatus : byte
{
    Pending = 1,
    Preparing = 2,
    Completed = 3,
    Rejected = 4,
}

public sealed class RestaurantOrder
{
    public Guid OrderId { get; set; }
    public Guid RestaurantId { get; set; }
    public string Items { get; set; } = string.Empty;
    public string? ImagePath { get; set; }
    public int? PreparationMinutes { get; set; }
    public int Total { get; set; }
    public RestaurantOrderStatus Status { get; set; }
    public DateTime CreatedAtUtc { get; set; }
}
