namespace Vaveyla.Api.Models;

public enum RefundRequestStatus : byte
{
    Pending = 1,
    Approved = 2,
    Rejected = 3,
    Completed = 4,
}

public enum OrderCancelReason : byte
{
    ChangedMind = 1,
    WrongOrder = 2,
    LateDelivery = 3,
    QualityIssue = 4,
    Other = 99,
}

public sealed class OrderRefundRequest
{
    public Guid RefundRequestId { get; set; }
    public Guid OrderId { get; set; }
    public Guid CustomerUserId { get; set; }
    public Guid RestaurantId { get; set; }
    public RefundRequestStatus Status { get; set; }
    public OrderCancelReason Reason { get; set; }
    public string? ReasonNote { get; set; }
    public string? RestaurantResponse { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime? ResolvedAtUtc { get; set; }
    public Guid? ResolvedByUserId { get; set; }

    public CustomerOrder? Order { get; set; }
}
