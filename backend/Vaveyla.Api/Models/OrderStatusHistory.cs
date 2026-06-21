namespace Vaveyla.Api.Models;

public sealed class OrderStatusHistory
{
    public Guid HistoryId { get; set; }
    public Guid OrderId { get; set; }
    public CustomerOrderStatus Status { get; set; }
    public string? Note { get; set; }
    public string? ActorRole { get; set; }
    public Guid? ActorUserId { get; set; }
    public DateTime CreatedAtUtc { get; set; }

    public CustomerOrder? Order { get; set; }
}
