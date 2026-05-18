using Vaveyla.Api.Data;

namespace Vaveyla.Api.Services.Recommendations;

public interface IRecommendationScoringService
{
    IReadOnlyList<(RecommendationCatalogRow Row, double Score)> ScoreAll(RecommendationQueryContext context);
}
