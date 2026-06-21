namespace Vaveyla.Api.Models;

public sealed record FavoriteRestaurantDto(
    Guid Id,
    string Name,
    string Type,
    string? PhotoPath);

public sealed record FavoriteProductDto(
    Guid Id,
    string Name,
    int Price,
    string ImagePath,
    Guid RestaurantId,
    string RestaurantName,
    string? RestaurantType,
    byte SaleUnit);

public sealed record CustomerFavoritesResponse(
    List<FavoriteRestaurantDto> Restaurants,
    List<FavoriteProductDto> Products);

public sealed record UpdateCustomerFavoriteRequest(
    string Type,
    Guid TargetId);
