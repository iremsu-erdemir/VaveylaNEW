using Vaveyla.Api.Models;

namespace Vaveyla.Api.Data;

public interface IProductRepository
{
    /// <summary>Müşteri uygulamasında satışa açık menü ürünleri (öneri skoru için katalog).</summary>
    Task<IReadOnlyList<RecommendationCatalogRow>> GetAvailableCatalogAsync(
        CancellationToken cancellationToken);
}

public sealed record RecommendationCatalogRow(
    MenuItem Item,
    string RestaurantName,
    string? RestaurantPhotoPath,
    string RestaurantType,
    string? RestaurantAddress,
    string RestaurantPhone,
    double? RestaurantLat,
    double? RestaurantLng,
    int? EstimatedDeliveryMinutes,
    bool RestaurantIsOpen);
