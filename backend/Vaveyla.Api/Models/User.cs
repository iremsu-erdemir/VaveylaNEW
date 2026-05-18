namespace Vaveyla.Api.Models;

public sealed class User
{
    public Guid UserId { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? Phone { get; set; }
    public string? Address { get; set; }
    public string PasswordHash { get; set; } = string.Empty;
    public string? ProfilePhotoPath { get; set; }
    public UserRole Role { get; set; }
    public bool IsPrivacyPolicyAccepted { get; set; }
    public bool IsTermsOfServiceAccepted { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public string? PasswordResetCodeHash { get; set; }
    public DateTime? PasswordResetCodeExpiresAtUtc { get; set; }
    public DateTime? PasswordResetVerifiedAtUtc { get; set; }
    public int TotalPenaltyPoints { get; set; }
    public DateTime? SuspendedUntilUtc { get; set; }
    public bool IsPermanentlyBanned { get; set; }

    /// <summary>Push, SignalR ve uygulama içi bildirim kayıtları bu bayrak kapalıyken gönderilmez.</summary>
    public bool NotificationEnabled { get; set; } = true;

    /// <summary>Veritabanı alanı değil; anlık UTC ile süre sonu karşılaştırması.</summary>
    public bool IsSuspended =>
        SuspendedUntilUtc != null && SuspendedUntilUtc > DateTime.UtcNow;
    public List<UserAddress> Addresses { get; set; } = [];
    public List<PaymentCard> PaymentCards { get; set; } = [];
    public List<UserFeedback> Feedbacks { get; set; } = [];
}
