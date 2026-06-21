namespace Vaveyla.Api.Models;

/// <summary>
/// Teslim edilmiş siparişlerden türetilen menü kalemi istatistikleri (uygulama içi ayrıştırma).
/// </summary>
public sealed record MenuItemOrderStatistics(
    IReadOnlyDictionary<Guid, int> GlobalQtyByMenuItemId,
    IReadOnlyDictionary<Guid, int> GlobalQtyRecentByMenuItemId,
    IReadOnlyDictionary<Guid, int> UserQtyByMenuItemId,
    IReadOnlyDictionary<Guid, DateTime> UserLastOrderedAtUtcByMenuItemId,
    bool CustomerHasDeliveredOrders);
