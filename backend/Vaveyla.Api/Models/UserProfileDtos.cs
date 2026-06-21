namespace Vaveyla.Api.Models;

public sealed record UserProfileDto(
    Guid UserId,
    string FullName,
    string Email,
    string? Phone,
    string? Address,
    string? PhotoUrl,
    /// <summary>Yalnızca JWT ile kendi profiline bakan kurye veya işletme sahibi için dolu; aksi halde null.</summary>
    int? TotalPenaltyPoints,
    bool NotificationEnabled);

public sealed record PatchUserSettingsRequest(bool NotificationEnabled);

public sealed record UpdateUserProfileRequest(
    string FullName,
    string Email,
    string? Phone,
    string? Address);
