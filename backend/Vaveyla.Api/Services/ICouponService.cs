using Vaveyla.Api.Models;

namespace Vaveyla.Api.Services;

public interface ICouponService
{
    /// <summary>Kullanıcı kupon kodu girer, UserCoupon oluşturulur (Pending).</summary>
    Task<ApplyCouponCodeResponse?> ApplyCodeAsync(Guid userId, string code, CancellationToken ct = default);

    /// <summary>Kullanıcının kuponlarını listeler.</summary>
    Task<List<UserCouponDto>> GetMyCouponsAsync(Guid userId, CancellationToken ct = default);

    /// <summary>Sepet tutarı ve restoran için kupon indirimi hesaplar. Restoran indirimi varsa null döner.</summary>
    Task<(decimal DiscountAmount, string? Error)> CalculateCouponDiscountAsync(
        Guid userId,
        Guid restaurantId,
        decimal cartTotalAfterOtherDiscounts,
        Guid userCouponId,
        CancellationToken ct = default);

    /// <summary>Kuponu siparişte kullandığında UserCoupon'u Used yapar. Race condition için transaction kullanılmalı.</summary>
    Task<bool> MarkCouponAsUsedAsync(Guid userCouponId, Guid orderId, CancellationToken ct = default);
}
