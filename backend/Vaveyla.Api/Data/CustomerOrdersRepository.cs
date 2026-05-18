using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Data;

public interface ICustomerOrdersRepository
{
    Task<CustomerOrder> CreateOrderAsync(CustomerOrder order, CancellationToken cancellationToken);
    Task<List<CustomerOrder>> GetOrdersForCustomerAsync(Guid customerUserId, CancellationToken cancellationToken);
    Task<List<CustomerOrder>> GetOrdersForRestaurantAsync(Guid restaurantId, CancellationToken cancellationToken);
    Task<List<CustomerOrder>> GetOrdersForCourierAsync(CancellationToken cancellationToken);
    Task<List<CustomerOrder>> GetOrdersForCourierAsync(Guid courierUserId, CancellationToken cancellationToken);
    Task<CustomerOrder?> GetOrderAsync(Guid orderId, CancellationToken cancellationToken);
    Task UpdateOrderStatusAsync(CustomerOrder order, CancellationToken cancellationToken);
    Task AddCourierLocationAsync(CourierLocationLog location, CancellationToken cancellationToken);
    Task<Dictionary<Guid, string>> GetCourierRefusalReasonsByOrderIdsAsync(
        Guid courierUserId,
        IReadOnlyCollection<Guid> orderIds,
        CancellationToken cancellationToken);
    Task<string?> GetCourierRefusalReasonAsync(
        Guid orderId,
        Guid courierUserId,
        CancellationToken cancellationToken);
    Task AddCourierOrderRefusalAsync(
        Guid orderId,
        Guid courierUserId,
        string reason,
        CancellationToken cancellationToken);
    Task ClearCourierOrderRefusalAsync(
        Guid orderId,
        Guid courierUserId,
        CancellationToken cancellationToken);
    Task<Dictionary<Guid, string>> GetLatestCourierRefusalReasonsByOrderIdsAsync(
        IReadOnlyCollection<Guid> orderIds,
        CancellationToken cancellationToken);
}

public sealed class CustomerOrdersRepository : ICustomerOrdersRepository
{
    private readonly VaveylaDbContext _dbContext;

    public CustomerOrdersRepository(VaveylaDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task<CustomerOrder> CreateOrderAsync(
        CustomerOrder order,
        CancellationToken cancellationToken)
    {
        _dbContext.CustomerOrders.Add(order);
        await _dbContext.SaveChangesAsync(cancellationToken);
        return order;
    }

    public async Task<List<CustomerOrder>> GetOrdersForCustomerAsync(
        Guid customerUserId,
        CancellationToken cancellationToken)
    {
        return await _dbContext.CustomerOrders
            .Where(o => o.CustomerUserId == customerUserId)
            .OrderByDescending(o => o.CreatedAtUtc)
            .ToListAsync(cancellationToken);
    }

    public async Task<List<CustomerOrder>> GetOrdersForRestaurantAsync(
        Guid restaurantId,
        CancellationToken cancellationToken)
    {
        return await _dbContext.CustomerOrders
            .Where(o => o.RestaurantId == restaurantId)
            .OrderByDescending(o => o.CreatedAtUtc)
            .ToListAsync(cancellationToken);
    }

    public async Task<List<CustomerOrder>> GetOrdersForCourierAsync(
        CancellationToken cancellationToken)
    {
        return await _dbContext.CustomerOrders
            .Where(o => o.Status != CustomerOrderStatus.Delivered &&
                        o.Status != CustomerOrderStatus.Cancelled)
            .OrderByDescending(o => o.CreatedAtUtc)
            .ToListAsync(cancellationToken);
    }

    public async Task<List<CustomerOrder>> GetOrdersForCourierAsync(
        Guid courierUserId,
        CancellationToken cancellationToken)
    {
        // Yalnızca bu kuryeye atanmış siparişler (havuzdaki / atanmamış siparişler görünmez).
        return await _dbContext.CustomerOrders
            .Where(o =>
                o.AssignedCourierUserId == courierUserId &&
                o.Status != CustomerOrderStatus.Cancelled)
            .OrderByDescending(o => o.CreatedAtUtc)
            .ToListAsync(cancellationToken);
    }

    public async Task<CustomerOrder?> GetOrderAsync(
        Guid orderId,
        CancellationToken cancellationToken)
    {
        return await _dbContext.CustomerOrders
            .FirstOrDefaultAsync(o => o.OrderId == orderId, cancellationToken);
    }

    public async Task UpdateOrderStatusAsync(
        CustomerOrder order,
        CancellationToken cancellationToken)
    {
        _dbContext.CustomerOrders.Update(order);
        await _dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task AddCourierLocationAsync(
        CourierLocationLog location,
        CancellationToken cancellationToken)
    {
        _dbContext.CourierLocationLogs.Add(location);
        await _dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task<Dictionary<Guid, string>> GetCourierRefusalReasonsByOrderIdsAsync(
        Guid courierUserId,
        IReadOnlyCollection<Guid> orderIds,
        CancellationToken cancellationToken)
    {
        if (orderIds.Count == 0)
        {
            return new Dictionary<Guid, string>();
        }

        var rows = await _dbContext.CourierOrderRefusals
            .AsNoTracking()
            .Where(r => r.CourierUserId == courierUserId && orderIds.Contains(r.OrderId))
            .Select(r => new { r.OrderId, r.Reason })
            .ToListAsync(cancellationToken);
        return rows.ToDictionary(x => x.OrderId, x => x.Reason);
    }

    public async Task<string?> GetCourierRefusalReasonAsync(
        Guid orderId,
        Guid courierUserId,
        CancellationToken cancellationToken)
    {
        return await _dbContext.CourierOrderRefusals
            .AsNoTracking()
            .Where(r => r.OrderId == orderId && r.CourierUserId == courierUserId)
            .Select(r => r.Reason)
            .FirstOrDefaultAsync(cancellationToken);
    }

    public async Task AddCourierOrderRefusalAsync(
        Guid orderId,
        Guid courierUserId,
        string reason,
        CancellationToken cancellationToken)
    {
        _dbContext.CourierOrderRefusals.Add(new CourierOrderRefusal
        {
            RefusalId = Guid.NewGuid(),
            OrderId = orderId,
            CourierUserId = courierUserId,
            Reason = reason,
            CreatedAtUtc = DateTime.UtcNow,
        });
        await _dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task ClearCourierOrderRefusalAsync(
        Guid orderId,
        Guid courierUserId,
        CancellationToken cancellationToken)
    {
        await _dbContext.CourierOrderRefusals
            .Where(r => r.OrderId == orderId && r.CourierUserId == courierUserId)
            .ExecuteDeleteAsync(cancellationToken);
    }

    public async Task<Dictionary<Guid, string>> GetLatestCourierRefusalReasonsByOrderIdsAsync(
        IReadOnlyCollection<Guid> orderIds,
        CancellationToken cancellationToken)
    {
        if (orderIds.Count == 0)
        {
            return new Dictionary<Guid, string>();
        }

        var rows = await _dbContext.CourierOrderRefusals
            .AsNoTracking()
            .Where(r => orderIds.Contains(r.OrderId))
            .OrderByDescending(r => r.CreatedAtUtc)
            .Select(r => new { r.OrderId, r.Reason, r.CreatedAtUtc })
            .ToListAsync(cancellationToken);

        var result = new Dictionary<Guid, string>();
        foreach (var row in rows)
        {
            if (!result.ContainsKey(row.OrderId))
            {
                result[row.OrderId] = row.Reason;
            }
        }

        return result;
    }
}
