namespace Vaveyla.Api.Models;

/// <summary>Uygulanan ceza / puan kaydı (hedef kullanıcıya göre).</summary>
public sealed class Penalty
{
    public int Id { get; set; }

    public Guid UserId { get; set; }

    public int Points { get; set; }

    public PenaltyType Type { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public DateTime? SuspendedUntil { get; set; }
}
