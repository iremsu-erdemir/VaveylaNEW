namespace Vaveyla.Api.Models;

/// <summary>Kuryenin bir siparişi (havuz veya atanmış) reddetme kaydı; aynı kurye+sipariş tekil.</summary>
public sealed class CourierOrderRefusal
{
    public Guid RefusalId { get; set; }
    public Guid OrderId { get; set; }
    public Guid CourierUserId { get; set; }
    public string Reason { get; set; } = string.Empty;
    public DateTime CreatedAtUtc { get; set; }
}
