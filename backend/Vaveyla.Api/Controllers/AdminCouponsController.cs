using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Data;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Controllers;

[ApiController]
[Route("api/admin/coupons")]
[Authorize(Roles = "Admin")]
public sealed class AdminCouponsController : ControllerBase
{
    private readonly ICouponRepository _couponRepo;
    private readonly VaveylaDbContext _db;

    public AdminCouponsController(ICouponRepository couponRepo, VaveylaDbContext db)
    {
        _couponRepo = couponRepo;
        _db = db;
    }

    /// <summary>Onay bekleyen kuponları listele.</summary>
    [HttpGet("pending")]
    public async Task<ActionResult<List<object>>> GetPending(CancellationToken ct)
    {
        var pending = await _couponRepo.GetPendingUserCouponsAsync(ct);
        var userIds = pending.Select(x => x.UserId).Distinct().ToList();
        var users = await _db.Users
            .Where(u => userIds.Contains(u.UserId))
            .ToDictionaryAsync(u => u.UserId, u => u.Email ?? "", ct);

        var result = pending.Select(uc => new
        {
            userCouponId = uc.UserCouponId,
            userId = uc.UserId,
            code = uc.Coupon.Code,
            userEmail = users.GetValueOrDefault(uc.UserId),
            createdAtUtc = uc.CreatedAtUtc,
        }).ToList();

        return Ok(result);
    }

    /// <summary>Kuponu onayla.</summary>
    [HttpPost("{id:guid}/approve")]
    public async Task<ActionResult> Approve([FromRoute] Guid id, CancellationToken ct)
    {
        var userCoupon = await _couponRepo.GetUserCouponAsync(id, ct);
        if (userCoupon == null)
            return NotFound(new { message = "Kupon bulunamadı." });

        if (userCoupon.Status != UserCouponStatus.Pending)
            return BadRequest(new { message = "Bu kupon zaten onaylanmış veya kullanılmış." });

        if (userCoupon.Coupon.ExpiresAtUtc < DateTime.UtcNow)
        {
            userCoupon.Status = UserCouponStatus.Expired;
            await _couponRepo.UpdateUserCouponAsync(userCoupon, ct);
            return BadRequest(new { message = "Kuponun süresi dolmuş, onaylanamaz." });
        }

        await _couponRepo.ExpireOtherActiveUserCouponsAsync(
            userCoupon.UserId,
            userCoupon.CouponId,
            userCoupon.UserCouponId,
            ct);

        userCoupon.Status = UserCouponStatus.Approved;
        await _couponRepo.UpdateUserCouponAsync(userCoupon, ct);
        return Ok(new { message = "Kupon onaylandı." });
    }

    /// <summary>Yeni kupon oluştur (admin).</summary>
    [HttpPost]
    public async Task<ActionResult<object>> CreateCoupon(
        [FromBody] CreateCouponRequest request,
        CancellationToken ct)
    {
        var code = request.Code?.Trim().ToUpperInvariant() ?? "";
        if (string.IsNullOrEmpty(code))
            return BadRequest(new { message = "Kupon kodu gerekli." });

        var existing = await _couponRepo.GetByCodeAsync(code, ct);
        if (existing != null)
            return BadRequest(new { message = "Bu kupon kodu zaten mevcut." });

        var coupon = new Coupon
        {
            CouponId = Guid.NewGuid(),
            Code = code,
            Description = request.Description?.Trim(),
            DiscountType = (CouponDiscountType)request.DiscountType,
            DiscountValue = request.DiscountValue,
            MinCartAmount = request.MinCartAmount,
            MaxDiscountAmount = request.MaxDiscountAmount,
            ExpiresAtUtc = request.ExpiresAtUtc.ToUniversalTime(),
            RestaurantId = request.RestaurantId,
            CreatedAtUtc = DateTime.UtcNow,
        };

        await _couponRepo.CreateCouponAsync(coupon, ct);
        return Ok(new
        {
            couponId = coupon.CouponId,
            code = coupon.Code,
            message = "Kupon oluşturuldu.",
        });
    }

