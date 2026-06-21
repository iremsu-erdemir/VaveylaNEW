namespace Vaveyla.Api.Models;

public enum FeedbackStatus : byte
{
    New = 1,
    /// <summary>Eski kayıtlar; yeni akışta admin işlemi sonrası doğrudan <see cref="Resolved"/> kullanılır.</summary>
    InReview = 2,
    Resolved = 3,
    Rejected = 4,
}
