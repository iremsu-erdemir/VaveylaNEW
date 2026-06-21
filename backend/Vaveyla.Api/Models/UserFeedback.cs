namespace Vaveyla.Api.Models;

public sealed class UserFeedback
{
    public Guid FeedbackId { get; set; }
    public Guid UserId { get; set; }
    public string RestaurantName { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public DateTime CreatedAtUtc { get; set; }
    public User? User { get; set; }
}
