using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Data;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Services;

public sealed class CartCalculationService : ICartCalculationService
{
    /// <summary>
    /// Kilo: birim fiyat × kg × adet. Dilim: birim fiyat × dilim adedi (kg yok sayılır).
    /// </summary>
    private static decimal ComputeLineOriginalPrice(CalculateCartItemRequest reqItem)
    {
        if (reqItem.Quantity <= 0) return 0;
        var unit = (decimal)reqItem.UnitPrice;
        if (reqItem.SaleUnit == ProductSaleUnit.PerSlice)
            return unit * reqItem.Quantity;
        var w = reqItem.WeightKg <= 0 ? 1m : reqItem.WeightKg;
        return unit * w * reqItem.Quantity;
    }

    private const decimal DefaultCommissionRate = 0.10m;
    private readonly VaveylaDbContext _db;
    private readonly ICouponService _couponService;
    private readonly IUserSuspensionService _suspension;

    public CartCalculationService(
        VaveylaDbContext db,
        ICouponService couponService,
        IUserSuspensionService suspension)
    {
        _db = db;
        _couponService = couponService;
        _suspension = suspension;
    }

    /// <summary>
    /// Sepet indirim kuralları (Kritik - müşteri tercihi):
    /// 1. Sepette ASLA iki indirim aynı anda uygulanamaz.
    /// 2. Müşteri kupon seçerse: Sadece kupon uygulanır, restoran indirimi görülmez.
    /// 3. Müşteri kupon seçmezse ve restoran indirimi varsa: Sadece restoran indirimi, kupon seçilemez (CanUseCoupon=false).
    /// 4. Özet: Müşteri kupon isterse kupon kazanır; restoran indirimi kullanıyorsa kupon eklenemez.
    /// </summary>
    public async Task<CalculateCartResponse> CalculateCartAsync(CalculateCartRequest request, CancellationToken ct = default)
    {
        if (request.Items == null || request.Items.Count == 0)
        {
            return EmptyResponse();
        }

        await EnsurePartiesAllowedForCheckoutAsync(request, ct);

        var productIds = request.Items.Select(x => x.ProductId).Distinct().ToList();
        var menuItems = await _db.MenuItems
            .Where(m => m.RestaurantId == request.RestaurantId && productIds.Contains(m.MenuItemId))
            .ToDictionaryAsync(m => m.MenuItemId, ct);

        var restaurantData = await _db.Restaurants
            .AsNoTracking()
            .Where(r => r.RestaurantId == request.RestaurantId)
            .Select(r => new
            {
                r.CommissionRate,
                r.RestaurantDiscountPercent,
                r.RestaurantDiscountApproved,
                r.RestaurantDiscountIsActive
            })
            .FirstOrDefaultAsync(ct);
        var commissionRate = restaurantData?.CommissionRate ?? DefaultCommissionRate;
        var restaurantDiscountPercent = restaurantData?.RestaurantDiscountPercent ?? 0;
        var restaurantDiscountApproved = restaurantData?.RestaurantDiscountApproved ?? false;
        var restaurantDiscountIsActive = restaurantData?.RestaurantDiscountIsActive ?? true;
        var hasRestaurantDiscount = restaurantDiscountPercent > 0 && restaurantDiscountApproved && restaurantDiscountIsActive;

#if DEBUG
        Console.WriteLine($"[RESTAURANT_DISCOUNT DEBUG] RestaurantId={request.RestaurantId} " +
            $"RestaurantDiscountPercent={restaurantDiscountPercent} RestaurantDiscountApproved={restaurantDiscountApproved} " +
            $"hasRestaurantDiscount={hasRestaurantDiscount} userCouponId={request.UserCouponId}");
#endif

        // Kural: Müşteri kupon seçtiyse → Sadece kupon, restoran/kampanya indirimi uygulanmaz
        if ((hasRestaurantDiscount || await HasActiveCampaignAsync(request.RestaurantId, ct)) && request.UserCouponId.HasValue && request.CustomerUserId.HasValue)
        {
#if DEBUG
            Console.WriteLine("[RESTAURANT_DISCOUNT DEBUG] Branch: COUPON_ONLY (müşteri kupon seçti, restoran indirimi atlanıyor)");
#endif
            return await CalculateWithCouponOnlyAsync(request, menuItems, commissionRate, ct);
        }

        // Kural: Restoran indirimi var ve müşteri kupon seçmemiş → Sadece restoran indirimi
        if (hasRestaurantDiscount)
        {
#if DEBUG
            Console.WriteLine($"[RESTAURANT_DISCOUNT DEBUG] Branch: RESTAURANT_DISCOUNT_ONLY %{restaurantDiscountPercent}");
#endif
            return CalculateWithRestaurantDiscountOnly(
                request, menuItems, totalOriginal => totalOriginal * (restaurantDiscountPercent / 100m),
                commissionRate, restaurantDiscountPercent);
        }

        // Restoran indirimi yok: Campaign tablosundan aktif kampanya kontrol et (Status=Active, IsActive=true, sepet hedefli)
        var activeCampaign = await GetActiveCartCampaignAsync(request.RestaurantId, ct);
        if (activeCampaign != null)
        {
            var now = DateTime.UtcNow;
            if (activeCampaign.StartDate <= now && activeCampaign.EndDate >= now)
            {
                return CalculateWithCampaignDiscountAsync(request, menuItems, activeCampaign, commissionRate);
            }
        }

        // Restoran indirimi yok, kampanya yok: Sadece kupon (varsa) veya indirim yok
#if DEBUG
        Console.WriteLine("[RESTAURANT_DISCOUNT DEBUG] Branch: COUPON_OR_NONE (restoran indirimi yok veya onaysız)");
#endif
        return await CalculateWithCouponOrNoDiscountAsync(request, menuItems, commissionRate, ct);
    }

