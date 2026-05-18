namespace Vaveyla.Api.Models;

public sealed class PaymentCard
{
    public Guid PaymentCardId { get; set; }
    public Guid UserId { get; set; }
    public string CardholderName { get; set; } = string.Empty;
    public string CardNumber { get; set; } = string.Empty;
    public string Expiration { get; set; } = string.Empty;
    public string CVC { get; set; } = string.Empty;
    public string BankName { get; set; } = string.Empty;
    public string CardAlias { get; set; } = string.Empty;
    public DateTime CreatedAtUtc { get; set; }
    public User? User { get; set; }
}
