namespace Vaveyla.Api.Models;

public sealed class CustomerOrderLineItem
{
    public Guid LineItemId { get; set; }
    public Guid OrderId { get; set; }
    public Guid ProductId { get; set; }
    public string ProductName { get; set; } = string.Empty;
    public string? ImagePath { get; set; }
    public int Quantity { get; set; }
    public decimal WeightKg { get; set; } = 1m;
    public byte SaleUnit { get; set; }
    public decimal UnitPrice { get; set; }
    public decimal LineTotal { get; set; }
    /// <summary>JSON: varyasyon seçimleri (ör. boyut, ekstra).</summary>
    public string? VariationJson { get; set; }

    public CustomerOrder? Order { get; set; }
}