    private static CalculateCartResponse CalculateWithRestaurantDiscountOnly(
        CalculateCartRequest request,
        Dictionary<Guid, MenuItem> menuItems,
        Func<decimal, decimal> restaurantDiscountFunc,
        decimal commissionRate,
        decimal restaurantDiscountPercent)
    {
        var itemResults = new List<CalculateCartItemResponse>();
        decimal totalOriginal = 0;

        foreach (var reqItem in request.Items)
        {
            if (reqItem.Quantity <= 0) continue;

            menuItems.TryGetValue(reqItem.ProductId, out var menuItem);
            var productName = menuItem?.Name ?? "Ürün";
            var lineOriginal = ComputeLineOriginalPrice(reqItem);
            totalOriginal += lineOriginal;

            var lineDiscount = lineOriginal * (restaurantDiscountPercent / 100m);
            var discountedLine = lineOriginal - lineDiscount;

            itemResults.Add(new CalculateCartItemResponse(
                reqItem.ProductId,
                productName,
                reqItem.Quantity,
                lineOriginal,
                discountedLine,
                lineDiscount));
        }

        var totalDiscount = totalOriginal * (restaurantDiscountPercent / 100m);
        var finalPrice = Math.Max(0, totalOriginal - totalDiscount);
        var restaurantEarning = finalPrice * (1 - commissionRate);
        var platformEarning = finalPrice * commissionRate;

#if DEBUG
        Console.WriteLine($"[RESTAURANT_DISCOUNT DEBUG] Result RESTAURANT_DISCOUNT: totalDiscount={totalDiscount} finalPrice={finalPrice}");
#endif
        return new CalculateCartResponse(
            itemResults,
            totalOriginal,
            totalDiscount,
            finalPrice,
            finalPrice,
            restaurantEarning,
            platformEarning,
            HasRestaurantDiscount: true,
            RestaurantDiscountAmount: totalDiscount,
            CanUseCoupon: true, // Müşteri kupon seçerse restoran indirimi iptal edilir, sadece kupon uygulanır
            CouponDiscountAmount: 0,
            AppliedUserCouponId: null);
    }

