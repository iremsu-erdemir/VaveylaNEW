using Vaveyla.Api.Models;

namespace Vaveyla.Api.Data;

public interface IDeliveryChatRepository
{
    Task<List<DeliveryChatMessage>> GetMessagesForOrderAsync(
        Guid orderId,
        CancellationToken cancellationToken);

    Task<DeliveryChatMessage> AddMessageAsync(
        DeliveryChatMessage message,
        CancellationToken cancellationToken);

    Task<DeliveryChatMessage?> UpdateMessageAsync(
        Guid messageId,
        Guid orderId,
        Guid senderUserId,
        string text,
        CancellationToken cancellationToken);

    Task<bool> SoftDeleteMessageAsync(
        Guid messageId,
        Guid orderId,
        Guid senderUserId,
        CancellationToken cancellationToken);
}
