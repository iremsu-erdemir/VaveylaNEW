using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Data;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Services;

public interface IAccountDeletionService
{
    const int GracePeriodDays = 0;

    Task<AccountDeletionStatusDto> GetStatusAsync(Guid userId, CancellationToken ct = default);
    Task ScheduleDeletionAsync(Guid userId, string password, string? ipAddress, string? userAgent, CancellationToken ct = default);
    Task CancelScheduledDeletionAsync(Guid userId, CancellationToken ct = default);
    Task ProcessDueDeletionsAsync(CancellationToken ct = default);
}

public sealed class AccountDeletionService : IAccountDeletionService
{
    private readonly VaveylaDbContext _db;
    private readonly IUserRepository _users;

    public AccountDeletionService(VaveylaDbContext db, IUserRepository users)
    {
        _db = db;
        _users = users;
    }

    public async Task<AccountDeletionStatusDto> GetStatusAsync(Guid userId, CancellationToken ct = default)
    {
        var user = await _users.GetByIdAsync(userId, ct)
            ?? throw new InvalidOperationException("Kullanıcı bulunamadı.");

        var message = user.IsDeleted
            ? "Hesabınız silinmiş ve kişisel verileriniz KVKK kapsamında anonimleştirilmiştir."
            : "Hesap silme işlemi onaylandığında kişisel verileriniz hemen anonimleştirilir. "
                + "Sipariş geçmişi yasal yükümlülükler için anonim tutulur.";

        return new AccountDeletionStatusDto(
            user.DeletionScheduledAtUtc.HasValue && !user.IsDeleted,
            user.DeletionScheduledAtUtc,
            IAccountDeletionService.GracePeriodDays,
            message);
    }

    public async Task ScheduleDeletionAsync(
        Guid userId,
        string password,
        string? ipAddress,
        string? userAgent,
        CancellationToken ct = default)
    {
        var user = await _users.GetByIdAsync(userId, ct)
            ?? throw new InvalidOperationException("Kullanıcı bulunamadı.");

        if (user.IsDeleted)
        {
            throw new InvalidOperationException("Hesap zaten silinmiş.");
        }

        if (!BCrypt.Net.BCrypt.Verify(password.Trim(), user.PasswordHash))
        {
            throw new InvalidOperationException("Şifre hatalı.");
        }

        user.DeletionScheduledAtUtc = DateTime.UtcNow;
        await _users.UpdateAsync(user, ct);
        await LogAuditAsync(userId, "DeletionScheduled", ipAddress, userAgent, ct);
        await AnonymizeUserAsync(user, ct);
    }

    public async Task CancelScheduledDeletionAsync(Guid userId, CancellationToken ct = default)
    {
        var user = await _users.GetByIdAsync(userId, ct)
            ?? throw new InvalidOperationException("Kullanıcı bulunamadı.");

        if (user.IsDeleted)
        {
            throw new InvalidOperationException("Silinmiş hesap için iptal işlemi yapılamaz.");
        }

        user.DeletionScheduledAtUtc = null;
        await _users.UpdateAsync(user, ct);
        await LogAuditAsync(userId, "DeletionCancelled", null, null, ct);
    }

    public async Task ProcessDueDeletionsAsync(CancellationToken ct = default)
    {
        var cutoff = DateTime.UtcNow.AddDays(-IAccountDeletionService.GracePeriodDays);
        var users = await _db.Users
            .Where(u => u.DeletionScheduledAtUtc != null &&
                        u.DeletionScheduledAtUtc <= cutoff &&
                        !u.IsDeleted)
            .ToListAsync(ct);

        foreach (var user in users)
        {
            await AnonymizeUserAsync(user, ct);
        }
    }

    private async Task AnonymizeUserAsync(User user, CancellationToken ct)
    {
        var anonId = Guid.NewGuid().ToString("N")[..8];
        user.AnonymizedDisplayName = $"Silinmiş Kullanıcı {anonId}";
        user.FullName = user.AnonymizedDisplayName;
        user.Email = $"deleted_{anonId}@anonymized.local";
        user.Phone = null;
        user.Address = null;
        user.ProfilePhotoPath = null;
        user.IsDeleted = true;
        user.DeletedAtUtc = DateTime.UtcNow;
        user.DeletionScheduledAtUtc = null;
        user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(Guid.NewGuid().ToString("N"));
        user.NotificationEnabled = false;

        var orders = await _db.CustomerOrders
            .Where(o => o.CustomerUserId == user.UserId)
            .ToListAsync(ct);
        foreach (var order in orders)
        {
            order.CustomerName = user.AnonymizedDisplayName;
            order.CustomerPhone = null;
            order.DeliveryAddress = "Anonimleştirildi";
            order.DeliveryAddressDetail = null;
        }

        var addresses = await _db.UserAddresses.Where(a => a.UserId == user.UserId).ToListAsync(ct);
        _db.UserAddresses.RemoveRange(addresses);

        var cards = await _db.PaymentCards.Where(c => c.UserId == user.UserId).ToListAsync(ct);
        _db.PaymentCards.RemoveRange(cards);

        await _db.SaveChangesAsync(ct);
        await LogAuditAsync(user.UserId, "AccountAnonymized", null, null, ct);
    }

    private async Task LogAuditAsync(
        Guid userId,
        string action,
        string? ipAddress,
        string? userAgent,
        CancellationToken ct)
    {
        _db.AccountDeletionAuditLogs.Add(new AccountDeletionAuditLog
        {
            AuditId = Guid.NewGuid(),
            UserId = userId,
            Action = action,
            IpAddress = ipAddress,
            UserAgent = userAgent,
            CreatedAtUtc = DateTime.UtcNow,
        });
        await _db.SaveChangesAsync(ct);
    }
}
