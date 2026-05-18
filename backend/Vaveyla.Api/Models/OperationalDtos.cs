using System.ComponentModel.DataAnnotations;

namespace Vaveyla.Api.Models;

public sealed record OrderLineItemDto(
    Guid LineItemId,
    Guid ProductId,
    string ProductName,
    string? ImagePath,
    int Quantity,
    decimal WeightKg,
    byte SaleUnit,
    decimal UnitPrice,
    decimal LineTotal,
    string? VariationJson);

public sealed record OrderStatusHistoryDto(
    string Status,
    string? Note,
    string? ActorRole,
    DateTime CreatedAtUtc);

public sealed record OrderDetailDto(
    Guid Id,
    string OrderNumber,
    Guid RestaurantId,
    string? RestaurantName,
    string Status,
    DateTime CreatedAtUtc,
    string? DeliveryAddress,
    string? DeliveryAddressDetail,
    string? CourierName,
    string? PaymentMethod,
    string? OrderNotes,
    decimal Subtotal,
    decimal DeliveryFee,
    decimal TotalDiscount,
    decimal CouponDiscount,
    decimal Total,
    decimal? MinimumOrderAmount,
    bool MeetsMinimumOrder,
    string? CancellationReason,
    string? RejectionReason,
    List<OrderLineItemDto> LineItems,
    List<OrderStatusHistoryDto> StatusHistory,
    bool CanCancel,
    bool CanRequestRefund,
    bool CanReorder);

public sealed class CancelOrderRequest
{
    [Required]
    public OrderCancelReason Reason { get; set; }

    [MaxLength(500)]
    public string? ReasonNote { get; set; }
}

public sealed class CreateRefundRequestBody
{
    [Required]
    public OrderCancelReason Reason { get; set; }

    [MaxLength(500)]
    public string? ReasonNote { get; set; }
}

public sealed record RefundRequestDto(
    Guid RefundRequestId,
    Guid OrderId,
    string OrderNumber,
    string? RestaurantName,
    RefundRequestStatus Status,
    OrderCancelReason Reason,
    string? ReasonNote,
    string? RestaurantResponse,
    DateTime CreatedAtUtc,
    DateTime? ResolvedAtUtc,
    List<OrderStatusHistoryDto> StatusHistory);

public sealed class ResolveRefundRequest
{
    public bool Approve { get; set; }

    [MaxLength(500)]
    public string? ResponseNote { get; set; }
}

public sealed record DeliveryValidationRequest(
    Guid RestaurantId,
    double CustomerLat,
    double CustomerLng);

public sealed record DeliveryValidationResponse(
    bool IsDeliverable,
    double DistanceKm,
    decimal DeliveryFee,
    decimal? MinimumOrderAmount,
    decimal? MaxDeliveryDistanceKm,
    string? Message);

public sealed record ReorderResultDto(
    int AddedCount,
    int SkippedCount,
    List<string> UnavailableProducts,
    List<string> Warnings);

public sealed class RequestAccountDeletionBody
{
    [Required]
    public string Password { get; set; } = string.Empty;

    public bool ConfirmDataPolicy { get; set; }
}

public sealed record AccountDeletionStatusDto(
    bool IsDeletionScheduled,
    DateTime? DeletionScheduledAtUtc,
    int GracePeriodDays,
    string DataPolicySummary);

public sealed class VerifyEmailRequest
{
    [Required]
    [EmailAddress]
    public string Email { get; set; } = string.Empty;

    [Required]
    [MaxLength(8)]
    public string Code { get; set; } = string.Empty;
}

public sealed class SendSmsOtpRequest
{
    [Required]
    [MaxLength(40)]
    public string Phone { get; set; } = string.Empty;
}

public sealed class VerifySmsOtpRequest
{
    [Required]
    [MaxLength(40)]
    public string Phone { get; set; } = string.Empty;

    [Required]
    [MaxLength(8)]
    public string Code { get; set; } = string.Empty;
}
