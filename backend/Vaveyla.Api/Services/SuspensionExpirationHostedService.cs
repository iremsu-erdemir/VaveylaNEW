namespace Vaveyla.Api.Services;

/// <summary>Periyodik olarak süresi dolan hesap askılarını kaldırır (varsayılan: 1 saat).</summary>
public sealed class SuspensionExpirationHostedService : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<SuspensionExpirationHostedService> _logger;
    private static readonly TimeSpan Interval = TimeSpan.FromHours(1);

    public SuspensionExpirationHostedService(
        IServiceScopeFactory scopeFactory,
        ILogger<SuspensionExpirationHostedService> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = _scopeFactory.CreateScope();
                var suspension = scope.ServiceProvider.GetRequiredService<IUserSuspensionService>();
                await suspension.ClearExpiredSuspensionsAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Askı süresi dolu kullanıcıları temizlerken hata oluştu.");
            }

            try
            {
                await Task.Delay(Interval, stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
        }
    }
}