    /// <summary>
    /// Kupon seçildiğinde ve restoran indirimi varken: Sadece kupon uygulanır.
    /// Restoran indirimi ve kampanyalar uygulanmaz (600 - 50 = 550 gibi).
    /// Kupon indirimi her ürüne orantılı dağıtılır (checkout ekranında güncel fiyat gösterimi için).
    /// </summary>
    private async Task<CalculateCartResponse> CalculateWithCouponOnlyAsync(
        CalculateCartRequest request,
        Dictionary<Guid, MenuItem> menuItems,
        decimal commissionRate,
        CancellationToken ct)
    {
        var itemResults = new List<CalculateCartItemResponse>();
        decimal totalOriginal = 0;

        foreach (var reqItem in request.Items)
        {
            if (reqItem.Quantity <= 0) continue;

            menuItems.TryGetValue(reqItem.ProductId, out var menuItem);
            var productName = menuItem?.Name ?? "Ürün";
            var lineOriginal = ComputeLineOriginalPrice(reqItem);
            totalOriginal += lineOriginal;

            itemResults.Add(new CalculateCartItemResponse(
                reqItem.ProductId,
                productName,
                reqItem.Quantity,
                lineOriginal,
                lineOriginal,
                0));
        }

        var subtotalBeforeCoupon = totalOriginal;
        decimal couponDiscount = 0;
        Guid? appliedUserCouponId = null;

        if (request.UserCouponId.HasValue && request.CustomerUserId.HasValue)
        {
            var (amount, _) = await _couponService.CalculateCouponDiscountAsync(
                request.CustomerUserId.Value,
                request.RestaurantId,
                subtotalBeforeCoupon,
                request.UserCouponId.Value,
                ct);
            couponDiscount = amount;
            appliedUserCouponId = request.UserCouponId;
        }

        var totalDiscount = couponDiscount;
        var finalPrice = Math.Max(0, totalOriginal - totalDiscount);

        // Kupon indirimini ürünlere orantılı dağıt (sipariş listesinde güncel fiyat gösterimi için)
        if (totalOriginal > 0 && totalDiscount > 0)
        {
            var updatedItems = new List<CalculateCartItemResponse>();
            decimal allocatedDiscount = 0;
            for (var i = 0; i < itemResults.Count; i++)
            {
                var item = itemResults[i];
                var isLast = i == itemResults.Count - 1;
                var lineDiscount = isLast
                    ? totalDiscount - allocatedDiscount
                    : Math.Round(totalDiscount * (item.OriginalPrice / totalOriginal), 2);
                allocatedDiscount += lineDiscount;
                var discountedLine = Math.Max(0, item.OriginalPrice - lineDiscount);
                updatedItems.Add(new CalculateCartItemResponse(
                    item.ProductId,
                    item.ProductName,
                    item.Quantity,
                    item.OriginalPrice,
                    discountedLine,
                    lineDiscount));
            }
            itemResults = updatedItems;
        }
        var restaurantEarning = finalPrice * (1 - commissionRate);
        var platformEarning = finalPrice * commissionRate;

        return new CalculateCartResponse(
            itemResults,
            totalOriginal,
            totalDiscount,
            finalPrice,
            finalPrice,
            restaurantEarning,
            platformEarning,
            HasRestaurantDiscount: false,
            RestaurantDiscountAmount: 0,
            CanUseCoupon: true,
            CouponDiscountAmount: couponDiscount,
            AppliedUserCouponId: appliedUserCouponId,
            HasRestaurantDiscountSkippedForCoupon: true);
    }

