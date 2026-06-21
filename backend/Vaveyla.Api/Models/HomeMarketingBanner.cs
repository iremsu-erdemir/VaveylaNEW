namespace Vaveyla.Api.Models;

/// <summary>Ana sayfa "Özel Teklifler" kaydırıcısı — admin tarafından yönetilir.</summary>
public enum HomeMarketingBannerAction : byte
{
    None = 0,
    Category = 1,
    Restaurant = 2,
    Product = 3,
    ExternalUrl = 4,
    SpecialOffers = 5,
}

public sealed class HomeMarketingBanner
{
    public Guid BannerId { get; set; }
    public string ImageUrl { get; set; } = string.Empty;
    public string? Title { get; set; }
    public string? Subtitle { get; set; }
    public string? BadgeText { get; set; }
    public string? BodyText { get; set; }
    public int SortOrder { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime? StartsAtUtc { get; set; }
    public DateTime? EndsAtUtc { get; set; }
    public HomeMarketingBannerAction ActionType { get; set; }
    public string? ActionTarget { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime UpdatedAtUtc { get; set; }
}
