namespace Vaveyla.Api.Models;

public sealed class CustomerFavorite
{
    public Guid FavoriteId { get; set; }
    public Guid CustomerUserId { get; set; }
    public string FavoriteType { get; set; } = string.Empty;
    public Guid TargetId { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
}
