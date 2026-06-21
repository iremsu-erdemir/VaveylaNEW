namespace Vaveyla.Api.Services;

public sealed record PushMessage(
    string Title,
    string Body,
    Dictionary<string, string>? Data = null);

public interface IPushNotificationSender
{
    Task SendAsync(string deviceToken, PushMessage message, CancellationToken cancellationToken);
}
