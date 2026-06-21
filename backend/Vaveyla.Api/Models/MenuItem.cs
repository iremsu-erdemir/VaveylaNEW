namespace Vaveyla.Api.Models;

/// <summary>0 = kilo başına fiyat, 1 = dilim başına fiyat.</summary>
public static class ProductSaleUnit
{
    public const byte PerKilogram = 0;
    public const byte PerSlice = 1;
}

public sealed class MenuItem
{
    public Guid MenuItemId { get; set; }
    public Guid RestaurantId { get; set; }
    public string? CategoryName { get; set; }
    public string Name { get; set; } = string.Empty;
    public int Price { get; set; }
    /// <summary>0 = kg, 1 = dilim (fiyat <see cref="Price"/> birim başına).</summary>
    public byte SaleUnit { get; set; } = ProductSaleUnit.PerKilogram;
    public string ImagePath { get; set; } = string.Empty;
    public bool IsAvailable { get; set; } = true;
    public bool IsFeatured { get; set; } = false;
    public DateTime CreatedAtUtc { get; set; }
}
