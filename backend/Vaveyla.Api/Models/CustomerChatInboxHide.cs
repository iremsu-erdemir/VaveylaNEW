namespace Vaveyla.Api.Models;

/// <summary>Müşteri Sohbetler listesinden gizlenen restoran veya teslimat (sipariş) satırı.</summary>
public sealed class CustomerChatInboxHide
{
    public Guid HideId { get; set; }
    public Guid CustomerUserId { get; set; }

    /// <summary>Pastane sohbeti için dolu; teslimatta null.</summary>
    public Guid? RestaurantId { get; set; }

    /// <summary>Teslimat sohbeti için dolu; pastanede null.</summary>
    public Guid? OrderId { get; set; }

    public DateTime HiddenAtUtc { get; set; }
}
