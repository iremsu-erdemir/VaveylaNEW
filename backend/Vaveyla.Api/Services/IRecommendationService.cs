using Vaveyla.Api.Models;

namespace Vaveyla.Api.Services;

public interface IRecommendationService
{
    Task<RecommendationsResponse> GetRecommendationsAsync(
        Guid userId,
        string? preference,
        CancellationToken cancellationToken);
}
