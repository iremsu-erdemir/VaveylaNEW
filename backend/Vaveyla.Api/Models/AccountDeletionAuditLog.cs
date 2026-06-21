namespace Vaveyla.Api.Models;

public sealed class AccountDeletionAuditLog
{
    public Guid AuditId { get; set; }
    public Guid UserId { get; set; }
    public string Action { get; set; } = string.Empty;
    public string? IpAddress { get; set; }
    public string? UserAgent { get; set; }
    public DateTime CreatedAtUtc { get; set; }
}
