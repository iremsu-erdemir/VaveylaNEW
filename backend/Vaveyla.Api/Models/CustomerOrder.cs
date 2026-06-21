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
    /// <summary>Müşteri iade talebi oluşturdu; restoran/admin onayı bekleniyor.</summary>
    RefundRequested = 8,
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
    public decimal Subtotal { get; set; }
    public decimal DeliveryFee { get; set; }
    public string? PaymentMethod { get; set; }
    public string? OrderNotes { get; set; }
    public OrderCancelReason? CancellationReason { get; set; }
    public string? CancellationReasonNote { get; set; }
    public DateTime? CancelledAtUtc { get; set; }
    public string? CancelledByRole { get; set; }

    public List<CustomerOrderLineItem> LineItems { get; set; } = [];
    public List<OrderStatusHistory> StatusHistory { get; set; } = [];
    public List<OrderRefundRequest> RefundRequests { get; set; } = [];
}
