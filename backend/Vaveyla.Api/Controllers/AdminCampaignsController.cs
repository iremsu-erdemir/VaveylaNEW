using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Vaveyla.Api.Data;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Controllers;

[ApiController]
[Route("api/admin/campaigns")]
[Authorize(Roles = "Admin")]
public sealed class AdminCampaignsController : ControllerBase
{
    private readonly ICampaignRepository _campaignRepo;
    private readonly IRestaurantOwnerRepository _restaurantRepo;

    public AdminCampaignsController(
        ICampaignRepository campaignRepo,
        IRestaurantOwnerRepository restaurantRepo)
    {
        _campaignRepo = campaignRepo;
        _restaurantRepo = restaurantRepo;
    }

    [HttpGet]
    public async Task<ActionResult<List<object>>> GetAll(CancellationToken ct)
    {
        var campaigns = await _campaignRepo.GetAllAsync(ct);
        var restaurantIds = campaigns.Where(c => c.RestaurantId.HasValue).Select(c => c.RestaurantId!.Value).Distinct().ToList();
        var restaurantMap = new Dictionary<Guid, Restaurant>();
        foreach (var rid in restaurantIds)
        {
            var r = await _restaurantRepo.GetRestaurantByIdAsync(rid, ct);
            if (r != null) restaurantMap[rid] = r;
        }

        var result = new List<object>();
        foreach (var c in campaigns)
        {
            var restaurantName = c.RestaurantId.HasValue ? restaurantMap.GetValueOrDefault(c.RestaurantId!.Value)?.Name : null;
            var dto = ToDto(c, restaurantName);
            var status = dto.Status;
            // Restoran indirimi ile eşleşen kampanyalarda status RestaurantDiscountIsActive'den alınır
            if (c.RestaurantId.HasValue && restaurantMap.TryGetValue(c.RestaurantId.Value, out var rest))
            {
                var isRestaurantDiscount = (int)c.DiscountType == 1 && (int)c.TargetType == 3
                    && (int)c.DiscountOwner == 1 && !c.TargetId.HasValue
                    && rest.RestaurantDiscountPercent.HasValue
                    && c.DiscountValue == rest.RestaurantDiscountPercent.Value;
                if (isRestaurantDiscount && rest.RestaurantDiscountApproved)
                {
                    status = rest.RestaurantDiscountIsActive ? "Active" : "Pasif";
                }
            }
            result.Add(new
            {
                dto.CampaignId,
                dto.Name,
                dto.Description,
                dto.DiscountType,
                dto.DiscountValue,
                dto.TargetType,
                dto.TargetId,
                dto.TargetCategoryName,
                dto.MinCartAmount,
                dto.IsActive,
                status,
                dto.DiscountOwner,
                dto.RestaurantId,
                dto.RestaurantName,
                dto.StartDate,
                dto.EndDate,
                dto.CreatedAtUtc,
            });
        }
        return Ok(result);
    }

    [HttpPost]
    public async Task<ActionResult<CampaignDto>> Create(
        [FromBody] CreateCampaignRequest request,
        CancellationToken ct)
    {
        var campaign = new Campaign
        {
            CampaignId = Guid.NewGuid(),
            Name = request.Name.Trim(),
            Description = request.Description?.Trim(),
            DiscountType = (CampaignDiscountType)request.DiscountType,
            DiscountValue = request.DiscountValue,
            TargetType = (CampaignTargetType)request.TargetType,
            TargetId = request.TargetId,
            TargetCategoryName = request.TargetCategoryName?.Trim(),
            MinCartAmount = request.MinCartAmount,
            IsActive = true,
            Status = "Active",
            DiscountOwner = (CampaignDiscountOwner)request.DiscountOwner,
            RestaurantId = null,
            StartDate = request.StartDate.ToUniversalTime(),
            EndDate = request.EndDate.ToUniversalTime(),
            CreatedAtUtc = DateTime.UtcNow,
        };
        await _campaignRepo.CreateAsync(campaign, ct);
        return Ok(ToDto(campaign, null));
    }

    [HttpPut("{id:guid}/approve")]
    public async Task<ActionResult> Approve([FromRoute] Guid id, CancellationToken ct)
    {
        var campaign = await _campaignRepo.GetByIdAsync(id, ct);
        if (campaign == null)
            return NotFound(new { message = "Kampanya bulunamadı." });

        campaign.Status = "Active";
        await _campaignRepo.UpdateAsync(campaign, ct);
        return Ok(new { message = "Kampanya onaylandı." });
    }

    [HttpPut("{id:guid}/reject")]
    public async Task<ActionResult> Reject([FromRoute] Guid id, CancellationToken ct)
    {
        var campaign = await _campaignRepo.GetByIdAsync(id, ct);
        if (campaign == null)
            return NotFound(new { message = "Kampanya bulunamadı." });

        campaign.Status = "Rejected";
        campaign.IsActive = false;
        await _campaignRepo.UpdateAsync(campaign, ct);
        return Ok(new { message = "Kampanya reddedildi." });
    }

    [HttpPut("{id:guid}/deactivate")]
    public async Task<ActionResult> Deactivate([FromRoute] Guid id, CancellationToken ct)
    {
        var campaign = await _campaignRepo.GetByIdAsync(id, ct);
        if (campaign == null)
            return NotFound(new { message = "Kampanya bulunamadı." });

        campaign.IsActive = false;
        await _campaignRepo.UpdateAsync(campaign, ct);
        return Ok(new { message = "Kampanya devre dışı bırakıldı." });
    }

    private static CampaignDto ToDto(Campaign c, string? restaurantName) =>
        new(c.CampaignId, c.Name, c.Description, (int)c.DiscountType, c.DiscountValue,
            (int)c.TargetType, c.TargetId, c.TargetCategoryName, c.MinCartAmount, c.IsActive, c.Status,
            (int)c.DiscountOwner, c.RestaurantId, restaurantName, c.StartDate, c.EndDate, c.CreatedAtUtc);
}
