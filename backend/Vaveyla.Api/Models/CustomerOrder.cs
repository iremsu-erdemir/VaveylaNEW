namespace Vaveyla.Api.Models;

public enum CustomerOrderStatus : byte
{
    Pending = 1,      // Beklemede - pastane onayı
    Preparing = 2,    // Hazırlanıyor
    Assigned = 3,     // Kuryeye atandı
    InTransit = 4,    // Yolda
    Delivered = 5,    // Teslim edildi
    Cancelled = 6,
    /// <summary>Kurye atamayı bıraktı; restoran yeni kurye atayacak. Müşteri için iptal değildir.</summary>
    AwaitingCourierReassignment = 7,
}

public sealed class CustomerOrder
{
    public Guid OrderId { get; set; }
    public Guid CustomerUserId { get; set; }
    public Guid RestaurantId { get; set; }
    public string Items { get; set; } = string.Empty;  // "2x Çilekli Pasta, 1x Kapkek"
    public int Total { get; set; }
    public decimal TotalDiscount { get; set; }
    public Guid? AppliedUserCouponId { get; set; }
    public decimal? CouponDiscountAmount { get; set; }
    public decimal RestaurantEarning { get; set; }
    public decimal PlatformEarning { get; set; }
    public string DeliveryAddress { get; set; } = string.Empty;
    public string? DeliveryAddressDetail { get; set; }
    public double? CustomerLat { get; set; }
    public double? CustomerLng { get; set; }
    public string? RestaurantAddress { get; set; }
    public double? RestaurantLat { get; set; }
    public double? RestaurantLng { get; set; }
    public string? CustomerName { get; set; }
    public string? CustomerPhone { get; set; }
    public Guid? AssignedCourierUserId { get; set; }
    public double? CourierLat { get; set; }
    public double? CourierLng { get; set; }
    public DateTime? CourierLocationUpdatedAtUtc { get; set; }
    public CustomerOrderStatus Status { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    /// <summary>Restoran reddi veya diğer iptal senaryolarında müşteriye iletilen açıklama.</summary>
    public string? RejectionReason { get; set; }
}
