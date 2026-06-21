using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Data;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Controllers;

/// <summary>Müşteri ana sayfası — kimlik doğrulama gerekmez.</summary>
[ApiController]
[Route("api/home/marketing-banners")]
public sealed class HomeMarketingBannersController : ControllerBase
{
    private readonly VaveylaDbContext _db;

    public HomeMarketingBannersController(VaveylaDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<ActionResult<List<HomeMarketingBannerPublicDto>>> GetActive(
        CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var rows = await _db.HomeMarketingBanners.AsNoTracking()
            .Where(x =>
                x.IsActive &&
                (x.StartsAtUtc == null || x.StartsAtUtc <= now) &&
                (x.EndsAtUtc == null || x.EndsAtUtc >= now))
            .OrderBy(x => x.SortOrder)
            .ThenBy(x => x.CreatedAtUtc)
            .Select(x => new HomeMarketingBannerPublicDto(
                x.BannerId,
                x.ImageUrl,
                x.Title,
                x.Subtitle,
                x.BadgeText,
                x.BodyText,
                x.SortOrder,
                MarketingBannerActionMapper.ToApiString(x.ActionType),
                x.ActionTarget))
            .ToListAsync(cancellationToken);

        return Ok(rows);
    }
}

public sealed record HomeMarketingBannerPublicDto(
    Guid Id,
    string ImageUrl,
    string? Title,
    string? Subtitle,
    string? BadgeText,
    string? BodyText,
    int SortOrder,
    string ActionType,
    string? ActionTarget);
