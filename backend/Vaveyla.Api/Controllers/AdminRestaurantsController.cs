using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Data;

namespace Vaveyla.Api.Controllers;

[ApiController]
[Route("api/admin/restaurants")]
[Authorize(Roles = "Admin")]
public sealed class AdminRestaurantsController : ControllerBase
{
    private readonly VaveylaDbContext _db;

    public AdminRestaurantsController(VaveylaDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<ActionResult<List<object>>> GetAll(CancellationToken ct)
    {
        var restaurants = await _db.Restaurants
            .OrderBy(r => r.Name)
            .Select(r => new
            {
                r.RestaurantId,
                r.Name,
                r.Type,
                r.Address,
                r.Phone,
                r.IsOpen,
                r.IsEnabled,
                r.CommissionRate,
            })
            .ToListAsync(ct);

        return Ok(restaurants);
    }

    [HttpPut("{id:guid}/toggle-status")]
    public async Task<ActionResult> ToggleStatus([FromRoute] Guid id, CancellationToken ct)
    {
        var restaurant = await _db.Restaurants.FirstOrDefaultAsync(r => r.RestaurantId == id, ct);
        if (restaurant == null)
            return NotFound(new { message = "Restoran bulunamadı." });

        restaurant.IsEnabled = !restaurant.IsEnabled;
        await _db.SaveChangesAsync(ct);
        return Ok(new { message = $"Restoran {(restaurant.IsEnabled ? "aktif" : "pasif")}." });
    }

    [HttpPut("{id:guid}/set-commission")]
    public async Task<ActionResult> SetCommission(
        [FromRoute] Guid id,
        [FromBody] SetCommissionRequest request,
        CancellationToken ct)
    {
        var restaurant = await _db.Restaurants.FirstOrDefaultAsync(r => r.RestaurantId == id, ct);
        if (restaurant == null)
            return NotFound(new { message = "Restoran bulunamadı." });

        if (!request.CommissionRate.HasValue || request.CommissionRate is < 0 or > 1)
            return BadRequest(new { message = "Komisyon oranı 0-1 arasında olmalıdır." });

        restaurant.CommissionRate = request.CommissionRate.Value;
        await _db.SaveChangesAsync(ct);
        return Ok(new { message = "Komisyon oranı güncellendi.", commissionRate = restaurant.CommissionRate });
    }

    /// <summary>Onaylı restoran indirimlerini listele (düzenleme için).</summary>
    [HttpGet("approved-discounts")]
    public async Task<ActionResult<List<object>>> GetApprovedDiscounts(CancellationToken ct)
    {
        var restaurants = await _db.Restaurants
            .Where(r =>
                r.RestaurantDiscountPercent.HasValue &&
                r.RestaurantDiscountPercent > 0 &&
                r.RestaurantDiscountApproved)
            .Select(r => new
            {
                r.RestaurantId,
                r.Name,
                r.RestaurantDiscountPercent,
                r.RestaurantDiscountIsActive,
            })
            .ToListAsync(ct);
        return Ok(restaurants);
    }

    /// <summary>Onay bekleyen restoran indirimlerini listele.</summary>
    [HttpGet("pending-discounts")]
    public async Task<ActionResult<List<object>>> GetPendingDiscounts(CancellationToken ct)
    {
        var restaurants = await _db.Restaurants
            .Where(r =>
                r.RestaurantDiscountPercent.HasValue &&
                r.RestaurantDiscountPercent > 0 &&
                !r.RestaurantDiscountApproved)
            .Select(r => new
            {
                r.RestaurantId,
                r.Name,
                r.RestaurantDiscountPercent,
            })
            .ToListAsync(ct);
        return Ok(restaurants);
    }

    /// <summary>Restoran indirimini onayla. Opsiyonel: Body'de restaurantDiscountPercent gönderilirse o değer kullanılır (yanlış kaydedilen değeri düzeltmek için).</summary>
    [HttpPost("{id:guid}/approve-discount")]
    public async Task<ActionResult> ApproveDiscount([FromRoute] Guid id, [FromBody] ApproveDiscountRequest? body, CancellationToken ct)
    {
        var restaurant = await _db.Restaurants.FirstOrDefaultAsync(r => r.RestaurantId == id, ct);
        if (restaurant == null)
            return NotFound(new { message = "Restoran bulunamadı." });

        if (!restaurant.RestaurantDiscountPercent.HasValue || restaurant.RestaurantDiscountPercent <= 0)
            return BadRequest(new { message = "Restoranda tanımlı indirim yok." });

        if (restaurant.RestaurantDiscountApproved)
            return BadRequest(new { message = "İndirim zaten onaylı." });

        // Admin yanlış kaydedilen değeri düzeltebilir (örn. 10 yerine 25)
        if (body?.RestaurantDiscountPercent is { } pct && pct > 0 && pct <= 100)
        {
            restaurant.RestaurantDiscountPercent = pct;
        }

        restaurant.RestaurantDiscountApproved = true;
        restaurant.RestaurantDiscountIsActive = true; // Onay sonrası aktif başlar
        await _db.SaveChangesAsync(ct);
        return Ok(new { message = "Restoran indirimi onaylandı.", restaurantDiscountPercent = restaurant.RestaurantDiscountPercent });
    }

    /// <summary>Restoran indirim yüzdesini güncelle (onaylı veya onay bekleyen). Yanlış kaydedilen değeri düzeltmek için.</summary>
    [HttpPut("{id:guid}/discount")]
    public async Task<ActionResult> UpdateDiscount(
        [FromRoute] Guid id,
        [FromBody] UpdateRestaurantDiscountRequest request,
        CancellationToken ct)
    {
        var restaurant = await _db.Restaurants.FirstOrDefaultAsync(r => r.RestaurantId == id, ct);
        if (restaurant == null)
            return NotFound(new { message = "Restoran bulunamadı." });

        if (!request.RestaurantDiscountPercent.HasValue || request.RestaurantDiscountPercent is <= 0 or > 100)
            return BadRequest(new { message = "İndirim oranı 1-100 arasında olmalıdır." });

        restaurant.RestaurantDiscountPercent = request.RestaurantDiscountPercent.Value;
        await _db.SaveChangesAsync(ct);
        return Ok(new { message = "İndirim oranı güncellendi.", restaurantDiscountPercent = restaurant.RestaurantDiscountPercent });
    }

    /// <summary>Restoran indirimini reddet ve sil.</summary>
    [HttpPost("{id:guid}/reject-discount")]
    public async Task<ActionResult> RejectDiscount([FromRoute] Guid id, CancellationToken ct)
    {
        var restaurant = await _db.Restaurants.FirstOrDefaultAsync(r => r.RestaurantId == id, ct);
        if (restaurant == null)
            return NotFound(new { message = "Restoran bulunamadı." });

        if (!restaurant.RestaurantDiscountPercent.HasValue || restaurant.RestaurantDiscountPercent <= 0)
            return BadRequest(new { message = "Restoranda tanımlı indirim yok." });

        if (restaurant.RestaurantDiscountApproved)
            return BadRequest(new { message = "Onaylı indirim reddedilemez." });

        restaurant.RestaurantDiscountPercent = null;
        restaurant.RestaurantDiscountApproved = false;
        await _db.SaveChangesAsync(ct);
        return Ok(new { message = "Restoran indirimi reddedildi ve kaldırıldı." });
    }
}

public sealed record SetCommissionRequest(decimal? CommissionRate);

/// <summary>Onay sırasında indirim yüzdesini düzeltmek için (opsiyonel).</summary>
public sealed record ApproveDiscountRequest(decimal? RestaurantDiscountPercent);

/// <summary>Restoran indirim yüzdesini güncellemek için.</summary>
public sealed record UpdateRestaurantDiscountRequest(decimal? RestaurantDiscountPercent);
