namespace Vaveyla.Api.Models;

/// <summary>1: Percentage, 2: Fixed</summary>
public enum CampaignDiscountType : int
{
    Percentage = 1,
    Fixed = 2,
}

/// <summary>1: Product, 2: Category, 3: Cart</summary>
public enum CampaignTargetType : int
{
    Product = 1,
    Category = 2,
    Cart = 3,
}

/// <summary>Restaurant or Platform</summary>
public enum CampaignDiscountOwner : int
{
    Restaurant = 1,
    Platform = 2,
}

public sealed class Campaign
{
    public Guid CampaignId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public CampaignDiscountType DiscountType { get; set; }
    public decimal DiscountValue { get; set; }
    public CampaignTargetType TargetType { get; set; }
    public Guid? TargetId { get; set; }
    public string? TargetCategoryName { get; set; }
    public decimal? MinCartAmount { get; set; }
    public bool IsActive { get; set; }
    public string Status { get; set; } = "Pending";
    public CampaignDiscountOwner DiscountOwner { get; set; }
    public Guid? RestaurantId { get; set; }
    public DateTime StartDate { get; set; }
    public DateTime EndDate { get; set; }
    public DateTime CreatedAtUtc { get; set; }
}
