using Microsoft.EntityFrameworkCore;

namespace Vaveyla.Api.Data;

/// <summary>
/// Siparişte <see cref="Models.CustomerOrder.AssignedCourierUserId"/> boş olsa bile
/// teslimat sohbetinde müşteri dışı gönderen kurye kimliği çıkarılabilir.
/// </summary>
public static class CustomerOrderCourierHelper
{
    public static async Task<Dictionary<Guid, Guid>> GetCourierUserIdsFromDeliveryChatAsync(
        VaveylaDbContext db,
        Guid customerUserId,
        IReadOnlyCollection<Guid> orderIds,
        CancellationToken cancellationToken = default)
    {
        if (orderIds.Count == 0)
        {
            return new Dictionary<Guid, Guid>();
        }

        var rows = await db.DeliveryChatMessages.AsNoTracking()
            .Where(m => orderIds.Contains(m.OrderId) && m.DeletedAtUtc == null)
            .Select(m => new { m.OrderId, m.SenderUserId, m.CreatedAtUtc })
            .ToListAsync(cancellationToken);

        var result = new Dictionary<Guid, Guid>();
        foreach (var group in rows.GroupBy(x => x.OrderId))
        {
            var pick = group
                .OrderByDescending(x => x.CreatedAtUtc)
                .FirstOrDefault(x => x.SenderUserId != customerUserId);
            if (pick != null)
            {
                result[group.Key] = pick.SenderUserId;
            }
        }

        return result;
    }
}
