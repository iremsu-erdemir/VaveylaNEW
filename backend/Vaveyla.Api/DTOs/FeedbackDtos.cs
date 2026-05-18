using System.ComponentModel.DataAnnotations;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.DTOs;

public sealed class CreateCustomerFeedbackRequest
{
    [Required]
    public FeedbackTargetType TargetType { get; set; }

    [Required]
    public Guid TargetEntityId { get; set; }

    [Required]
    [MaxLength(1200)]
    public string Message { get; set; } = string.Empty;
}

public sealed record FeedbackAdminListItemDto(
    int FeedbackId,
    string ComplainantName,
    string TargetDisplay,
    string? OrderNumberLabel,
    string? OrderTitle,
    DateTime CreatedAtUtc,
    string Message,
    FeedbackStatus Status,
    string StatusLabel);

public sealed class AdminFeedbackActionRequest
{
    [Required]
    public AdminActionType Action { get; set; }

    /// <summary>Yalnızca <see cref="AdminActionType.AddPenaltyPoints"/> için; varsayılan 20.</summary>
    [Range(1, 500)]
    public int? Points { get; set; }

    /// <summary>
    /// Yalnızca <see cref="AdminActionType.SuspendUser"/> için: 3 veya 7 gün.
    /// <see cref="SuspendUntilUtc"/> ile birlikte kullanılmamalıdır.
    /// </summary>
    public int? SuspendDays { get; set; }

    /// <summary>
    /// Yalnızca <see cref="AdminActionType.SuspendUser"/> için: manuel bitiş (UTC).
    /// Şimdiden sonra ve en fazla yaklaşık 365 gün olmalıdır.
    /// </summary>
    public DateTime? SuspendUntilUtc { get; set; }
}
