using System.ComponentModel.DataAnnotations;

namespace Vaveyla.Api.Models;

public sealed record UserFeedbackDto(
    Guid FeedbackId,
    Guid UserId,
    string RestaurantName,
    string Message,
    DateTime CreatedAtUtc);

public sealed class CreateUserFeedbackRequest
{
    [Required]
    [MaxLength(160)]
    public string RestaurantName { get; set; } = string.Empty;

    [Required]
    [MaxLength(1200)]
    public string Message { get; set; } = string.Empty;
}
