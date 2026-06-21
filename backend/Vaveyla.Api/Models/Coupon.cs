namespace Vaveyla.Api.Models;

/// <summary>1: Percentage, 2: Fixed</summary>
public enum CouponDiscountType : int
{
    Percentage = 1,
    Fixed = 2,
}

/// <summary>pending, approved, used, expired</summary>
public enum CouponStatus : int
{
    Pending = 1,
    Approved = 2,
    Used = 3,
    Expired = 4,
}

/// <summary>UserCoupon status</summary>
public enum UserCouponStatus : int
{
    Pending = 1,   // Admin onayı bekliyor
    Approved = 2,  // Onaylandı, kullanılabilir
    Used = 3,      // Kullanıldı
    Expired = 4,   // Süresi doldu
}

public sealed class Coupon
{
    public Guid CouponId { get; set; }
    public string Code { get; set; } = string.Empty;
    public string? Description { get; set; }
    public CouponDiscountType DiscountType { get; set; }
    public decimal DiscountValue { get; set; }
    public decimal? MinCartAmount { get; set; }
    public decimal? MaxDiscountAmount { get; set; }
    public DateTime ExpiresAtUtc { get; set; }
    /// <summary>null = global kupon (tüm restoranlar), dolu = sadece o restoranda geçerli</summary>
    public Guid? RestaurantId { get; set; }
    public DateTime CreatedAtUtc { get; set; }
}

public sealed class UserCoupon
{
    public Guid UserCouponId { get; set; }
    public Guid UserId { get; set; }
    public Guid CouponId { get; set; }
    public UserCouponStatus Status { get; set; }
    public DateTime? UsedAtUtc { get; set; }
    public Guid? OrderId { get; set; }
    public DateTime CreatedAtUtc { get; set; }

    public User User { get; set; } = null!;
    public Coupon Coupon { get; set; } = null!;
}
