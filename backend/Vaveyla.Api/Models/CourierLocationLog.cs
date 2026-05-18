namespace Vaveyla.Api.Models;

public sealed class CourierLocationLog
{
    public Guid CourierLocationLogId { get; set; }
    public Guid OrderId { get; set; }
    public Guid CourierUserId { get; set; }
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public DateTime TimestampUtc { get; set; }
    public DateTime CreatedAtUtc { get; set; }
}
