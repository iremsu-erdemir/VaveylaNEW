using Vaveyla.Api.Data;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Services.Recommendations;

public sealed record RecommendationQueryContext(
    IReadOnlyList<RecommendationCatalogRow> Catalog,
    IReadOnlyDictionary<Guid, IReadOnlyList<MenuItem>> MenusByRestaurantId,
    MenuItemOrderStatistics Statistics,
    int MaxGlobalQty,
    SweetPreference Preference,
    DateTime IstanbulNow,
    bool CustomerHasDeliveredOrders,
    string AppliedFilter,
    IReadOnlyList<string> ExcludedProducts,
    string FilterReason,
    IReadOnlyList<RecommendationFilterOptionDto> AvailableFilters);
