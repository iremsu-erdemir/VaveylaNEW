using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Data;

public sealed class ProductRepository : IProductRepository
{
    private readonly IRestaurantOwnerRepository _restaurantOwnerRepository;

    public ProductRepository(IRestaurantOwnerRepository restaurantOwnerRepository)
    {
        _restaurantOwnerRepository = restaurantOwnerRepository;
    }

    public async Task<IReadOnlyList<RecommendationCatalogRow>> GetAvailableCatalogAsync(
        CancellationToken cancellationToken)
    {
        var all = await _restaurantOwnerRepository.GetAllProductsAsync(cancellationToken);
        return all
            .Where(p => p.Item.IsAvailable)
            .Select(p => new RecommendationCatalogRow(
                p.Item,
                p.RestaurantName,
                p.RestaurantPhotoPath,
                p.RestaurantType,
                p.RestaurantAddress,
                p.RestaurantPhone,
                p.RestaurantLat,
                p.RestaurantLng,
                p.EstimatedDeliveryMinutes,
                p.RestaurantIsOpen))
            .ToList();
    }
}
