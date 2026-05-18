using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Data;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Controllers;

[ApiController]
[Route("api/customer/favorites")]
public sealed class CustomerFavoritesController : ControllerBase
{
    private readonly VaveylaDbContext _dbContext;

    public CustomerFavoritesController(VaveylaDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    [HttpGet]
    public async Task<ActionResult<CustomerFavoritesResponse>> GetFavorites(
        [FromQuery] Guid customerUserId,
        CancellationToken cancellationToken)
    {
        if (customerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Customer user id is required." });
        }

        var favorites = await _dbContext.CustomerFavorites
            .Where(x => x.CustomerUserId == customerUserId)
            .ToListAsync(cancellationToken);
        var restaurantIds = favorites
            .Where(x => x.FavoriteType == "restaurant")
            .Select(x => x.TargetId)
            .Distinct()
            .ToList();
        var productIds = favorites
            .Where(x => x.FavoriteType == "product")
            .Select(x => x.TargetId)
            .Distinct()
            .ToList();

        var restaurants = await _dbContext.Restaurants
            .Where(x => restaurantIds.Contains(x.RestaurantId))
            .Select(x => new FavoriteRestaurantDto(
                x.RestaurantId,
                x.Name,
                x.Type,
                x.PhotoPath))
            .ToListAsync(cancellationToken);

        var products = await _dbContext.MenuItems
            .Where(x => productIds.Contains(x.MenuItemId))
            .Join(
                _dbContext.Restaurants,
                p => p.RestaurantId,
                r => r.RestaurantId,
                (p, r) => new FavoriteProductDto(
                    p.MenuItemId,
                    p.Name,
                    p.Price,
                    p.ImagePath,
                    r.RestaurantId,
                    r.Name,
                    r.Type,
                    p.SaleUnit))
            .ToListAsync(cancellationToken);

        var response = new CustomerFavoritesResponse(restaurants, products);
        return Ok(response);
    }

    [HttpPost]
    public async Task<ActionResult> AddFavorite(
        [FromQuery] Guid customerUserId,
        [FromBody] UpdateCustomerFavoriteRequest request,
        CancellationToken cancellationToken)
    {
        if (customerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Customer user id is required." });
        }
        if (!TryNormalizeType(request.Type, out var favoriteType))
        {
            return BadRequest(new { message = "Invalid favorite type." });
        }
        if (request.TargetId == Guid.Empty)
        {
            return BadRequest(new { message = "Target id is required." });
        }

        var exists = await FavoriteTargetExistsAsync(
            favoriteType,
            request.TargetId,
            cancellationToken);
        if (!exists)
        {
            return NotFound(new { message = "Target not found." });
        }

        var alreadyAdded = await _dbContext.CustomerFavorites.AnyAsync(
            x =>
                x.CustomerUserId == customerUserId &&
                x.FavoriteType == favoriteType &&
                x.TargetId == request.TargetId,
            cancellationToken);
        if (!alreadyAdded)
        {
            _dbContext.CustomerFavorites.Add(new CustomerFavorite
            {
                FavoriteId = Guid.NewGuid(),
                CustomerUserId = customerUserId,
                FavoriteType = favoriteType,
                TargetId = request.TargetId,
                CreatedAtUtc = DateTime.UtcNow,
            });
            await _dbContext.SaveChangesAsync(cancellationToken);
        }

        return NoContent();
    }

    [HttpDelete]
    public async Task<ActionResult> RemoveFavorite(
        [FromQuery] Guid customerUserId,
        [FromQuery] string type,
        [FromQuery] Guid targetId,
        CancellationToken cancellationToken)
    {
        if (customerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Customer user id is required." });
        }
        if (!TryNormalizeType(type, out var favoriteType))
        {
            return BadRequest(new { message = "Invalid favorite type." });
        }
        if (targetId == Guid.Empty)
        {
            return BadRequest(new { message = "Target id is required." });
        }

        var favorite = await _dbContext.CustomerFavorites.FirstOrDefaultAsync(
            x =>
                x.CustomerUserId == customerUserId &&
                x.FavoriteType == favoriteType &&
                x.TargetId == targetId,
            cancellationToken);
        if (favorite is null)
        {
            return NoContent();
        }

        _dbContext.CustomerFavorites.Remove(favorite);
        await _dbContext.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    private async Task<bool> FavoriteTargetExistsAsync(
        string type,
        Guid targetId,
        CancellationToken cancellationToken)
    {
        if (type == "restaurant")
        {
            return await _dbContext.Restaurants.AnyAsync(
                x => x.RestaurantId == targetId,
                cancellationToken);
        }

        return await _dbContext.MenuItems.AnyAsync(
            x => x.MenuItemId == targetId,
            cancellationToken);
    }

    private static bool TryNormalizeType(string? value, out string normalized)
    {
        normalized = string.Empty;
        var text = value?.Trim().ToLowerInvariant();
        if (string.IsNullOrWhiteSpace(text))
        {
            return false;
        }

        switch (text)
        {
            case "restaurant":
            case "pastane":
                normalized = "restaurant";
                return true;
            case "product":
            case "menu":
            case "urun":
                normalized = "product";
                return true;
            default:
                return false;
        }
    }
}
