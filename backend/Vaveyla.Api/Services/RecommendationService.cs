using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;
using Vaveyla.Api.Models;
using Vaveyla.Api.Services.Recommendations;

namespace Vaveyla.Api.Services;

public sealed class RecommendationService : IRecommendationService
{
    private static readonly TimeSpan CacheDuration = TimeSpan.FromSeconds(90);

    private readonly IMemoryCache _cache;
    private readonly IRecommendationQueryService _query;
    private readonly IRecommendationScoringService _scoring;
    private readonly IRecommendationComposer _composer;
    private readonly ILogger<RecommendationService> _logger;

    public RecommendationService(
        IMemoryCache cache,
        IRecommendationQueryService query,
        IRecommendationScoringService scoring,
        IRecommendationComposer composer,
        ILogger<RecommendationService> logger)
    {
        _cache = cache;
        _query = query;
        _scoring = scoring;
        _composer = composer;
        _logger = logger;
    }

    public async Task<RecommendationsResponse> GetRecommendationsAsync(
        Guid userId,
        string? preference,
        CancellationToken cancellationToken)
    {
        if (userId == Guid.Empty)
        {
            return EmptyResponse("sweet/any", "Kullanici bulunamadi.");
        }

        var prefKey = string.IsNullOrWhiteSpace(preference) ? "any" : preference.Trim().ToLowerInvariant();
        var cacheKey = $"recommendation:{userId:N}:{prefKey}";

        if (_cache.TryGetValue(cacheKey, out RecommendationsResponse? cached) && cached is not null)
        {
            return cached;
        }

        var context = await _query.BuildAsync(userId, preference, cancellationToken);
        if (context is null)
        {
            return EmptyResponse("sweet/any", "Context olusturulamadi.");
        }

        if (context.Catalog.Count == 0)
        {
            var empty = EmptyResponse(context.AppliedFilter, context.FilterReason);
            _cache.Set(cacheKey, empty, CacheDuration);
            return empty;
        }

        var scored = _scoring.ScoreAll(context);
        var result = _composer.Compose(context, scored);
        _logger.LogInformation(
            "Recommendation debug | preference={Preference} applied={AppliedFilter} excluded={Excluded} final={Final}",
            prefKey,
            result.AppliedFilter,
            string.Join(", ", result.ExcludedProducts),
            string.Join(" | ", result.Products.Select(p => $"{p.Name}:{p.Score:F2}")));

        _cache.Set(cacheKey, result, CacheDuration);
        return result;
    }

    private static RecommendationsResponse EmptyResponse(string appliedFilter, string reason) =>
        new(
            Array.Empty<RecommendationItemDto>(),
            appliedFilter,
            Array.Empty<string>(),
            reason,
            Array.Empty<RecommendationFilterOptionDto>());
}
