namespace Vaveyla.Api.Models;

public enum NotificationType : byte
{
    OrderCreated = 1,
    OrderPreparing = 2,
    CourierDispatched = 3,
    OrderDelivered = 4,
    NewOrderForOwner = 5,
    OrderCancelledForOwner = 6,
    CourierPickedUpForOwner = 7,
    NewDeliveryTaskForCourier = 8,
    OrderReadyForCourier = 9,
    DeliveryCompletedForCourier = 10,
    /// Müşteri ↔ kurye teslimat sohbeti (anlık bildirim + liste).
    DeliveryChatMessage = 11,
    AccountSuspended = 12,
    Generic = 250,
}

public sealed class Notification
{
    public Guid NotificationId { get; set; }
    public Guid UserId { get; set; }
    public UserRole UserRole { get; set; }
    public NotificationType Type { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public string? DataJson { get; set; }
    public Guid? RelatedOrderId { get; set; }
    public bool IsRead { get; set; }
    public DateTime? ReadAtUtc { get; set; }
    public DateTime CreatedAtUtc { get; set; }
}

public sealed class UserDeviceToken
{
    public Guid DeviceTokenId { get; set; }
    public Guid UserId { get; set; }
    public string Platform { get; set; } = string.Empty;
    public string Token { get; set; } = string.Empty;
    public DateTime LastSeenAtUtc { get; set; }
    public DateTime CreatedAtUtc { get; set; }
}
