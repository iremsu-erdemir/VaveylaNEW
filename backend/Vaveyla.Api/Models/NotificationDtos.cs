namespace Vaveyla.Api.Models;

public sealed record NotificationDto(
    Guid NotificationId,
    Guid UserId,
    string UserRole,
    string Type,
    string Title,
    string Message,
    bool IsRead,
    DateTime CreatedAtUtc,
    DateTime? ReadAtUtc,
    Guid? RelatedOrderId,
    string? DataJson);

public sealed record CreateNotificationRequest(
    Guid? UserId,
    int? RoleId,
    string Type,
    string Title,
    string Message,
    Guid? RelatedOrderId,
    Dictionary<string, object?>? Data);

public sealed record RegisterDeviceTokenRequest(
    Guid UserId,
    string Platform,
    string Token);
