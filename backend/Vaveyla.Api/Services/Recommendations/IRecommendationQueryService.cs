namespace Vaveyla.Api.Services.Recommendations;

public interface IRecommendationQueryService
{
    Task<RecommendationQueryContext?> BuildAsync(
        Guid customerUserId,
        string? preference,
        CancellationToken cancellationToken);
}
