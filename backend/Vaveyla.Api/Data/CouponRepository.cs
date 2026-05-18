using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Data;

public sealed class CouponRepository : ICouponRepository
{
    private readonly VaveylaDbContext _db;

    public CouponRepository(VaveylaDbContext db)
    {
        _db = db;
    }

    public async Task<Coupon?> GetByCodeAsync(string code, CancellationToken ct = default)
    {
        var normalized = code?.Trim().ToUpperInvariant() ?? string.Empty;
        if (string.IsNullOrEmpty(normalized)) return null;
        return await _db.Coupons
            .FirstOrDefaultAsync(c => c.Code == normalized, ct);
    }

    public async Task<Coupon?> GetByIdAsync(Guid couponId, CancellationToken ct = default) =>
        await _db.Coupons.FindAsync([couponId], ct);

    public async Task<UserCoupon?> GetUserCouponAsync(Guid userCouponId, CancellationToken ct = default) =>
        await _db.UserCoupons
            .Include(uc => uc.Coupon)
            .FirstOrDefaultAsync(uc => uc.UserCouponId == userCouponId, ct);

    /// <summary>UserId+CouponId için en son atanan kaydı döner. Birden fazla instance olabilir (admin tekrar atayabilir).</summary>
    public async Task<UserCoupon?> GetUserCouponAsync(Guid userId, Guid couponId, CancellationToken ct = default) =>
        await _db.UserCoupons
            .Include(uc => uc.Coupon)
            .Where(uc => uc.UserId == userId && uc.CouponId == couponId)
            .OrderByDescending(uc => uc.CreatedAtUtc)
            .FirstOrDefaultAsync(ct);

    public async Task<bool> HasActiveUserCouponAsync(Guid userId, Guid couponId, CancellationToken ct = default) =>
        await _db.UserCoupons
            .AnyAsync(uc => uc.UserId == userId && uc.CouponId == couponId &&
                (uc.Status == UserCouponStatus.Approved || uc.Status == UserCouponStatus.Pending), ct);

    public async Task<List<UserCoupon>> GetUserCouponsAsync(Guid userId, CancellationToken ct = default) =>
        await _db.UserCoupons
            .Include(uc => uc.Coupon)
            .Where(uc => uc.UserId == userId)
            .OrderByDescending(uc => uc.CreatedAtUtc)
            .ToListAsync(ct);

    public async Task<List<UserCoupon>> GetPendingUserCouponsAsync(CancellationToken ct = default) =>
        await _db.UserCoupons
            .Include(uc => uc.Coupon)
            .Where(uc => uc.Status == UserCouponStatus.Pending)
            .OrderBy(uc => uc.CreatedAtUtc)
            .ToListAsync(ct);

    public async Task<UserCoupon> CreateUserCouponAsync(UserCoupon userCoupon, CancellationToken ct = default)
    {
        _db.UserCoupons.Add(userCoupon);
        await _db.SaveChangesAsync(ct);
        return userCoupon;
    }

    public async Task UpdateUserCouponAsync(UserCoupon userCoupon, CancellationToken ct = default)
    {
        _db.UserCoupons.Update(userCoupon);
        await _db.SaveChangesAsync(ct);
    }

    public async Task<Coupon> CreateCouponAsync(Coupon coupon, CancellationToken ct = default)
    {
        _db.Coupons.Add(coupon);
        await _db.SaveChangesAsync(ct);
        return coupon;
    }

    public async Task ExpireOtherActiveUserCouponsAsync(
        Guid userId,
        Guid couponId,
        Guid? exceptUserCouponId,
        CancellationToken ct = default)
    {
        var query = _db.UserCoupons.Where(uc =>
            uc.UserId == userId &&
            uc.CouponId == couponId &&
            (uc.Status == UserCouponStatus.Approved || uc.Status == UserCouponStatus.Pending));
        if (exceptUserCouponId.HasValue)
            query = query.Where(uc => uc.UserCouponId != exceptUserCouponId.Value);

        var list = await query.ToListAsync(ct);
        foreach (var uc in list)
            uc.Status = UserCouponStatus.Expired;

        if (list.Count > 0)
            await _db.SaveChangesAsync(ct);
    }
}
