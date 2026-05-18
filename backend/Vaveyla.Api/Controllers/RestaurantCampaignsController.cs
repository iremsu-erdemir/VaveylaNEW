using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Vaveyla.Api.Data;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Controllers;

[ApiController]
[Route("api/restaurant/campaigns")]
[Authorize(Roles = "RestaurantOwner")]
public sealed class RestaurantCampaignsController : ControllerBase
{
    private readonly ICampaignRepository _campaignRepo;
    private readonly IRestaurantOwnerRepository _restaurantRepo;
    private readonly IUserRepository _userRepo;

    public RestaurantCampaignsController(
        ICampaignRepository campaignRepo,
        IRestaurantOwnerRepository restaurantRepo,
        IUserRepository userRepo)
    {
        _campaignRepo = campaignRepo;
        _restaurantRepo = restaurantRepo;
        _userRepo = userRepo;
    }

    [HttpGet]
    public async Task<ActionResult<List<object>>> GetAll(CancellationToken ct)
    {
        var userId = GetCurrentUserId();
        if (!userId.HasValue) return Unauthorized(new { message = "Yetkisiz erişim." });
        var restaurant = await GetRestaurantForOwnerAsync(userId.Value, ct);
        if (restaurant == null)
            return Unauthorized(new { message = "Restoran bulunamadı." });

        var restaurantDiscountStatus = !restaurant.RestaurantDiscountApproved
            ? "Onay bekliyor"
            : restaurant.RestaurantDiscountIsActive ? "Active" : "Pasif";

        var campaigns = await _campaignRepo.GetByRestaurantAsync(restaurant.RestaurantId, ct);
        var hasMatchingCampaign = restaurant.RestaurantDiscountPercent.HasValue && campaigns.Any(c =>
            (int)c.DiscountType == 1 && (int)c.TargetType == 3 && (int)c.DiscountOwner == 1
            && !c.TargetId.HasValue && c.DiscountValue == restaurant.RestaurantDiscountPercent!.Value);

        var result = new List<object>();
        // Restoran indirimi varsa: eşleşen kampanya yoksa "Restoran İndirimi" ekle, varsa kampanyanın status'unu güncelle
        if (restaurant.RestaurantDiscountPercent.HasValue && restaurant.RestaurantDiscountPercent > 0 && !hasMatchingCampaign)
        {
            result.Add(new
            {
                campaignId = Guid.Empty,
                name = "Restoran İndirimi",
                description = (string?)null,
                discountType = 1,
                discountValue = restaurant.RestaurantDiscountPercent,
                targetType = 3,
                targetId = (Guid?)null,
                targetCategoryName = (string?)null,
                minCartAmount = (decimal?)null,
                isActive = restaurant.RestaurantDiscountIsActive,
                status = restaurantDiscountStatus,
                discountOwner = 1,
                restaurantId = restaurant.RestaurantId,
                restaurantName = restaurant.Name,
                startDate = DateTime.UtcNow,
                endDate = DateTime.UtcNow.AddYears(1),
                createdAtUtc = DateTime.UtcNow,
                savedAs = "restaurant_discount",
            });
        }

        // Kampanyalar: restoran indirimi ile eşleşenlerde status backend'den (RestaurantDiscountIsActive) alınır
        foreach (var c in campaigns)
        {
            var dto = ToDto(c, restaurant.Name);
            var isRestaurantDiscountCampaign = (int)c.DiscountType == 1 && (int)c.TargetType == 3
                && (int)c.DiscountOwner == 1 && !c.TargetId.HasValue
                && restaurant.RestaurantDiscountPercent.HasValue
                && c.DiscountValue == restaurant.RestaurantDiscountPercent.Value;
            if (isRestaurantDiscountCampaign)
            {
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
                    isActive = restaurant.RestaurantDiscountIsActive,
                    status = restaurantDiscountStatus,
                    dto.DiscountOwner,
                    dto.RestaurantId,
                    dto.RestaurantName,
                    dto.StartDate,
                    dto.EndDate,
                    dto.CreatedAtUtc,
                    savedAs = "restaurant_discount",
                });
            }
            else
            {
                result.Add(dto);
            }
        }
        return Ok(result);
    }

    [HttpPost]
    public async Task<ActionResult> Create(
        [FromBody] CreateCampaignRequest request,
        CancellationToken ct)
    {
        var userId = GetCurrentUserId();
        if (!userId.HasValue) return Unauthorized(new { message = "Yetkisiz erişim." });
        var restaurant = await GetRestaurantForOwnerAsync(userId.Value, ct);
        if (restaurant == null)
            return Unauthorized(new { message = "Restoran bulunamadı." });

        var campaigns = await _campaignRepo.GetByRestaurantAsync(restaurant.RestaurantId, ct);
        var hasExistingCampaigns = campaigns.Count > 0;
        var hasRestaurantDiscount = restaurant.RestaurantDiscountPercent.HasValue && restaurant.RestaurantDiscountPercent > 0;

        // Basit "tüm ürünlere yüzde indirim" → Restoran indirimi olarak kaydet (Restoran İndirimi Onayı'na düşer)
        var isSimpleRestaurantPercentDiscount = request.DiscountType == (int)CampaignDiscountType.Percentage
            && request.TargetType == (int)CampaignTargetType.Cart
            && request.DiscountOwner == (int)CampaignDiscountOwner.Restaurant
            && !request.TargetId.HasValue
            && request.DiscountValue > 0
            && request.DiscountValue <= 100
            && (!request.MinCartAmount.HasValue || request.MinCartAmount <= 0);

        if (isSimpleRestaurantPercentDiscount)
        {
            if (hasExistingCampaigns)
                return BadRequest(new { message = "Zaten bir kampanyanız var. Aynı anda yalnızca bir indirim kampanyası ekleyebilirsiniz." });

            restaurant.RestaurantDiscountPercent = (decimal)request.DiscountValue;
            restaurant.RestaurantDiscountApproved = false;
            await _restaurantRepo.UpdateRestaurantAsync(restaurant, ct);
            return Ok(new
            {
                savedAs = "restaurant_discount",
                message = "Restoran indirimi kaydedildi. Admin onayından sonra müşterilere yansır.",
                restaurantDiscountPercent = request.DiscountValue
            });
        }

        // Sabit (₺) veya karmaşık kampanya: Mevcut restoran indirimi/kampanyayı temizleyip yenisini oluştur
        if (hasRestaurantDiscount)
        {
            restaurant.RestaurantDiscountPercent = null;
            restaurant.RestaurantDiscountApproved = false;
            restaurant.RestaurantDiscountIsActive = false;
            await _restaurantRepo.UpdateRestaurantAsync(restaurant, ct);
        }
        foreach (var existingCampaign in campaigns)
        {
            existingCampaign.IsActive = false;
            existingCampaign.Status = "Replaced";
            await _campaignRepo.UpdateAsync(existingCampaign, ct);
        }

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
            Status = "Pending",
            DiscountOwner = CampaignDiscountOwner.Restaurant,
            RestaurantId = restaurant.RestaurantId,
            StartDate = request.StartDate.ToUniversalTime(),
            EndDate = request.EndDate.ToUniversalTime(),
            CreatedAtUtc = DateTime.UtcNow,
        };
        await _campaignRepo.CreateAsync(campaign, ct);
        return Ok(ToDto(campaign, restaurant.Name));
    }

    [HttpPut("{id:guid}")]
    public async Task<ActionResult<CampaignDto>> Update(
        [FromRoute] Guid id,
        [FromBody] CreateCampaignRequest request,
        CancellationToken ct)
    {
        var userId = GetCurrentUserId();
        if (!userId.HasValue) return Unauthorized(new { message = "Yetkisiz erişim." });
        var restaurant = await GetRestaurantForOwnerAsync(userId.Value, ct);
        if (restaurant == null)
            return Unauthorized(new { message = "Restoran bulunamadı." });

        var campaign = await _campaignRepo.GetByIdAsync(id, ct);
        if (campaign == null || campaign.RestaurantId != restaurant.RestaurantId)
            return NotFound(new { message = "Kampanya bulunamadı." });

        campaign.Name = request.Name.Trim();
        campaign.Description = request.Description?.Trim();
        campaign.DiscountType = (CampaignDiscountType)request.DiscountType;
        campaign.DiscountValue = request.DiscountValue;
        campaign.TargetType = (CampaignTargetType)request.TargetType;
        campaign.TargetId = request.TargetId;
        campaign.TargetCategoryName = request.TargetCategoryName?.Trim();
        campaign.MinCartAmount = request.MinCartAmount;
        campaign.StartDate = request.StartDate.ToUniversalTime();
        campaign.EndDate = request.EndDate.ToUniversalTime();
        await _campaignRepo.UpdateAsync(campaign, ct);
        return Ok(ToDto(campaign, restaurant.Name));
    }

    [HttpDelete("{id:guid}")]
    public async Task<ActionResult> Delete([FromRoute] Guid id, CancellationToken ct)
    {
        var userId = GetCurrentUserId();
        if (!userId.HasValue) return Unauthorized(new { message = "Yetkisiz erişim." });
        var restaurant = await GetRestaurantForOwnerAsync(userId.Value, ct);
        if (restaurant == null)
            return Unauthorized(new { message = "Restoran bulunamadı." });

        var campaign = await _campaignRepo.GetByIdAsync(id, ct);
        if (campaign == null || campaign.RestaurantId != restaurant.RestaurantId)
            return NotFound(new { message = "Kampanya bulunamadı." });

        await _campaignRepo.DeleteAsync(campaign, ct);
        return NoContent();
    }

    private Guid? GetCurrentUserId()
    {
        var sub = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        return Guid.TryParse(sub, out var id) ? id : null;
    }

    private async Task<Restaurant?> GetRestaurantForOwnerAsync(Guid ownerUserId, CancellationToken ct)
    {
        if (ownerUserId == Guid.Empty) return null;
        var user = await _userRepo.GetByIdAsync(ownerUserId, ct);
        if (user == null || user.Role != UserRole.RestaurantOwner) return null;
        return await _restaurantRepo.GetRestaurantAsync(ownerUserId, ct);
    }

    private static CampaignDto ToDto(Campaign c, string restaurantName) =>
        new(c.CampaignId, c.Name, c.Description, (int)c.DiscountType, c.DiscountValue,
            (int)c.TargetType, c.TargetId, c.TargetCategoryName, c.MinCartAmount, c.IsActive, c.Status,
            (int)c.DiscountOwner, c.RestaurantId, restaurantName, c.StartDate, c.EndDate, c.CreatedAtUtc);
}
