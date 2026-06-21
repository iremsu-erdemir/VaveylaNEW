using System.Text.Json.Serialization;

namespace Vaveyla.Api.Models;

public sealed record MenuItemDto(
    Guid Id,
    string? CategoryName,
    string Name,
    int Price,
    /// <summary>0 = kilo, 1 = dilim.</summary>
    [property: JsonPropertyName("saleUnit")] byte SaleUnit,
    [property: JsonPropertyName("imagePath")] string ImagePath,
    bool IsAvailable,
    bool IsFeatured);

public sealed record CreateMenuItemRequest(
    string Name,
    int Price,
    [property: JsonPropertyName("imagePath")] string? ImagePath,
    bool? IsAvailable,
    bool? IsFeatured,
    [property: JsonPropertyName("categoryName")] string? CategoryName,
    /// <summary>0 = kilo, 1 = dilim. Varsayılan 0.</summary>
    [property: JsonPropertyName("saleUnit")] byte? SaleUnit);

public sealed record UpdateMenuItemRequest(
    string? Name,
    int? Price,
    [property: JsonPropertyName("imagePath")] string? ImagePath,
    bool? IsAvailable,
    bool? IsFeatured,
    [property: JsonPropertyName("categoryName")] string? CategoryName,
    [property: JsonPropertyName("saleUnit")] byte? SaleUnit);

public sealed record RestaurantOrderDto(
    Guid Id,
    string Time,
    string Date,
    [property: JsonPropertyName("imagePath")] string ImagePath,
    string Items,
    int Total,
    string Status,
    [property: JsonPropertyName("preparationMinutes")] int? PreparationMinutes,
    [property: JsonPropertyName("assignedCourierUserId")] Guid? AssignedCourierUserId = null,
    [property: JsonPropertyName("assignedCourierName")] string? AssignedCourierName = null,
    [property: JsonPropertyName("rejectionReason")] string? RejectionReason = null,
    /// <summary>Ham müşteri sipariş durumu: pending, preparing, assigned, inTransit, delivered, cancelled.</summary>
    [property: JsonPropertyName("fulfillmentStatus")] string? FulfillmentStatus = null,
    [property: JsonPropertyName("canAssignCourier")] bool CanAssignCourier = false,
    [property: JsonPropertyName("courierReassignmentRequired")] bool CourierReassignmentRequired = false,
    [property: JsonPropertyName("courierReleaseReason")] string? CourierReleaseReason = null);

public sealed record CourierAccountDto(
    Guid Id,
    string FullName,
    string? Email,
    string? Phone);

public sealed record AssignCourierToOrderRequest(
    [property: JsonPropertyName("courierUserId")] Guid CourierUserId);

public sealed record CreateOrderRequest(
    string Items,
    int Total,
    [property: JsonPropertyName("imagePath")] string? ImagePath,
    [property: JsonPropertyName("preparationMinutes")] int? PreparationMinutes,
    string? Status,
    DateTime? CreatedAtUtc);

public sealed record UpdateOrderStatusRequest(
    string Status,
    string? RejectionReason = null);

public sealed record RestaurantReviewDto(
    Guid Id,
    string CustomerName,
    double Rating,
    string Comment,
    string Date,
    string? OwnerReply);

public sealed record UpdateReviewReplyRequest(string OwnerReply);

public sealed record OwnerChatConversationDto(
    Guid CustomerUserId,
    string CustomerName,
    string LastMessage,
    string LastMessageSenderType,
    DateTime LastMessageAtUtc,
    int MessageCount);

public sealed record OwnerChatMessageDto(
    Guid Id,
    Guid RestaurantId,
    Guid CustomerUserId,
    Guid SenderUserId,
    string SenderType,
    string SenderName,
    string Message,
    DateTime CreatedAtUtc);

public sealed record OwnerSendChatMessageRequest(
    Guid CustomerUserId,
    string Message);

public sealed record RestaurantSettingsDto
{
    public Guid RestaurantId { get; init; }
    public string RestaurantName { get; init; } = string.Empty;
    public string RestaurantType { get; init; } = string.Empty;
    public string Address { get; init; } = string.Empty;
    public double? Latitude { get; init; }
    public double? Longitude { get; init; }
    public string Phone { get; init; } = string.Empty;
    public string WorkingHours { get; init; } = string.Empty;
    public bool OrderNotifications { get; init; }
    public bool IsOpen { get; init; }
    public double Rating { get; init; }
    public int ReviewCount { get; init; }
    public string? RestaurantPhotoPath { get; init; }
    public decimal? RestaurantDiscountPercent { get; init; }
    public bool RestaurantDiscountApproved { get; init; }
    public bool RestaurantDiscountIsActive { get; init; }
    /// <summary>Gösterim: "Kampanya Adı %15 (Aktif)" veya "Restoran İndirimi %15 (Pasif)" vb.</summary>
    public string? ActiveCampaignDisplayText { get; init; }
    public Dictionary<int, int> RatingDistribution { get; init; } = new();
    public List<RestaurantReviewDto> Reviews { get; init; } = new();
}

public sealed record UpdateRestaurantSettingsRequest
{
    public string? RestaurantName { get; init; }
    public string? RestaurantType { get; init; }
    public string? Address { get; init; }
    public double? Latitude { get; init; }
    public double? Longitude { get; init; }
    public string? Phone { get; init; }
    public string? WorkingHours { get; init; }
    public bool? OrderNotifications { get; init; }
    public bool? IsOpen { get; init; }
    public string? RestaurantPhotoPath { get; init; }
    /// <summary>0-100 arası yüzde. Admin onayından sonra aktif.</summary>
    public decimal? RestaurantDiscountPercent { get; init; }
}

public sealed record UpdateDiscountRequest(decimal? RestaurantDiscountPercent);

public sealed record ToggleDiscountActiveRequest(bool IsActive);