    /// <summary>
    /// Restoran indirimi yokken: Sadece kupon (seçildiyse) veya indirim yok.
    /// Kampanya indirimi uygulanmaz.
    /// Kupon indirimi her ürüne orantılı dağıtılır (checkout ekranında güncel fiyat gösterimi için).
    /// </summary>
    private async Task<CalculateCartResponse> CalculateWithCouponOrNoDiscountAsync(
        CalculateCartRequest request,
        Dictionary<Guid, MenuItem> menuItems,
        decimal commissionRate,
        CancellationToken ct)
    {
        var itemResults = new List<CalculateCartItemResponse>();
        decimal totalOriginal = 0;

        foreach (var reqItem in request.Items)
        {
            if (reqItem.Quantity <= 0) continue;

            menuItems.TryGetValue(reqItem.ProductId, out var menuItem);
            var productName = menuItem?.Name ?? "Ürün";
            var lineOriginal = ComputeLineOriginalPrice(reqItem);
            totalOriginal += lineOriginal;

            itemResults.Add(new CalculateCartItemResponse(
                reqItem.ProductId,
                productName,
                reqItem.Quantity,
                lineOriginal,
                lineOriginal,
                0));
        }

        decimal couponDiscount = 0;
        Guid? appliedUserCouponId = null;

        if (request.UserCouponId.HasValue && request.CustomerUserId.HasValue)
        {
            var (amount, _) = await _couponService.CalculateCouponDiscountAsync(
                request.CustomerUserId.Value,
                request.RestaurantId,
                totalOriginal,
                request.UserCouponId.Value,
                ct);
            couponDiscount = amount;
            appliedUserCouponId = request.UserCouponId;
        }

        var totalDiscount = couponDiscount;
        var finalPrice = Math.Max(0, totalOriginal - totalDiscount);

        // Kupon indirimini ürünlere orantılı dağıt (sipariş listesinde güncel fiyat gösterimi için)
        if (totalOriginal > 0 && totalDiscount > 0)
        {
            var updatedItems = new List<CalculateCartItemResponse>();
            decimal allocatedDiscount = 0;
            for (var i = 0; i < itemResults.Count; i++)
            {
                var item = itemResults[i];
                var isLast = i == itemResults.Count - 1;
                var lineDiscount = isLast
                    ? totalDiscount - allocatedDiscount
                    : Math.Round(totalDiscount * (item.OriginalPrice / totalOriginal), 2);
                allocatedDiscount += lineDiscount;
                var discountedLine = Math.Max(0, item.OriginalPrice - lineDiscount);
                updatedItems.Add(new CalculateCartItemResponse(
                    item.ProductId,
                    item.ProductName,
                    item.Quantity,
                    item.OriginalPrice,
                    discountedLine,
                    lineDiscount));
            }
            itemResults = updatedItems;
        }

        var restaurantEarning = finalPrice * (1 - commissionRate);
        var platformEarning = finalPrice * commissionRate;

        return new CalculateCartResponse(
            itemResults,
            totalOriginal,
            totalDiscount,
            finalPrice,
            finalPrice,
            restaurantEarning,
            platformEarning,
            HasRestaurantDiscount: false,
            RestaurantDiscountAmount: 0,
            CanUseCoupon: true,
            CouponDiscountAmount: couponDiscount,
            AppliedUserCouponId: appliedUserCouponId);
    }

    private static CalculateCartResponse EmptyResponse() =>
        new([], 0, 0, 0, 0, 0, 0);

    private async Task<bool> HasActiveCampaignAsync(Guid restaurantId, CancellationToken ct)
    {
        var campaign = await GetActiveCartCampaignAsync(restaurantId, ct);
        if (campaign == null) return false;
        var now = DateTime.UtcNow;
        return campaign.StartDate <= now && campaign.EndDate >= now;
    }

    private async Task<Campaign?> GetActiveCartCampaignAsync(Guid restaurantId, CancellationToken ct)
    {
        return await _db.Campaigns
            .AsNoTracking()
            .Where(c => c.RestaurantId == restaurantId
                && c.TargetType == CampaignTargetType.Cart
                && c.Status == "Active"
                && c.IsActive)
            .OrderByDescending(c => c.CreatedAtUtc)
            .FirstOrDefaultAsync(ct);
    }

