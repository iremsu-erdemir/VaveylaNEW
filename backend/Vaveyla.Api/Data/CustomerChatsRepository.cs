using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Data;

public interface ICustomerChatsRepository
{
    Task<List<RestaurantChatMessage>> GetMessagesAsync(
        Guid customerUserId,
        Guid restaurantId,
        int limit,
        CancellationToken cancellationToken);

    Task<RestaurantChatMessage> AddMessageAsync(
        RestaurantChatMessage message,
        CancellationToken cancellationToken);

    Task<bool> DeleteCustomerMessageAsync(
        Guid chatMessageId,
        Guid customerUserId,
        CancellationToken cancellationToken);
}

public sealed class CustomerChatsRepository : ICustomerChatsRepository
{
    private readonly VaveylaDbContext _dbContext;

    public CustomerChatsRepository(VaveylaDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task<List<RestaurantChatMessage>> GetMessagesAsync(
        Guid customerUserId,
        Guid restaurantId,
        int limit,
        CancellationToken cancellationToken)
    {
        if (limit < 1)
        {
            limit = 1;
        }
        if (limit > 200)
        {
            limit = 200;
        }

        var raw = await _dbContext.RestaurantChatMessages
            .Where(x => x.CustomerUserId == customerUserId && x.RestaurantId == restaurantId)
            .OrderByDescending(x => x.CreatedAtUtc)
            .Take(limit)
            .ToListAsync(cancellationToken);

        raw.Reverse();
        return raw;
    }

    public async Task<RestaurantChatMessage> AddMessageAsync(
        RestaurantChatMessage message,
        CancellationToken cancellationToken)
    {
        _dbContext.RestaurantChatMessages.Add(message);
        await _dbContext.SaveChangesAsync(cancellationToken);
        return message;
    }

    public async Task<bool> DeleteCustomerMessageAsync(
        Guid chatMessageId,
        Guid customerUserId,
        CancellationToken cancellationToken)
    {
        var message = await _dbContext.RestaurantChatMessages.FirstOrDefaultAsync(
            x => x.ChatMessageId == chatMessageId &&
                 x.CustomerUserId == customerUserId &&
                 x.SenderUserId == customerUserId &&
                 x.SenderType == "customer",
            cancellationToken);
        if (message is null)
        {
            return false;
        }

        _dbContext.RestaurantChatMessages.Remove(message);
        await _dbContext.SaveChangesAsync(cancellationToken);
        return true;
    }
}
