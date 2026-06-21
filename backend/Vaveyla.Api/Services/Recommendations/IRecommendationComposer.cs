using Vaveyla.Api.Data;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Services.Recommendations;

public interface IRecommendationComposer
{
    RecommendationsResponse Compose(
        RecommendationQueryContext context,
        IReadOnlyList<(RecommendationCatalogRow Row, double Score)> scored);
}