    private static CalculateCartResponse CalculateWithCampaignDiscountAsync(
        CalculateCartRequest request,
        Dictionary<Guid, MenuItem> menuItems,
        Campaign campaign,
        decimal commissionRate)
    {
        var itemResults = new List<CalculateCartItemResponse>();
        decimal totalOriginal = 0;

        foreach (var reqItem in request.Items)
        {
            if (reqItem.Quantity <= 0) continue;
            menuItems.TryGetValue(reqItem.ProductId, out var menuItem);
            var productName = menuItem?.Name ?? "Ürün";
            var lineOriginal = ComputeLineOriginalPrice(reqItem);
            totalOriginal += lineOriginal;
            itemResults.Add(new CalculateCartItemResponse(
                reqItem.ProductId, productName, reqItem.Quantity,
                lineOriginal, lineOriginal, 0));
        }

        decimal totalDiscount = 0;
        if (campaign.MinCartAmount.HasValue && totalOriginal < campaign.MinCartAmount.Value)
        {
            totalDiscount = 0;
        }
        else if (campaign.DiscountType == CampaignDiscountType.Percentage)
        {
            totalDiscount = totalOriginal * (campaign.DiscountValue / 100m);
        }
        else
        {
            totalDiscount = Math.Min(campaign.DiscountValue, totalOriginal);
        }

        var finalPrice = Math.Max(0, totalOriginal - totalDiscount);

        if (totalOriginal > 0 && totalDiscount > 0)
        {
            var updatedItems = new List<CalculateCartItemResponse>();
            decimal allocatedDiscount = 0;
            for (var i = 0; i < itemResults.Count; i++)
            {
                var item = itemResults[i];
                var isLast = i == itemResults.Count - 1;
                var lineDiscount = isLast
                    ? totalDiscount - allocatedDiscount
                    : Math.Round(totalDiscount * (item.OriginalPrice / totalOriginal), 2);
                allocatedDiscount += lineDiscount;
                var discountedLine = Math.Max(0, item.OriginalPrice - lineDiscount);
                updatedItems.Add(new CalculateCartItemResponse(
                    item.ProductId, item.ProductName, item.Quantity,
                    item.OriginalPrice, discountedLine, lineDiscount));
            }
            itemResults = updatedItems;
        }

        var restaurantEarning = finalPrice * (1 - commissionRate);
        var platformEarning = finalPrice * commissionRate;

        return new CalculateCartResponse(
            itemResults, totalOriginal, totalDiscount, finalPrice, finalPrice,
            restaurantEarning, platformEarning,
            HasRestaurantDiscount: true,
            RestaurantDiscountAmount: totalDiscount,
            CanUseCoupon: true,
            CouponDiscountAmount: 0,
            AppliedUserCouponId: null);
    }

    private async Task EnsurePartiesAllowedForCheckoutAsync(CalculateCartRequest request, CancellationToken ct)
    {
        var restaurant = await _db.Restaurants.AsNoTracking()
            .FirstOrDefaultAsync(r => r.RestaurantId == request.RestaurantId, ct);
        if (restaurant is null)
        {
            return;
        }

        var owner = await _db.Users.AsNoTracking()
            .FirstOrDefaultAsync(u => u.UserId == restaurant.OwnerUserId, ct);
        _suspension.ThrowIfOperationallyBlocked(
            owner,
            "Bu işletme şu anda sipariş kabul edemiyor (askı veya kalıcı kapatma).");

        if (request.CustomerUserId is { } customerId && customerId != Guid.Empty)
        {
            var customer = await _db.Users.AsNoTracking()
                .FirstOrDefaultAsync(u => u.UserId == customerId, ct);
            _suspension.ThrowIfOperationallyBlocked(
                customer,
                "Hesabınız askıda veya kalıcı olarak kapatılmış; sipariş veremezsiniz.");
        }
    }
}
