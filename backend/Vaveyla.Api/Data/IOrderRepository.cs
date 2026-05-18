using Vaveyla.Api.Models;

namespace Vaveyla.Api.Data;

public interface IOrderRepository
{
    /// <summary>
    /// Teslim siparişleri tek geçişte işler: global / son pencere / kullanıcı adetleri ve kullanıcı bazlı son sipariş zamanı.
    /// </summary>
    Task<MenuItemOrderStatistics> GetOrderStatisticsAsync(
        Guid customerUserId,
        IReadOnlyDictionary<Guid, IReadOnlyList<MenuItem>> menusByRestaurantId,
        int recentOrderWindowDays,
        CancellationToken cancellationToken);
}
