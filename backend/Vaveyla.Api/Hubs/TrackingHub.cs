using Microsoft.AspNetCore.SignalR;

namespace Vaveyla.Api.Hubs;

public sealed class TrackingHub : Hub
{
    public Task SubscribeOrder(string orderId)
    {
        return Groups.AddToGroupAsync(Context.ConnectionId, GroupName(orderId));
    }

    public Task UnsubscribeOrder(string orderId)
    {
        return Groups.RemoveFromGroupAsync(Context.ConnectionId, GroupName(orderId));
    }

    public Task StartTracking(string orderId)
    {
        return Groups.AddToGroupAsync(Context.ConnectionId, GroupName(orderId));
    }

    public Task StopTracking(string orderId)
    {
        return Groups.RemoveFromGroupAsync(Context.ConnectionId, GroupName(orderId));
    }

    public static string GroupName(string orderId) => $"order:{orderId}";
}
