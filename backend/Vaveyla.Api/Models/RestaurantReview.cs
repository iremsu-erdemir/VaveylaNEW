namespace Vaveyla.Api.Models;

public sealed class RestaurantReview
{
    public Guid ReviewId { get; set; }
    public Guid RestaurantId { get; set; }
    public Guid CustomerUserId { get; set; }
    public string TargetType { get; set; } = "restaurant";
    public Guid TargetId { get; set; }
    public Guid? ProductId { get; set; }
    public string CustomerName { get; set; } = string.Empty;
    public byte Rating { get; set; }
    public string Comment { get; set; } = string.Empty;
    public string? OwnerReply { get; set; }
    public DateTime CreatedAtUtc { get; set; }
}
