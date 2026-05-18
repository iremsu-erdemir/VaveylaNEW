using Vaveyla.Api.Data;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Services.Recommendations;

public sealed class RecommendationQueryService : IRecommendationQueryService
{
    public const int RecentOrderWindowDays = 30;

    private readonly IProductRepository _productRepository;
    private readonly IOrderRepository _orderRepository;

    public RecommendationQueryService(
        IProductRepository productRepository,
        IOrderRepository orderRepository)
    {
        _productRepository = productRepository;
        _orderRepository = orderRepository;
    }

    public async Task<RecommendationQueryContext?> BuildAsync(
        Guid customerUserId,
        string? preference,
        CancellationToken cancellationToken)
    {
        if (customerUserId == Guid.Empty)
        {
            return null;
        }

        var catalog = await _productRepository.GetAvailableCatalogAsync(cancellationToken);
        if (catalog.Count == 0)
        {
            return new RecommendationQueryContext(
                catalog,
                new Dictionary<Guid, IReadOnlyList<MenuItem>>(),
                new MenuItemOrderStatistics(
                    new Dictionary<Guid, int>(),
                    new Dictionary<Guid, int>(),
                    new Dictionary<Guid, int>(),
                    new Dictionary<Guid, DateTime>(),
                    false),
                0,
                RecommendationScoringService.ParsePreference(preference),
                GetIstanbulNow(),
                false,
                "sweet/any",
                Array.Empty<string>(),
                "Katalog bos.",
                DefaultFilters);
        }

        var filterPreference = RecommendationScoringService.ParsePreference(preference);
        var (filteredCatalog, excludedProducts, appliedFilter, filterReason) =
            ApplyHardFilter(catalog, filterPreference);

        var menusByRestaurant = catalog
            .GroupBy(c => c.Item.RestaurantId)
            .ToDictionary(
                g => g.Key,
                g => (IReadOnlyList<MenuItem>)g
                    .Select(x => x.Item)
                    .GroupBy(m => m.MenuItemId)
                    .Select(x => x.First())
                    .ToList());

        var stats = await _orderRepository.GetOrderStatisticsAsync(
            customerUserId,
            menusByRestaurant,
            RecentOrderWindowDays,
            cancellationToken);

        var maxGlobal = stats.GlobalQtyByMenuItemId.Values.DefaultIfEmpty(0).Max();

        return new RecommendationQueryContext(
            filteredCatalog,
            menusByRestaurant,
            stats,
            maxGlobal,
            filterPreference,
            GetIstanbulNow(),
            stats.CustomerHasDeliveredOrders,
            appliedFilter,
            excludedProducts,
            filterReason,
            DefaultFilters);
    }

    private static readonly IReadOnlyList<RecommendationFilterOptionDto> DefaultFilters =
        new[]
        {
            new RecommendationFilterOptionDto("sweet", "Tatli", "any"),
            new RecommendationFilterOptionDto("chocolate", "Cikolatali", "chocolate"),
            new RecommendationFilterOptionDto("fruit", "Meyveli", "fruit"),
            new RecommendationFilterOptionDto("bakery", "Kahvaltilik", "bakery"),
            new RecommendationFilterOptionDto("drink", "Icecek", "drink"),
        };

