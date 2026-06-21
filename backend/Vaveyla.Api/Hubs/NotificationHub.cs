using Microsoft.AspNetCore.SignalR;

namespace Vaveyla.Api.Hubs;

public sealed class NotificationHub : Hub
{
    public Task SubscribeUser(string userId)
    {
        return Groups.AddToGroupAsync(Context.ConnectionId, $"user:{userId}");
    }

    public Task UnsubscribeUser(string userId)
    {
        return Groups.RemoveFromGroupAsync(Context.ConnectionId, $"user:{userId}");
    }
}
