using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Data;

namespace Vaveyla.Api.Controllers;

[ApiController]
[Route("api/campaigns")]
public sealed class CampaignsController : ControllerBase
{
    private readonly VaveylaDbContext _db;

    public CampaignsController(VaveylaDbContext db)
    {
        _db = db;
    }

    [HttpGet("active")]
    public async Task<ActionResult<List<object>>> GetActive(
        [FromQuery] Guid? restaurantId,
        CancellationToken ct)
    {
        var now = DateTime.UtcNow;
        var query = _db.Campaigns
            .Where(c =>
                c.IsActive &&
                c.Status == "Active" &&
                c.StartDate <= now &&
                c.EndDate >= now);

        if (restaurantId.HasValue && restaurantId.Value != Guid.Empty)
            query = query.Where(c => c.RestaurantId == null || c.RestaurantId == restaurantId);

        var campaigns = await query
            .OrderByDescending(c => c.DiscountValue)
            .Select(c => new
            {
                c.CampaignId,
                c.Name,
                c.Description,
                discountType = (int)c.DiscountType,
                c.DiscountValue,
                targetType = (int)c.TargetType,
                c.TargetId,
                c.TargetCategoryName,
                c.MinCartAmount,
                c.RestaurantId,
            })
            .ToListAsync(ct);

        return Ok(campaigns);
    }
}
