namespace Vaveyla.Api.Models;

public sealed class AdminActionLog
{
    public int Id { get; set; }

    public Guid AdminUserId { get; set; }

    public AdminActionType ActionType { get; set; }

    public string Details { get; set; } = string.Empty;

    public int? RelatedFeedbackId { get; set; }

    public Guid? RelatedUserId { get; set; }

    public DateTime CreatedAtUtc { get; set; }
}
