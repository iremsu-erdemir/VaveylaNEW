using System.Text.Json.Serialization;

namespace Vaveyla.Api.Models;

public sealed record ApplyCouponCodeRequest([property: JsonPropertyName("code")] string Code);

public sealed record ApplyCouponCodeResponse(
    [property: JsonPropertyName("userCouponId")] Guid UserCouponId,
    [property: JsonPropertyName("code")] string Code,
    [property: JsonPropertyName("message")] string Message);

public sealed record UserCouponDto(
    [property: JsonPropertyName("userCouponId")] Guid UserCouponId,
    [property: JsonPropertyName("couponId")] Guid CouponId,
    [property: JsonPropertyName("code")] string Code,
    [property: JsonPropertyName("description")] string? Description,
    [property: JsonPropertyName("discountType")] int DiscountType,
    [property: JsonPropertyName("discountValue")] decimal DiscountValue,
    [property: JsonPropertyName("minCartAmount")] decimal? MinCartAmount,
    [property: JsonPropertyName("maxDiscountAmount")] decimal? MaxDiscountAmount,
    [property: JsonPropertyName("expiresAtUtc")] DateTime ExpiresAtUtc,
    [property: JsonPropertyName("restaurantId")] Guid? RestaurantId,
    [property: JsonPropertyName("status")] string Status,
    [property: JsonPropertyName("usedAtUtc")] DateTime? UsedAtUtc);

public sealed record PendingUserCouponDto(
    [property: JsonPropertyName("userCouponId")] Guid UserCouponId,
    [property: JsonPropertyName("userId")] Guid UserId,
    [property: JsonPropertyName("code")] string Code,
    [property: JsonPropertyName("userEmail")] string? UserEmail,
    [property: JsonPropertyName("createdAtUtc")] DateTime CreatedAtUtc);
