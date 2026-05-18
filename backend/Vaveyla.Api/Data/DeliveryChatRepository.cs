using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Data;

public sealed class DeliveryChatRepository : IDeliveryChatRepository
{
    private readonly VaveylaDbContext _db;

    public DeliveryChatRepository(VaveylaDbContext db)
    {
        _db = db;
    }

    public async Task<List<DeliveryChatMessage>> GetMessagesForOrderAsync(
        Guid orderId,
        CancellationToken cancellationToken)
    {
        return await _db.DeliveryChatMessages
            .AsNoTracking()
            .Where(m => m.OrderId == orderId && m.DeletedAtUtc == null)
            .OrderBy(m => m.CreatedAtUtc)
            .ToListAsync(cancellationToken);
    }

    public async Task<DeliveryChatMessage> AddMessageAsync(
        DeliveryChatMessage message,
        CancellationToken cancellationToken)
    {
        _db.DeliveryChatMessages.Add(message);
        await _db.SaveChangesAsync(cancellationToken);
        return message;
    }

    public async Task<DeliveryChatMessage?> UpdateMessageAsync(
        Guid messageId,
        Guid orderId,
        Guid senderUserId,
        string text,
        CancellationToken cancellationToken)
    {
        var msg = await _db.DeliveryChatMessages.FirstOrDefaultAsync(
            m =>
                m.MessageId == messageId &&
                m.OrderId == orderId &&
                m.DeletedAtUtc == null,
            cancellationToken);

        if (msg is null || msg.SenderUserId != senderUserId)
        {
            return null;
        }

        msg.Message = text;
        msg.EditedAtUtc = DateTime.UtcNow;
        await _db.SaveChangesAsync(cancellationToken);
        return msg;
    }

    public async Task<bool> SoftDeleteMessageAsync(
        Guid messageId,
        Guid orderId,
        Guid senderUserId,
        CancellationToken cancellationToken)
    {
        var msg = await _db.DeliveryChatMessages.FirstOrDefaultAsync(
            m =>
                m.MessageId == messageId &&
                m.OrderId == orderId &&
                m.DeletedAtUtc == null,
            cancellationToken);

        if (msg is null || msg.SenderUserId != senderUserId)
        {
            return false;
        }

        msg.DeletedAtUtc = DateTime.UtcNow;
        await _db.SaveChangesAsync(cancellationToken);
        return true;
    }
}
