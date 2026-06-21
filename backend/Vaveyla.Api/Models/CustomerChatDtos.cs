namespace Vaveyla.Api.Models;

/// <param name="Kind"><c>restaurant</c> veya <c>delivery</c> (kurye teslimat sohbeti).</param>
/// <param name="OrderId">Yalnızca <c>delivery</c> için dolu.</param>
/// <param name="CourierName">Teslimat satırı: atanmış kurye adı (yoksa null).</param>
/// <param name="OrderItemsPreview">Teslimat: sipariş ürün özeti metni.</param>
public sealed record CustomerChatConversationDto(
    Guid RestaurantId,
    string RestaurantName,
    string LastMessage,
    string LastMessageSenderType,
    DateTime LastMessageAtUtc,
    int MessageCount,
    string Kind = "restaurant",
    Guid? OrderId = null,
    string? CourierName = null,
    string? OrderItemsPreview = null);

