using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Data;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Controllers;

[ApiController]
[Route("api/products")]
public sealed class ProductsController : ControllerBase
{
    private readonly IRestaurantOwnerRepository _repository;
    private readonly VaveylaDbContext _dbContext;

    public ProductsController(
        IRestaurantOwnerRepository repository,
        VaveylaDbContext dbContext)
    {
        _repository = repository;
        _dbContext = dbContext;
    }

    /// <summary>
    /// Müşteri paneli için ürünleri getirir.
    /// type: featured | new | popular | all
    /// category: kategori adı (örn: Pastalar)
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<List<CustomerProductDto>>> GetProducts(
        [FromQuery] string? type,
        [FromQuery] string? category,
        [FromQuery] Guid? restaurantId,
        CancellationToken cancellationToken)
    {
        var all = await _repository.GetAllProductsAsync(cancellationToken);
        var reviewStats = await _dbContext.RestaurantReviews
            .Where(r =>
                (r.TargetType == "menu" && r.TargetId != Guid.Empty) ||
                (r.TargetType == "order" && r.ProductId.HasValue))
            .GroupBy(r => r.TargetType == "menu" ? r.TargetId : r.ProductId!.Value)
            .Select(g => new
            {
                ProductId = g.Key,
                Rating = Math.Round(g.Average(x => x.Rating), 1),
                ReviewCount = g.Count(),
            })
            .ToDictionaryAsync(x => x.ProductId, cancellationToken);

        var products = all
            .Select(p =>
            {
                reviewStats.TryGetValue(p.Item.MenuItemId, out var stats);
                return new CustomerProductDto(
                    p.Item.MenuItemId,
                    p.Item.RestaurantId,
                    p.RestaurantName,
                    p.RestaurantPhotoPath,
                    p.RestaurantType,
                    p.RestaurantAddress,
                    p.RestaurantPhone,
                    p.RestaurantLat,
                    p.RestaurantLng,
                    p.EstimatedDeliveryMinutes,
                    p.RestaurantIsOpen,
                    p.Item.CategoryName,
                    p.Item.Name,
                    p.Item.Price,
                    p.Item.SaleUnit,
                    stats?.Rating ?? 0,
                    stats?.ReviewCount ?? 0,
                    p.Item.ImagePath,
                    p.Item.IsAvailable,
                    p.Item.IsFeatured,
                    p.Item.CreatedAtUtc);
            })
            .ToList();

        if (!string.IsNullOrWhiteSpace(category))
        {
            var cat = category.Trim();
            products = products
                .Where(p => string.Equals(p.CategoryName, cat, StringComparison.OrdinalIgnoreCase))
                .ToList();
        }

        if (restaurantId.HasValue && restaurantId.Value != Guid.Empty)
        {
            products = products.Where(p => p.RestaurantId == restaurantId.Value).ToList();
        }

        var typeFilter = type?.Trim().ToLowerInvariant();
        switch (typeFilter)
        {
            case "featured":
                products = products.Where(p => p.IsFeatured).ToList();
                break;
            case "new":
                var oneWeekAgo = DateTime.UtcNow.AddDays(-7);
                products = products
                    .Where(p => p.CreatedAtUtc >= oneWeekAgo)
                    .OrderByDescending(p => p.CreatedAtUtc)
                    .ToList();
                break;
            case "popular":
                products = products
                    .Where(p => p.Rating >= 4.0)
                    .OrderByDescending(p => p.Rating)
                    .ThenByDescending(p => p.ReviewCount)
                    .ThenByDescending(p => p.CreatedAtUtc)
                    .ToList();
                break;
            case "all":
            default:
                break;
        }

        return Ok(products);
    }
}
