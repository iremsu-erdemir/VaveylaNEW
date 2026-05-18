namespace Vaveyla.Api.Services;

public sealed class NoopPushNotificationSender : IPushNotificationSender
{
    private readonly ILogger<NoopPushNotificationSender> _logger;

    public NoopPushNotificationSender(ILogger<NoopPushNotificationSender> logger)
    {
        _logger = logger;
    }

    public Task SendAsync(string deviceToken, PushMessage message, CancellationToken cancellationToken)
    {
        _logger.LogInformation(
            "Push sender is noop. Token={Token}, Title={Title}",
            deviceToken,
            message.Title);
        return Task.CompletedTask;
    }
}