    private static (IReadOnlyList<RecommendationCatalogRow> Filtered, IReadOnlyList<string> Excluded, string AppliedFilter, string Reason)
        ApplyHardFilter(IReadOnlyList<RecommendationCatalogRow> catalog, SweetPreference preference)
    {
        var excluded = new List<string>();
        var filtered = new List<RecommendationCatalogRow>();

        foreach (var row in catalog)
        {
            if (!row.Item.IsAvailable)
            {
                excluded.Add(row.Item.Name);
                continue;
            }

            var category = ResolveCategory(row.Item);
            var tags = ResolveTags(row.Item);
            var pass = preference switch
            {
                SweetPreference.Chocolate => category == ProductCategory.Sweet && tags.Contains("chocolate"),
                SweetPreference.Fruit => category == ProductCategory.Sweet && tags.Contains("fruit"),
                SweetPreference.Bakery => category == ProductCategory.Bakery,
                SweetPreference.Drink => category == ProductCategory.Drink,
                SweetPreference.Savory => category == ProductCategory.Savory,
                _ => category == ProductCategory.Sweet,
            };

            if (pass)
            {
                filtered.Add(row);
            }
            else
            {
                excluded.Add(row.Item.Name);
            }
        }

        if (filtered.Count > 0)
        {
            var scope = preference switch
            {
                SweetPreference.Bakery => "bakery",
                SweetPreference.Drink => "drink",
                SweetPreference.Savory => "savory",
                _ => "sweet",
            };
            return (filtered, excluded, $"{scope}/{preference.ToString().ToLowerInvariant()}", "Hard filter uygulandi.");
        }

        if (preference is SweetPreference.Bakery or SweetPreference.Drink or SweetPreference.Savory)
        {
            var scope = preference.ToString().ToLowerInvariant();
            return (Array.Empty<RecommendationCatalogRow>(), excluded, $"{scope}/strict", "Secili kategori icin urun bulunamadi.");
        }

        var snackFallback = catalog.Where(r => ResolveCategory(r.Item) == ProductCategory.Snack).ToList();
        if (snackFallback.Count > 0)
        {
            return (snackFallback, excluded, "snack/fallback", "Sweet category bos, snack fallback uygulandi.");
        }

        return (catalog, excluded, "global/trending", "Fallback sonrasinda global trend urunler donduruldu.");
    }

    private static ProductCategory ResolveCategory(MenuItem item)
    {
        var value = item.CategoryName?.Trim().ToLowerInvariant() ?? string.Empty;
        var blob = $"{item.Name} {value}".ToLowerInvariant();
        if (blob.Contains("borek")
            || blob.Contains("börek")
            || blob.Contains("kut boregi")
            || blob.Contains("küt böreği")
            || blob.Contains("kruvasan")
            || blob.Contains("croissant")
            || blob.Contains("pogaca")
            || blob.Contains("poğaça")
            || blob.Contains("simit")
            || blob.Contains("sandvic")
            || blob.Contains("sandviç"))
            return ProductCategory.Bakery;
        if (blob.Contains("icecek") || blob.Contains("içecek") || blob.Contains("drink") || blob.Contains("kahve") || blob.Contains("cay") || blob.Contains("çay"))
            return ProductCategory.Drink;
        if (blob.Contains("tuzlu"))
            return ProductCategory.Savory;
        if (blob.Contains("atistirmalik") || blob.Contains("atıştırmalık") || blob.Contains("snack"))
            return ProductCategory.Snack;
        return ProductCategory.Sweet;
    }

    private static HashSet<string> ResolveTags(MenuItem item)
    {
        var blob = $"{item.Name} {item.CategoryName}".ToLowerInvariant();
        var tags = new HashSet<string>();
        if (blob.Contains("cikolata") || blob.Contains("çikolata") || blob.Contains("chocolate"))
            tags.Add("chocolate");
        if (blob.Contains("meyve") || blob.Contains("cilek") || blob.Contains("çilek") || blob.Contains("fruit"))
            tags.Add("fruit");
        if (blob.Contains("hafif") || blob.Contains("light") || blob.Contains("sutlu") || blob.Contains("sütlü"))
            tags.Add("light");
        if (blob.Contains("fit") || blob.Contains("low calorie"))
            tags.Add("low-calorie");
        if (blob.Contains("geleneksel"))
            tags.Add("traditional");
        return tags;
    }

    private static DateTime GetIstanbulNow()
    {
        try
        {
            var tz = TimeZoneInfo.FindSystemTimeZoneById(
                OperatingSystem.IsWindows() ? "Turkey Standard Time" : "Europe/Istanbul");
            return TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, tz);
        }
        catch
        {
            return DateTime.UtcNow;
        }
    }
}
