using System.Text.Json.Serialization;

namespace Vaveyla.Api.Models;

public sealed record CustomerCartItemDto(
    Guid Id,
    Guid ProductId,
    Guid RestaurantId,
    string Name,
    [property: JsonPropertyName("imagePath")] string ImagePath,
    [property: JsonPropertyName("unitPrice")] int UnitPrice,
    [property: JsonPropertyName("weightKg")] decimal WeightKg,
    int Quantity,
    [property: JsonPropertyName("saleUnit")] byte SaleUnit);

public sealed record AddCartItemRequest(
    Guid ProductId,
    int Quantity,
    [property: JsonPropertyName("weightKg")] decimal WeightKg);

public sealed record UpdateCartItemRequest(int Quantity);
