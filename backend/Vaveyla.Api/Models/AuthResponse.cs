namespace Vaveyla.Api.Models;

public sealed class AuthResponse
{
    public Guid UserId { get; init; }
    public UserRole Role { get; init; }
    public string FullName { get; init; } = string.Empty;
    public string? Token { get; init; }

    /// <summary>JWT alındıktan sonra da süre dolana kadar true olabilir; istemci uyarı gösterebilir.</summary>
    public bool IsSuspended { get; init; }

    public DateTime? SuspendedUntilUtc { get; init; }

    public bool NotificationEnabled { get; init; } = true;
}
