using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Data;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Controllers;

[ApiController]
[Route("api/admin/marketing-banners")]
[Authorize(Roles = "Admin")]
public sealed class AdminMarketingBannersController : ControllerBase
{
    private readonly VaveylaDbContext _db;

    public AdminMarketingBannersController(VaveylaDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<ActionResult<List<HomeMarketingBannerAdminDto>>> GetAll(
        CancellationToken cancellationToken)
    {
        var rows = await _db.HomeMarketingBanners.AsNoTracking()
            .OrderBy(x => x.SortOrder)
            .ThenByDescending(x => x.UpdatedAtUtc)
            .Select(x => new HomeMarketingBannerAdminDto(
                x.BannerId,
                x.ImageUrl,
                x.Title,
                x.Subtitle,
                x.BadgeText,
                x.BodyText,
                x.SortOrder,
                x.IsActive,
                x.StartsAtUtc,
                x.EndsAtUtc,
                MarketingBannerActionMapper.ToApiString(x.ActionType),
                x.ActionTarget,
                x.CreatedAtUtc,
                x.UpdatedAtUtc))
            .ToListAsync(cancellationToken);

        return Ok(rows);
    }

    [HttpPost]
    public async Task<ActionResult<HomeMarketingBannerAdminDto>> Create(
        [FromBody] UpsertMarketingBannerRequest body,
        CancellationToken cancellationToken)
    {
        var err = Validate(body, isCreate: true);
        if (err is not null)
        {
            return BadRequest(new { message = err });
        }

        var now = DateTime.UtcNow;
        var entity = new HomeMarketingBanner
        {
            BannerId = Guid.NewGuid(),
            ImageUrl = body.ImageUrl!.Trim(),
            Title = NullIfEmpty(body.Title),
            Subtitle = NullIfEmpty(body.Subtitle),
            BadgeText = NullIfEmpty(body.BadgeText),
            BodyText = NullIfEmpty(body.BodyText),
            SortOrder = body.SortOrder,
            IsActive = body.IsActive,
            StartsAtUtc = body.StartsAtUtc,
            EndsAtUtc = body.EndsAtUtc,
            ActionType = MarketingBannerActionMapper.Parse(body.ActionType),
            ActionTarget = NullIfEmpty(body.ActionTarget),
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        };

        _db.HomeMarketingBanners.Add(entity);
        await _db.SaveChangesAsync(cancellationToken);

        return Ok(MapAdminDto(entity));
    }

    [HttpPut("{bannerId:guid}")]
    public async Task<ActionResult<HomeMarketingBannerAdminDto>> Update(
        [FromRoute] Guid bannerId,
        [FromBody] UpsertMarketingBannerRequest body,
        CancellationToken cancellationToken)
    {
        var err = Validate(body, isCreate: false);
        if (err is not null)
        {
            return BadRequest(new { message = err });
        }

        var entity = await _db.HomeMarketingBanners.FirstOrDefaultAsync(
            x => x.BannerId == bannerId,
            cancellationToken);
        if (entity is null)
        {
            return NotFound(new { message = "Banner bulunamadı." });
        }

        entity.ImageUrl = body.ImageUrl!.Trim();
        entity.Title = NullIfEmpty(body.Title);
        entity.Subtitle = NullIfEmpty(body.Subtitle);
        entity.BadgeText = NullIfEmpty(body.BadgeText);
        entity.BodyText = NullIfEmpty(body.BodyText);
        entity.SortOrder = body.SortOrder;
        entity.IsActive = body.IsActive;
        entity.StartsAtUtc = body.StartsAtUtc;
        entity.EndsAtUtc = body.EndsAtUtc;
        entity.ActionType = MarketingBannerActionMapper.Parse(body.ActionType);
        entity.ActionTarget = NullIfEmpty(body.ActionTarget);
        entity.UpdatedAtUtc = DateTime.UtcNow;

        await _db.SaveChangesAsync(cancellationToken);

        return Ok(MapAdminDto(entity));
    }

    [HttpDelete("{bannerId:guid}")]
    public async Task<ActionResult> Delete(
        [FromRoute] Guid bannerId,
        CancellationToken cancellationToken)
    {
        var entity = await _db.HomeMarketingBanners.FirstOrDefaultAsync(
            x => x.BannerId == bannerId,
            cancellationToken);
        if (entity is null)
        {
            return NotFound(new { message = "Banner bulunamadı." });
        }

        _db.HomeMarketingBanners.Remove(entity);
        await _db.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    private static HomeMarketingBannerAdminDto MapAdminDto(HomeMarketingBanner x) =>
        new(
            x.BannerId,
            x.ImageUrl,
            x.Title,
            x.Subtitle,
            x.BadgeText,
            x.BodyText,
            x.SortOrder,
            x.IsActive,
            x.StartsAtUtc,
            x.EndsAtUtc,
            MarketingBannerActionMapper.ToApiString(x.ActionType),
            x.ActionTarget,
            x.CreatedAtUtc,
            x.UpdatedAtUtc);

    private static string? Validate(UpsertMarketingBannerRequest body, bool isCreate)
    {
        var url = body.ImageUrl?.Trim() ?? string.Empty;
        if (url.Length == 0)
        {
            return "Görsel URL zorunludur.";
        }

        if (url.Length > 2048)
        {
            return "Görsel URL en fazla 2048 karakter olabilir.";
        }

        if (body.ActionTarget is { Length: > 2048 })
        {
            return "Hedef (actionTarget) en fazla 2048 karakter olabilir.";
        }

        if (body.StartsAtUtc.HasValue && body.EndsAtUtc.HasValue &&
            body.EndsAtUtc < body.StartsAtUtc)
        {
            return "Bitiş tarihi başlangıçtan önce olamaz.";
        }

        _ = isCreate;
        return null;
    }

    private static string? NullIfEmpty(string? s)
    {
        if (string.IsNullOrWhiteSpace(s))
        {
            return null;
        }

        return s.Trim();
    }
}

public sealed record HomeMarketingBannerAdminDto(
    Guid Id,
    string ImageUrl,
    string? Title,
    string? Subtitle,
    string? BadgeText,
    string? BodyText,
    int SortOrder,
    bool IsActive,
    DateTime? StartsAtUtc,
    DateTime? EndsAtUtc,
    string ActionType,
    string? ActionTarget,
    DateTime CreatedAtUtc,
    DateTime UpdatedAtUtc);

public sealed class UpsertMarketingBannerRequest
{
    public string? ImageUrl { get; set; }
    public string? Title { get; set; }
    public string? Subtitle { get; set; }
    public string? BadgeText { get; set; }
    public string? BodyText { get; set; }
    public int SortOrder { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime? StartsAtUtc { get; set; }
    public DateTime? EndsAtUtc { get; set; }
    public string? ActionType { get; set; }
    public string? ActionTarget { get; set; }
}

internal static class MarketingBannerActionMapper
{
    public static string ToApiString(HomeMarketingBannerAction a) => a switch
    {
        HomeMarketingBannerAction.None => "none",
        HomeMarketingBannerAction.Category => "category",
        HomeMarketingBannerAction.Restaurant => "restaurant",
        HomeMarketingBannerAction.Product => "product",
        HomeMarketingBannerAction.ExternalUrl => "externalUrl",
        HomeMarketingBannerAction.SpecialOffers => "specialOffers",
        _ => "none",
    };

    public static HomeMarketingBannerAction Parse(string? s)
    {
        if (string.IsNullOrWhiteSpace(s))
        {
            return HomeMarketingBannerAction.None;
        }

        var t = s.Trim().ToLowerInvariant().Replace("_", string.Empty);
        return t switch
        {
            "none" => HomeMarketingBannerAction.None,
            "category" => HomeMarketingBannerAction.Category,
            "restaurant" => HomeMarketingBannerAction.Restaurant,
            "product" => HomeMarketingBannerAction.Product,
            "externalurl" or "url" => HomeMarketingBannerAction.ExternalUrl,
            "specialoffers" => HomeMarketingBannerAction.SpecialOffers,
            _ => Enum.TryParse<HomeMarketingBannerAction>(s, true, out var parsed)
                ? parsed
                : HomeMarketingBannerAction.None,
        };
    }
}
