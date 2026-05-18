using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Data;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Controllers;

[ApiController]
[Route("api/restaurant")]
public sealed class RestaurantTopProductsController : ControllerBase
{
    private readonly VaveylaDbContext _dbContext;
    private readonly IRestaurantOwnerRepository _restaurantRepo;

    public RestaurantTopProductsController(
        VaveylaDbContext dbContext,
        IRestaurantOwnerRepository restaurantRepo)
    {
        _dbContext = dbContext;
        _restaurantRepo = restaurantRepo;
    }

    [HttpGet("{restaurantId:guid}/top-products")]
    [HttpGet("/restaurant/{restaurantId:guid}/top-products")]
    public async Task<ActionResult<object>> GetTopProducts(
        [FromRoute] Guid restaurantId,
        [FromQuery] string? period,
        CancellationToken cancellationToken)
    {
        if (restaurantId == Guid.Empty)
        {
            return BadRequest(new { message = "RestaurantId is required." });
        }

        var normalizedPeriod = (period ?? "all").Trim().ToLowerInvariant();
        DateTime? startUtc = null;

        if (normalizedPeriod == "all")
        {
            startUtc = null;
        }
        else if (normalizedPeriod == "weekly")
        {
            startUtc = DateTime.UtcNow.AddDays(-7);
        }
        else if (normalizedPeriod == "monthly")
        {
            startUtc = DateTime.UtcNow.AddDays(-30);
        }
        else
        {
            return BadRequest(new
            {
                message = "Invalid period. Use 'all', 'weekly', or 'monthly'."
            });
        }

        var menuItems = await _restaurantRepo.GetMenuItemsAsync(restaurantId, cancellationToken);
        if (menuItems.Count == 0)
        {
            return Ok(new { bestSeller = (object?)null, topProducts = Array.Empty<object>() });
        }

        var normalizedNameToMenuItem = menuItems
            .Where(mi => !string.IsNullOrWhiteSpace(mi.Name))
            .GroupBy(mi => OrderItemsLineParser.NormalizeName(mi.Name))
            .ToDictionary(g => g.Key, g => g.First());

        var ordersQuery = _dbContext.CustomerOrders
            .Where(o =>
                o.RestaurantId == restaurantId &&
                o.Status == CustomerOrderStatus.Delivered)
            .AsNoTracking();

        if (startUtc.HasValue)
        {
            ordersQuery = ordersQuery.Where(o => o.CreatedAtUtc >= startUtc.Value);
        }

        // We only need Items strings to calculate top products.
        var orders = await ordersQuery
            .Select(o => o.Items)
            .ToListAsync(cancellationToken);

        var totalsByMenuItemId = new Dictionary<Guid, int>();
        var menuItemsList = menuItems;

        foreach (var itemsText in orders)
        {
            if (string.IsNullOrWhiteSpace(itemsText))
            {
                continue;
            }

            foreach (var (qty, productName) in OrderItemsLineParser.ParseItems(itemsText))
            {
                if (qty <= 0 || string.IsNullOrWhiteSpace(productName))
                {
                    continue;
                }

                var matched = OrderItemsLineParser.MatchMenuItem(
                    productName,
                    normalizedNameToMenuItem,
                    menuItemsList);

                if (matched is null)
                {
                    continue;
                }

                totalsByMenuItemId.TryGetValue(matched.MenuItemId, out var current);
                totalsByMenuItemId[matched.MenuItemId] = current + qty;
            }
        }

        if (totalsByMenuItemId.Count == 0)
        {
            return Ok(new { bestSeller = (object?)null, topProducts = Array.Empty<object>() });
        }

        var menuItemById = menuItems.ToDictionary(mi => mi.MenuItemId, mi => mi);

        var sortedTop = totalsByMenuItemId
            .OrderByDescending(kvp => kvp.Value)
            .ThenBy(kvp => menuItemById.TryGetValue(kvp.Key, out var mi) ? mi.Name : string.Empty)
            .Take(10)
            .ToList();

        var bestSellerId = sortedTop[0].Key;
        var bestSellerItem = menuItemById[bestSellerId];
        var bestSellerTotal = totalsByMenuItemId[bestSellerId];

        var topProducts = sortedTop.Select(kvp =>
        {
            var productId = kvp.Key;
            var productName = menuItemById[productId].Name;
            return new
            {
                productId,
                productName,
                totalSold = kvp.Value
            };
        }).ToList();

        return Ok(new
        {
            bestSeller = new
            {
                productId = bestSellerId,
                productName = bestSellerItem.Name,
                totalSold = bestSellerTotal
            },
            topProducts = topProducts
        });
    }

}

