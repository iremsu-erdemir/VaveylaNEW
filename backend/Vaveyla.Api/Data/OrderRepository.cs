using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Data;

public sealed class OrderRepository : IOrderRepository
{
    private readonly VaveylaDbContext _dbContext;

    public OrderRepository(VaveylaDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task<MenuItemOrderStatistics> GetOrderStatisticsAsync(
        Guid customerUserId,
        IReadOnlyDictionary<Guid, IReadOnlyList<MenuItem>> menusByRestaurantId,
        int recentOrderWindowDays,
        CancellationToken cancellationToken)
    {
        var rows = await _dbContext.CustomerOrders
            .AsNoTracking()
            .Where(o => o.Status == CustomerOrderStatus.Delivered)
            .Select(o => new { o.CustomerUserId, o.RestaurantId, o.Items, o.CreatedAtUtc })
            .ToListAsync(cancellationToken);

        var cutoffUtc = DateTime.UtcNow.AddDays(-Math.Max(1, recentOrderWindowDays));
        var globalQty = new Dictionary<Guid, int>();
        var globalRecentQty = new Dictionary<Guid, int>();
        var userQty = new Dictionary<Guid, int>();
        var userLastUtc = new Dictionary<Guid, DateTime>();

        var customerHasDeliveredOrders = customerUserId != Guid.Empty &&
            rows.Any(r => r.CustomerUserId == customerUserId);

        foreach (var row in rows)
        {
            AccumulateOrderLineMatches(
                row.RestaurantId,
                row.Items,
                row.CreatedAtUtc,
                menusByRestaurantId,
                globalQty,
                globalRecentQty,
                userQty,
                userLastUtc,
                row.CreatedAtUtc >= cutoffUtc,
                customerUserId,
                row.CustomerUserId);
        }

        return new MenuItemOrderStatistics(
            globalQty,
            globalRecentQty,
            userQty,
            userLastUtc,
            customerHasDeliveredOrders);
    }

    private static void AccumulateOrderLineMatches(
        Guid restaurantId,
        string itemsText,
        DateTime createdAtUtc,
        IReadOnlyDictionary<Guid, IReadOnlyList<MenuItem>> menusByRestaurantId,
        Dictionary<Guid, int> globalQty,
        Dictionary<Guid, int> globalRecentQty,
        Dictionary<Guid, int> userQty,
        Dictionary<Guid, DateTime> userLastUtc,
        bool includeInRecentWindow,
        Guid forCustomerId,
        Guid orderCustomerId)
    {
        if (string.IsNullOrWhiteSpace(itemsText))
        {
            return;
        }

        if (!menusByRestaurantId.TryGetValue(restaurantId, out var menuItems) || menuItems.Count == 0)
        {
            return;
        }

        var normalizedNameToMenuItem = menuItems
            .Where(mi => !string.IsNullOrWhiteSpace(mi.Name))
            .GroupBy(mi => OrderItemsLineParser.NormalizeName(mi.Name))
            .ToDictionary(g => g.Key, g => g.First());

        var menuItemsList = menuItems.ToList();
        var isUserOrder = orderCustomerId == forCustomerId;

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

            var id = matched.MenuItemId;
            AddQty(globalQty, id, qty);
            if (includeInRecentWindow)
            {
                AddQty(globalRecentQty, id, qty);
            }

            if (isUserOrder)
            {
                AddQty(userQty, id, qty);
                if (!userLastUtc.TryGetValue(id, out var prev) || createdAtUtc > prev)
                {
                    userLastUtc[id] = createdAtUtc;
                }
            }
        }
    }

    private static void AddQty(Dictionary<Guid, int> totals, Guid menuItemId, int qty)
    {
        totals.TryGetValue(menuItemId, out var current);
        totals[menuItemId] = current + qty;
    }
}
