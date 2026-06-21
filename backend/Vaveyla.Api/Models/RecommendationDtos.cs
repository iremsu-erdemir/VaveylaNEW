using System.Text.Json.Serialization;

namespace Vaveyla.Api.Models;

public enum ProductCategory
{
    Sweet,
    Savory,
    Drink,
    Snack,
    Bakery,
}

public sealed record RecommendationItemDto(
    Guid Id,
    Guid RestaurantId,
    string? RestaurantName,
    string Name,
    string ShortDescription,
    string ImageUrl,
    int Price,
    byte SaleUnit,
    double Score,
    string Reason,
    ProductCategory Category,
    string Subcategory,
    IReadOnlyList<string> Tags,
    bool IsActive);

public sealed record RecommendationsResponse(
    [property: JsonPropertyName("products")] IReadOnlyList<RecommendationItemDto> Products,
    string AppliedFilter,
    IReadOnlyList<string> ExcludedProducts,
    string Reason,
    IReadOnlyList<RecommendationFilterOptionDto> AvailableFilters)
{
    [JsonPropertyName("items")]
    public IReadOnlyList<RecommendationItemDto> Items => Products;
}

public sealed record RecommendationFilterOptionDto(
    string Id,
    string Label,
    string ApiPreference);
