using Vaveyla.Api.Data;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Services.Recommendations;

/// <summary>
/// Basit üretim skoru: 0.4 kullanıcı tercihi + 0.3 popülerlik + 0.2 zaman/mevsim + 0.1 recency.
/// </summary>
public sealed class RecommendationScoringService : IRecommendationScoringService
{
    private const double WeightUserPreference = 0.4;
    private const double WeightPopularity = 0.3;
    private const double WeightTimeMatch = 0.2;
    private const double WeightRecency = 0.1;

    private const double RecencyHalfLifeDays = 60d;

    private static readonly string[] ChocolateHints =
    {
        "çikolata", "chocolate", "brownie", "kakao", "cacao", "ganaj", "ganache", "truffle",
        "bitter", "mozaik", "profiterol",
    };

    private static readonly string[] FruitHints =
    {
        "meyve", "çilek", "cilek", "vişne", "visne", "limon", "portakal", "mango", "frambuaz",
        "ahududu", "elma", "armut", "kivi", "ananas", "berry", "fruit", "dondurma",
    };

    public IReadOnlyList<(RecommendationCatalogRow Row, double Score)> ScoreAll(
        RecommendationQueryContext context)
    {
        var utcNow = DateTime.UtcNow;
        var list = new List<(RecommendationCatalogRow, double)>();
        foreach (var row in context.Catalog)
        {
            var id = row.Item.MenuItemId;
            context.Statistics.UserQtyByMenuItemId.TryGetValue(id, out var userQty);
            context.Statistics.GlobalQtyByMenuItemId.TryGetValue(id, out var globalQty);
            DateTime? lastUtc = context.Statistics.UserLastOrderedAtUtcByMenuItemId.TryGetValue(id, out var lu)
                ? lu
                : null;

            var score = ScoreRow(
                row.Item,
                context.Preference,
                context.IstanbulNow,
                utcNow,
                userQty,
                lastUtc,
                globalQty,
                context.MaxGlobalQty,
                context.CustomerHasDeliveredOrders);

            list.Add((row, score));
        }

        return list;
    }

    public static SweetPreference ParsePreference(string? preference)
    {
        var p = (preference ?? "any").Trim().ToLowerInvariant();
        return p switch
        {
            "chocolate" or "çikolatalı" or "cikolatali" => SweetPreference.Chocolate,
            "fruit" or "meyveli" => SweetPreference.Fruit,
            "bakery" or "kahvaltilik" or "kahvaltılık" => SweetPreference.Bakery,
            "drink" or "icecek" or "içecek" => SweetPreference.Drink,
            "savory" or "tuzlu" => SweetPreference.Savory,
            _ => SweetPreference.Any,
        };
    }

    private static double ScoreRow(
        MenuItem item,
        SweetPreference preference,
        DateTime istanbulNow,
        DateTime utcNow,
        int userQty,
        DateTime? userLastOrderedAtUtc,
        int globalQty,
        int maxGlobalQty,
        bool customerHasDeliveredOrders)
    {
        var taste = PreferenceMatch(preference, item);
        var affinity = Math.Min(1d, Math.Log(1 + userQty) / Math.Log(1 + 10d));

        var userPreference = customerHasDeliveredOrders
            ? 0.55 * taste + 0.45 * affinity
            : taste;

        var popularity = maxGlobalQty <= 0
            ? 0d
            : Math.Min(1d, globalQty / (double)maxGlobalQty);

        var timeMatch = TimeMatch(item, istanbulNow, preference);
        var recency = Recency(userLastOrderedAtUtc, utcNow);

        if (preference == SweetPreference.Any)
        {
            // "Fark etmez" modunda davranis, trend ve saat uyumunu daha belirleyici hale getir.
            return Math.Clamp(
                0.30 * userPreference +
                0.35 * popularity +
                0.25 * timeMatch +
                0.10 * recency,
                0d,
                1d);
        }

        return Math.Clamp(
            WeightUserPreference * userPreference +
            WeightPopularity * popularity +
            WeightTimeMatch * timeMatch +
            WeightRecency * recency,
            0d,
            1d);
    }

    private static double PreferenceMatch(SweetPreference pref, MenuItem item)
    {
        if (pref == SweetPreference.Any)
        {
            return 1d;
        }

        var blob = $"{item.Name} {item.CategoryName}".ToLowerInvariant();
        var ch = MatchesAny(blob, ChocolateHints);
        var fr = MatchesAny(blob, FruitHints);
        return pref switch
        {
            SweetPreference.Chocolate => ch ? 1d : fr ? 0.25d : 0.55d,
            SweetPreference.Fruit => fr ? 1d : ch ? 0.3d : 0.55d,
            _ => 1d,
        };
    }

    private static double TimeMatch(MenuItem item, DateTime localNow, SweetPreference pref)
    {
        var hour = localNow.Hour;
        var month = localNow.Month;

        var hourFit = hour switch
        {
            >= 6 and < 11 => 0.85d,
            >= 11 and < 16 => 0.78d,
            >= 16 and < 23 => MatchesChocolate(item) ? 0.95d : 0.55d,
            _ => 0.5d,
        };

        var summer = month is 6 or 7 or 8;
        var winter = month is 12 or 1 or 2;
        var seasonFit = summer
            ? (MatchesFruit(item) ? 1d : 0.55d)
            : winter
                ? (MatchesChocolate(item) ? 0.95d : 0.55d)
                : 0.75d;

        if (pref == SweetPreference.Chocolate)
        {
            hourFit = 0.55 * hourFit + 0.45 * (MatchesChocolate(item) ? 1d : 0.35d);
        }
        else if (pref == SweetPreference.Fruit)
        {
            seasonFit = 0.5 * seasonFit + 0.5 * (MatchesFruit(item) ? 1d : 0.35d);
        }
        return Math.Clamp(0.65 * hourFit + 0.35 * seasonFit, 0d, 1d);
    }

    private static double Recency(DateTime? lastUtc, DateTime utcNow)
    {
        if (!lastUtc.HasValue)
        {
            return 0.35d;
        }

        var days = Math.Max(0d, (utcNow - lastUtc.Value).TotalDays);
        return Math.Exp(-days / RecencyHalfLifeDays);
    }

    private static bool MatchesChocolate(MenuItem item) =>
        MatchesAny($"{item.Name} {item.CategoryName}", ChocolateHints);

    private static bool MatchesFruit(MenuItem item) =>
        MatchesAny($"{item.Name} {item.CategoryName}", FruitHints);

    private static bool MatchesAny(string text, IEnumerable<string> hints) =>
        hints.Any(h => text.Contains(h, StringComparison.OrdinalIgnoreCase));
}
