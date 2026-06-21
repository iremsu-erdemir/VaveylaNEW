using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Data;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Controllers;

[ApiController]
[Route("api/special-offers")]
public sealed class SpecialOffersController : ControllerBase
{
    private readonly VaveylaDbContext _db;

    public SpecialOffersController(VaveylaDbContext db)
    {
        _db = db;
    }

    /// <summary>Müşteriye atanmış kuponlar ve onaylı restoran yüzde indirimleri. Sadece adminin atadığı kuponlar gösterilir.</summary>
    [HttpGet]
    public async Task<ActionResult<SpecialOffersResponse>> Get(
        [FromQuery] Guid? customerUserId,
        CancellationToken ct)
    {
        var now = DateTime.UtcNow;
        var couponItems = new List<SpecialOfferItemDto>();

        if (customerUserId.HasValue && customerUserId.Value != Guid.Empty)
        {
            couponItems = await _db.UserCoupons
                .Where(uc =>
                    uc.UserId == customerUserId.Value &&
                    uc.Status == UserCouponStatus.Approved &&
                    uc.Coupon.ExpiresAtUtc >= now &&
                    uc.UsedAtUtc == null)
                .Select(uc => new SpecialOfferItemDto(
                    "coupon",
                    uc.UserCouponId,
                    uc.Coupon.Code,
                    uc.Coupon.Description,
                    (int)uc.Coupon.DiscountType,
                    uc.Coupon.DiscountValue,
                    uc.Coupon.MinCartAmount,
                    uc.Coupon.MaxDiscountAmount,
                    null,
                    null))
                .ToListAsync(ct);
        }

        var restaurantDiscountsRaw = await _db.Restaurants
            .Where(r =>
                r.RestaurantDiscountPercent.HasValue &&
                r.RestaurantDiscountPercent > 0 &&
                r.RestaurantDiscountApproved &&
                r.RestaurantDiscountIsActive &&
                r.IsEnabled &&
                !_db.Users.Any(u =>
                    u.UserId == r.OwnerUserId &&
                    (u.IsPermanentlyBanned ||
                     (u.SuspendedUntilUtc != null && u.SuspendedUntilUtc > DateTime.UtcNow))))
            .Select(r => new { r.RestaurantDiscountPercent })
            .ToListAsync(ct);

        var uniquePercents = restaurantDiscountsRaw
            .Where(x => x.RestaurantDiscountPercent.HasValue)
            .Select(x => x.RestaurantDiscountPercent!.Value)
            .Distinct()
            .OrderByDescending(p => p)
            .Select(p => new SpecialOfferItemDto(
                "restaurant_discount",
                Guid.Empty,
                $"%{p} İndirim",
                $"{p}% indirimli pastaneler",
                1,
                p,
                null,
                null,
                null,
                null))
            .ToList();

        var items = couponItems.Concat(uniquePercents).ToList();
        return Ok(new SpecialOffersResponse(items));
    }

    /// <summary>Belirli yüzde indirime sahip restoranlar. Yüzde indirime tıklandığında.</summary>
    [HttpGet("restaurants-with-discount")]
    public async Task<ActionResult<List<RestaurantWithDiscountDto>>> GetRestaurantsWithDiscount(
        [FromQuery] decimal discountPercent,
        CancellationToken ct)
    {
        var restaurants = await _db.Restaurants
            .Where(r =>
                r.RestaurantDiscountPercent == discountPercent &&
                r.RestaurantDiscountApproved &&
                r.RestaurantDiscountIsActive &&
                r.IsEnabled &&
                r.IsOpen &&
                !_db.Users.Any(u =>
                    u.UserId == r.OwnerUserId &&
                    (u.IsPermanentlyBanned ||
                     (u.SuspendedUntilUtc != null && u.SuspendedUntilUtc > DateTime.UtcNow))))
            .Select(r => new RestaurantWithDiscountDto(
                r.RestaurantId,
                r.Name,
                r.Type,
                r.PhotoPath,
                r.RestaurantDiscountPercent!.Value,
                r.Address))
            .ToListAsync(ct);

        return Ok(restaurants);
    }
}

public sealed record SpecialOffersResponse(
    List<SpecialOfferItemDto> Items);

public sealed record SpecialOfferItemDto(
    string Type,
    Guid Id,
    string Title,
    string? Description,
    int DiscountType,
    decimal DiscountValue,
    decimal? MinCartAmount,
    decimal? MaxDiscountAmount,
    Guid? RestaurantId,
    string? RestaurantName);

public sealed record RestaurantWithDiscountDto(
    Guid RestaurantId,
    string Name,
    string Type,
    string? PhotoPath,
    decimal DiscountPercent,
    string Address);
