namespace Vaveyla.Api.Models;

public sealed class DeliveryChatMessage
{
    public Guid MessageId { get; set; }
    public Guid OrderId { get; set; }
    public Guid SenderUserId { get; set; }
    public string Message { get; set; } = string.Empty;
    public DateTime CreatedAtUtc { get; set; }
    public DateTime? EditedAtUtc { get; set; }
    public DateTime? DeletedAtUtc { get; set; }
}