    /// <summary>Atanmış kuponları listele (müşteri, kupon, durum - Kullanıldı etiketi için).</summary>
    [HttpGet("assignments")]
    public async Task<ActionResult<List<object>>> GetCouponAssignments(CancellationToken ct)
    {
        var list = await _db.UserCoupons
            .Include(uc => uc.Coupon)
            .Include(uc => uc.User)
            .OrderByDescending(uc => uc.CreatedAtUtc)
            .ToListAsync(ct);

        var assignments = list.Select(uc => new
        {
            userCouponId = uc.UserCouponId,
            userId = uc.UserId,
            userEmail = uc.User?.Email ?? "",
            userFullName = uc.User?.FullName ?? "",
            couponId = uc.CouponId,
            code = uc.Coupon?.Code ?? "",
            discountType = (int)(uc.Coupon?.DiscountType ?? CouponDiscountType.Percentage),
            discountValue = uc.Coupon?.DiscountValue ?? 0,
            expiresAtUtc = uc.Coupon?.ExpiresAtUtc,
            status = MapStatus(uc.Status),
            isUsed = uc.Status == UserCouponStatus.Used,
            usedAtUtc = uc.UsedAtUtc,
            orderId = uc.OrderId,
            createdAtUtc = uc.CreatedAtUtc,
        }).ToList();

        return Ok(assignments);
    }

    private static string MapStatus(UserCouponStatus s)
    {
        return s switch
        {
            UserCouponStatus.Pending => "pending",
            UserCouponStatus.Approved => "approved",
            UserCouponStatus.Used => "used",
            UserCouponStatus.Expired => "expired",
            _ => "unknown",
        };
    }

    /// <summary>Tüm kuponları listele (atama için).</summary>
    [HttpGet]
    public async Task<ActionResult<List<object>>> GetAllCoupons(CancellationToken ct)
    {
        var now = DateTime.UtcNow;
        var coupons = await _db.Coupons
            .Where(c => c.ExpiresAtUtc >= now)
            .OrderBy(c => c.Code)
            .Select(c => new { c.CouponId, c.Code, c.Description, c.DiscountType, c.DiscountValue, c.MinCartAmount, c.MaxDiscountAmount, c.ExpiresAtUtc })
            .ToListAsync(ct);
        return Ok(coupons);
    }

    /// <summary>Müşteri listesi (kupon atarken seçim için).</summary>
    [HttpGet("customers")]
    public async Task<ActionResult<List<object>>> GetCustomers(CancellationToken ct)
    {
        var customers = await _db.Users
            .Where(u => u.Role == UserRole.Customer)
            .OrderBy(u => u.FullName)
            .Select(u => new { u.UserId, u.FullName, u.Email })
            .ToListAsync(ct);
        return Ok(customers);
    }

    /// <summary>Admin, belirli bir müşteriye kupon atar (onaylı olarak).</summary>
    [HttpPost("assign-to-customer")]
    public async Task<ActionResult<object>> AssignToCustomer(
        [FromBody] AssignCouponToCustomerRequest request,
        CancellationToken ct)
    {
        var coupon = await _couponRepo.GetByIdAsync(request.CouponId, ct);
        if (coupon == null)
            return NotFound(new { message = "Kupon bulunamadı." });

        if (coupon.ExpiresAtUtc < DateTime.UtcNow)
            return BadRequest(new { message = "Kuponun süresi dolmuş." });

        var user = await _db.Users.FindAsync([request.CustomerUserId], ct);
        if (user == null)
            return NotFound(new { message = "Müşteri bulunamadı." });

        // Önceki aktif/pending atamaları pasifleştir; yalnızca bu yeni atama kullanılabilir olsun.
        await _couponRepo.ExpireOtherActiveUserCouponsAsync(
            request.CustomerUserId,
            request.CouponId,
            null,
            ct);

        // Her atama yeni bir UserCoupon kaydı oluşturur; önceki aktif/pending atamalar yukarıda pasifleştirildi.
        var userCoupon = new UserCoupon
        {
            UserCouponId = Guid.NewGuid(),
            UserId = request.CustomerUserId,
            CouponId = request.CouponId,
            Status = UserCouponStatus.Approved,
            CreatedAtUtc = DateTime.UtcNow,
        };
        await _couponRepo.CreateUserCouponAsync(userCoupon, ct);
        return Ok(new
        {
            userCouponId = userCoupon.UserCouponId,
            message = $"Kupon {user.FullName} kullanıcısına atandı.",
        });
    }
}

public sealed record AssignCouponToCustomerRequest(Guid CouponId, Guid CustomerUserId);

public sealed record CreateCouponRequest(
    string Code,
    string? Description,
    int DiscountType,
    decimal DiscountValue,
    decimal? MinCartAmount,
    decimal? MaxDiscountAmount,
    DateTime ExpiresAtUtc,
    Guid? RestaurantId);
