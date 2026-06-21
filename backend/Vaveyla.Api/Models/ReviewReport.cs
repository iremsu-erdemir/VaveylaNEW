namespace Vaveyla.Api.Models;

public sealed class ReviewReport
{
    public Guid ReportId { get; set; }
    public Guid ReviewId { get; set; }
    public Guid ReporterUserId { get; set; }
    public string Reason { get; set; } = string.Empty;
    public string Status { get; set; } = "pending";
    public DateTime CreatedAtUtc { get; set; }
}
