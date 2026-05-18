using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Data;

public interface INotificationRepository
{
    Task<Notification> AddAsync(Notification notification, CancellationToken cancellationToken);
    Task<List<Notification>> GetByUserAsync(Guid userId, int page, int pageSize, bool? isRead, CancellationToken cancellationToken);
    Task<int> GetUnreadCountAsync(Guid userId, CancellationToken cancellationToken);
    Task<Notification?> GetByIdAsync(Guid notificationId, CancellationToken cancellationToken);
    Task MarkAsReadAsync(Notification notification, CancellationToken cancellationToken);
    Task MarkAllAsReadAsync(Guid userId, CancellationToken cancellationToken);
    Task<List<Guid>> GetUserIdsByRoleAsync(UserRole role, CancellationToken cancellationToken);
    Task<User?> GetUserAsync(Guid userId, CancellationToken cancellationToken);
    Task<Guid?> GetRestaurantOwnerUserIdAsync(Guid restaurantId, CancellationToken cancellationToken);
    Task UpsertDeviceTokenAsync(UserDeviceToken token, CancellationToken cancellationToken);
    Task<List<UserDeviceToken>> GetDeviceTokensAsync(Guid userId, CancellationToken cancellationToken);
}

public sealed class NotificationRepository : INotificationRepository
{
    private readonly VaveylaDbContext _dbContext;

    public NotificationRepository(VaveylaDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task<Notification> AddAsync(Notification notification, CancellationToken cancellationToken)
    {
        _dbContext.Notifications.Add(notification);
        await _dbContext.SaveChangesAsync(cancellationToken);
        return notification;
    }

    public async Task<List<Notification>> GetByUserAsync(
        Guid userId,
        int page,
        int pageSize,
        bool? isRead,
        CancellationToken cancellationToken)
    {
        var query = _dbContext.Notifications
            .AsNoTracking()
            .Where(x => x.UserId == userId);

        if (isRead.HasValue)
        {
            query = query.Where(x => x.IsRead == isRead.Value);
        }

        return await query
            .OrderByDescending(x => x.CreatedAtUtc)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);
    }

    public async Task<int> GetUnreadCountAsync(Guid userId, CancellationToken cancellationToken)
    {
        return await _dbContext.Notifications
            .CountAsync(x => x.UserId == userId && !x.IsRead, cancellationToken);
    }

    public async Task<Notification?> GetByIdAsync(Guid notificationId, CancellationToken cancellationToken)
    {
        return await _dbContext.Notifications
            .FirstOrDefaultAsync(x => x.NotificationId == notificationId, cancellationToken);
    }

    public async Task MarkAsReadAsync(Notification notification, CancellationToken cancellationToken)
    {
        _dbContext.Notifications.Update(notification);
        await _dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task MarkAllAsReadAsync(Guid userId, CancellationToken cancellationToken)
    {
        var notifications = await _dbContext.Notifications
            .Where(x => x.UserId == userId && !x.IsRead)
            .ToListAsync(cancellationToken);

        if (notifications.Count == 0)
        {
            return;
        }

        var now = DateTime.UtcNow;
        foreach (var notification in notifications)
        {
            notification.IsRead = true;
            notification.ReadAtUtc = now;
        }

        _dbContext.Notifications.UpdateRange(notifications);
        await _dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task<List<Guid>> GetUserIdsByRoleAsync(UserRole role, CancellationToken cancellationToken)
    {
        return await _dbContext.Users
            .Where(x => x.Role == role)
            .Select(x => x.UserId)
            .ToListAsync(cancellationToken);
    }

    public async Task<User?> GetUserAsync(Guid userId, CancellationToken cancellationToken)
    {
        return await _dbContext.Users.FirstOrDefaultAsync(x => x.UserId == userId, cancellationToken);
    }

    public async Task<Guid?> GetRestaurantOwnerUserIdAsync(Guid restaurantId, CancellationToken cancellationToken)
    {
        return await _dbContext.Restaurants
            .Where(x => x.RestaurantId == restaurantId)
            .Select(x => (Guid?)x.OwnerUserId)
            .FirstOrDefaultAsync(cancellationToken);
    }

    public async Task UpsertDeviceTokenAsync(UserDeviceToken token, CancellationToken cancellationToken)
    {
        var existing = await _dbContext.UserDeviceTokens
            .FirstOrDefaultAsync(
                x => x.UserId == token.UserId && x.Token == token.Token,
                cancellationToken);

        if (existing is null)
        {
            _dbContext.UserDeviceTokens.Add(token);
        }
        else
        {
            existing.Platform = token.Platform;
            existing.LastSeenAtUtc = token.LastSeenAtUtc;
            _dbContext.UserDeviceTokens.Update(existing);
        }

        await _dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task<List<UserDeviceToken>> GetDeviceTokensAsync(Guid userId, CancellationToken cancellationToken)
    {
        return await _dbContext.UserDeviceTokens
            .AsNoTracking()
            .Where(x => x.UserId == userId)
            .ToListAsync(cancellationToken);
    }
}
