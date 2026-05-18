using Vaveyla.Api.Data;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Services.Recommendations;

public sealed class RecommendationComposer : IRecommendationComposer
{
    public RecommendationsResponse Compose(
        RecommendationQueryContext context,
        IReadOnlyList<(RecommendationCatalogRow Row, double Score)> scored)
    {
        var orderedRows = scored
            .OrderByDescending(x => x.Score)
            .ThenByDescending(x =>
                context.Statistics.GlobalQtyByMenuItemId.GetValueOrDefault(x.Row.Item.MenuItemId))
            .Select(x => x.Row)
            .DistinctBy(x => x.Item.MenuItemId)
            .ToList();

        var n = orderedRows.Count;
        var pickCount = n == 0 ? 0 : n < 3 ? n : Math.Min(5, n);

        var scoreByMenuItemId = scored
            .GroupBy(x => x.Row.Item.MenuItemId)
            .ToDictionary(g => g.Key, g => g.Max(x => x.Score));

        var picked = orderedRows.Take(pickCount).ToList();

        var items = picked
            .Select(row =>
            {
                scoreByMenuItemId.TryGetValue(row.Item.MenuItemId, out var s);
                var score = Math.Round(s, 4);
                return new RecommendationItemDto(
                    row.Item.MenuItemId,
                    row.Item.RestaurantId,
                    row.RestaurantName,
                    row.Item.Name,
                    BuildShortDescription(row),
                    row.Item.ImagePath,
                    row.Item.Price,
                    row.Item.SaleUnit,
                    score,
                    BuildReason(context, row, score),
                    ResolveCategory(row.Item),
                    ResolveSubcategory(row.Item),
                    ResolveTags(row.Item).ToList(),
                    row.Item.IsAvailable);
            })
            .ToList();

        return new RecommendationsResponse(
            items,
            context.AppliedFilter,
            context.ExcludedProducts,
            context.FilterReason,
            context.AvailableFilters);
    }

    private static string BuildShortDescription(RecommendationCatalogRow row)
    {
        var cat = string.IsNullOrWhiteSpace(row.Item.CategoryName) ? "Tatlı" : row.Item.CategoryName!.Trim();
        var rest = string.IsNullOrWhiteSpace(row.RestaurantName) ? "Pastane" : row.RestaurantName.Trim();
        var text = $"{cat} · {rest}";
        return text.Length <= 140 ? text : text[..137] + "...";
    }

    private static string BuildReason(
        RecommendationQueryContext context,
        RecommendationCatalogRow row,
        double score)
    {
        context.Statistics.UserQtyByMenuItemId.TryGetValue(row.Item.MenuItemId, out var userQty);
        context.Statistics.GlobalQtyByMenuItemId.TryGetValue(row.Item.MenuItemId, out var globalQty);
        var hour = context.IstanbulNow.Hour;
        var timeHint = hour < 12 ? "gune hafif bir baslangic" : hour < 18 ? "gun ortasi tatli molasi" : "aksam keyfi";

        if (context.Preference == SweetPreference.Any)
        {
            if (userQty > 0)
            {
                return $"Daha once bu urunu tercih ettigin icin ve su anki {timeHint} icin iyi bir eslesme oldugu icin onerildi.";
            }

            if (globalQty > 0)
            {
                return $"Son siparis trendlerinde one ciktigi ve {timeHint} icin dengeli bir secim oldugu icin onerildi.";
            }

            return $"Skorlamada yuksek puan aldigi ve {timeHint} icin uygun oldugu icin sana ozel secildi.";
        }

        var prefLabel = context.Preference switch
        {
            SweetPreference.Chocolate => "cikolatali",
            SweetPreference.Fruit => "meyveli",
            SweetPreference.Bakery => "kahvaltilik",
            SweetPreference.Drink => "icecek",
            SweetPreference.Savory => "tuzlu",
            _ => "dengeli",
        };

        if (score >= 0.8)
        {
            return $"{prefLabel} tercihine cok guclu uyum sagladigi ve tazelik/populerlik dengesi iyi oldugu icin onerildi.";
        }

        if (userQty > 0)
        {
            return $"{prefLabel} zevkine uydugu ve onceki siparis gecmisinle eslestigi icin onerildi.";
        }

        return $"{prefLabel} profilinle uyumlu oldugu ve bugunun saatine uygun bir tatli deneyimi sundugu icin secildi.";
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

    private static string ResolveSubcategory(MenuItem item)
    {
        var blob = $"{item.Name} {item.CategoryName}".ToLowerInvariant();
        if (blob.Contains("cikolata") || blob.Contains("çikolata")) return "chocolate";
        if (blob.Contains("meyve") || blob.Contains("fruit")) return "fruit";
        if (blob.Contains("hamur") || blob.Contains("pastry")) return "pastry";
        if (blob.Contains("ekmek") || blob.Contains("bread")) return "bread";
        return "general";
    }

    private static IReadOnlyCollection<string> ResolveTags(MenuItem item)
    {
        var blob = $"{item.Name} {item.CategoryName}".ToLowerInvariant();
        var tags = new HashSet<string>();
        if (blob.Contains("cikolata") || blob.Contains("çikolata") || blob.Contains("chocolate"))
            tags.Add("chocolate");
        if (blob.Contains("meyve") || blob.Contains("cilek") || blob.Contains("çilek") || blob.Contains("fruit"))
            tags.Add("fruit");
        if (blob.Contains("hafif") || blob.Contains("light") || blob.Contains("sutlu") || blob.Contains("sütlü"))
            tags.Add("light");
        if (blob.Contains("kizartma") || blob.Contains("fried"))
            tags.Add("fried");
        if (blob.Contains("geleneksel"))
            tags.Add("traditional");
        return tags;
    }
}
