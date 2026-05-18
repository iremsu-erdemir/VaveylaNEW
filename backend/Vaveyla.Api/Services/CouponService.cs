using Vaveyla.Api.Data;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Services;

public sealed class CouponService : ICouponService
{
    private readonly ICouponRepository _couponRepo;

    public CouponService(ICouponRepository couponRepo)
    {
        _couponRepo = couponRepo;
    }

    public async Task<ApplyCouponCodeResponse?> ApplyCodeAsync(Guid userId, string code, CancellationToken ct = default)
    {
        var normalized = code?.Trim().ToUpperInvariant() ?? string.Empty;
        if (string.IsNullOrEmpty(normalized))
            return null;

        var coupon = await _couponRepo.GetByCodeAsync(normalized, ct);
        if (coupon == null)
            return null;

        var existing = await _couponRepo.GetUserCouponAsync(userId, coupon.CouponId, ct);
        if (existing != null)
        {
            if (existing.Status == UserCouponStatus.Approved)
                return new ApplyCouponCodeResponse(existing.UserCouponId, coupon.Code, "Bu kupon zaten cüzdanınızda.");
            if (existing.Status == UserCouponStatus.Used)
                return new ApplyCouponCodeResponse(existing.UserCouponId, coupon.Code, "Bu kupon daha önce kullanıldı.");
            if (existing.Status == UserCouponStatus.Pending)
            {
                if (coupon.ExpiresAtUtc < DateTime.UtcNow)
                {
                    existing.Status = UserCouponStatus.Expired;
                    await _couponRepo.UpdateUserCouponAsync(existing, ct);
                    return new ApplyCouponCodeResponse(existing.UserCouponId, coupon.Code, "Bu kuponun süresi dolmuş.");
                }
                existing.Status = UserCouponStatus.Approved;
                await _couponRepo.UpdateUserCouponAsync(existing, ct);
                return new ApplyCouponCodeResponse(existing.UserCouponId, coupon.Code, "Kupon onaylandı. Hemen kullanabilirsiniz.");
            }
            if (existing.Status == UserCouponStatus.Expired)
                return new ApplyCouponCodeResponse(existing.UserCouponId, coupon.Code, "Bu kuponun süresi dolmuş.");
        }

        if (coupon.ExpiresAtUtc < DateTime.UtcNow)
            return null;

        var userCoupon = new UserCoupon
        {
            UserCouponId = Guid.NewGuid(),
            UserId = userId,
            CouponId = coupon.CouponId,
            Status = UserCouponStatus.Approved,
            CreatedAtUtc = DateTime.UtcNow,
        };
        await _couponRepo.CreateUserCouponAsync(userCoupon, ct);
        return new ApplyCouponCodeResponse(
            userCoupon.UserCouponId,
            coupon.Code,
            "Kupon cüzdanınıza eklendi. Hemen kullanabilirsiniz.");
    }

    public async Task<List<UserCouponDto>> GetMyCouponsAsync(Guid userId, CancellationToken ct = default)
    {
        var list = await _couponRepo.GetUserCouponsAsync(userId, ct);
        return list.Select(ToDto).ToList();
    }

    public async Task<(decimal DiscountAmount, string? Error)> CalculateCouponDiscountAsync(
        Guid userId,
        Guid restaurantId,
        decimal cartTotalAfterOtherDiscounts,
        Guid userCouponId,
        CancellationToken ct = default)
    {
        var userCoupon = await _couponRepo.GetUserCouponAsync(userCouponId, ct);
        if (userCoupon == null)
            return (0, "Kupon bulunamadı.");
        if (userCoupon.UserId != userId)
            return (0, "Bu kupon size ait değil.");
        if (userCoupon.Status != UserCouponStatus.Approved)
            return (0, userCoupon.Status == UserCouponStatus.Pending
                ? "Kupon henüz onaylanmadı."
                : userCoupon.Status == UserCouponStatus.Used
                    ? "Bu kupon daha önce kullanıldı."
                    : "Kupon geçersiz veya süresi dolmuş.");

        var coupon = userCoupon.Coupon;
        if (coupon.ExpiresAtUtc < DateTime.UtcNow)
            return (0, "Kuponun süresi dolmuş.");

        if (coupon.RestaurantId.HasValue && coupon.RestaurantId != restaurantId)
            return (0, "Bu kupon bu restoran için geçerli değil.");

        if (coupon.MinCartAmount.HasValue && cartTotalAfterOtherDiscounts < coupon.MinCartAmount.Value)
            return (0, $"Minimum sepet tutarı {coupon.MinCartAmount.Value:N0} TL olmalıdır.");

        decimal discount;
        if (coupon.DiscountType == CouponDiscountType.Percentage)
        {
            discount = cartTotalAfterOtherDiscounts * (coupon.DiscountValue / 100m);
            if (coupon.MaxDiscountAmount.HasValue && discount > coupon.MaxDiscountAmount.Value)
                discount = coupon.MaxDiscountAmount.Value;
        }
        else
        {
            discount = Math.Min(coupon.DiscountValue, cartTotalAfterOtherDiscounts);
        }

        return (Math.Round(discount, 2), null);
    }

    public async Task<bool> MarkCouponAsUsedAsync(Guid userCouponId, Guid orderId, CancellationToken ct = default)
    {
        var userCoupon = await _couponRepo.GetUserCouponAsync(userCouponId, ct);
        if (userCoupon == null || userCoupon.Status != UserCouponStatus.Approved)
            return false;

        // Aynı kupon şablonu için kalan başka onaylı/pending atamaları pasifleştir (tek kullanım).
        await _couponRepo.ExpireOtherActiveUserCouponsAsync(
            userCoupon.UserId,
            userCoupon.CouponId,
            userCouponId,
            ct);

        userCoupon.Status = UserCouponStatus.Used;
        userCoupon.UsedAtUtc = DateTime.UtcNow;
        userCoupon.OrderId = orderId;
        await _couponRepo.UpdateUserCouponAsync(userCoupon, ct);
        return true;
    }

    private static UserCouponDto ToDto(UserCoupon uc)
    {
        var c = uc.Coupon;
        var statusStr = uc.Status switch
        {
            UserCouponStatus.Pending => "pending",
            UserCouponStatus.Approved => "approved",
            UserCouponStatus.Used => "used",
            UserCouponStatus.Expired => "expired",
            _ => "unknown",
        };
        return new UserCouponDto(
            uc.UserCouponId,
            c.CouponId,
            c.Code,
            c.Description,
            (int)c.DiscountType,
            c.DiscountValue,
            c.MinCartAmount,
            c.MaxDiscountAmount,
            c.ExpiresAtUtc,
            c.RestaurantId,
            statusStr,
            uc.UsedAtUtc);
    }
}
