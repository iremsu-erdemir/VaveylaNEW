namespace Vaveyla.Api.Models;

/// <summary>Müşteri şikayeti. Hedef yalnızca TargetType + TargetEntityId ile tutulur (normalize).</summary>
public sealed class Feedback
{
    public int Id { get; set; }

    /// <summary>Şikayet eden müşteri (Users.UserId).</summary>
    public Guid CustomerId { get; set; }

    public FeedbackTargetType TargetType { get; set; }

    /// <summary>
    /// Hedef varlık: BakeryProduct → MenuItemId, BakeryOrder → CustomerOrder.OrderId, Courier → kurye UserId.
    /// </summary>
    public Guid TargetEntityId { get; set; }

    public string Message { get; set; } = string.Empty;

    public DateTime CreatedAtUtc { get; set; }

    public FeedbackStatus Status { get; set; } = FeedbackStatus.New;
}
