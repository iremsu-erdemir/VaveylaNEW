namespace Vaveyla.Api.Models;

public sealed class RestaurantChatMessage
{
    public Guid ChatMessageId { get; set; }
    public Guid RestaurantId { get; set; }
    public Guid CustomerUserId { get; set; }
    public Guid SenderUserId { get; set; }
    public string SenderType { get; set; } = "customer";
    public string Message { get; set; } = string.Empty;
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
}
