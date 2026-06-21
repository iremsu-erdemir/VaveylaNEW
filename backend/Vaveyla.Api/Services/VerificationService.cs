using System.Globalization;
using System.Security.Cryptography;
using Vaveyla.Api.Data;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Services;

public interface IVerificationService
{
    Task SendEmailVerificationAsync(Guid userId, CancellationToken ct = default);
    Task VerifyEmailAsync(Guid userId, string code, CancellationToken ct = default);
    Task SendSmsOtpAsync(Guid userId, string phone, CancellationToken ct = default);
    Task VerifySmsOtpAsync(Guid userId, string phone, string code, CancellationToken ct = default);
}

public sealed class VerificationService : IVerificationService
{
    private readonly IUserRepository _users;
    private readonly IPasswordResetEmailSender _emailSender;
    private readonly ILogger<VerificationService> _logger;

    public VerificationService(
        IUserRepository users,
        IPasswordResetEmailSender emailSender,
        ILogger<VerificationService> logger)
    {
        _users = users;
        _emailSender = emailSender;
        _logger = logger;
    }

    public async Task SendEmailVerificationAsync(Guid userId, CancellationToken ct = default)
    {
        var user = await _users.GetByIdAsync(userId, ct)
            ?? throw new InvalidOperationException("Kullanıcı bulunamadı.");

        if (user.EmailVerified)
        {
            throw new InvalidOperationException("E-posta zaten doğrulanmış.");
        }

        var code = GenerateCode();
        user.EmailVerificationCodeHash = BCrypt.Net.BCrypt.HashPassword(code);
        user.EmailVerificationExpiresAtUtc = DateTime.UtcNow.AddMinutes(30);
        await _users.UpdateAsync(user, ct);

        try
        {
            await _emailSender.SendResetCodeAsync(user.Email, code, ct);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "E-posta doğrulama kodu gönderilemedi: {Email}", user.Email);
            throw new InvalidOperationException(
                "Doğrulama e-postası gönderilemedi. Lütfen daha sonra tekrar deneyin.");
        }
    }

    public async Task VerifyEmailAsync(Guid userId, string code, CancellationToken ct = default)
    {
        var user = await _users.GetByIdAsync(userId, ct)
            ?? throw new InvalidOperationException("Kullanıcı bulunamadı.");

        if (!IsValidCode(user.EmailVerificationCodeHash, user.EmailVerificationExpiresAtUtc, code))
        {
            throw new InvalidOperationException("Kod geçersiz veya süresi dolmuş.");
        }

        user.EmailVerified = true;
        user.EmailVerificationCodeHash = null;
        user.EmailVerificationExpiresAtUtc = null;
        await _users.UpdateAsync(user, ct);
    }

    public async Task SendSmsOtpAsync(Guid userId, string phone, CancellationToken ct = default)
    {
        var user = await _users.GetByIdAsync(userId, ct)
            ?? throw new InvalidOperationException("Kullanıcı bulunamadı.");

        var normalizedPhone = phone.Trim();
        if (normalizedPhone.Length < 10)
        {
            throw new InvalidOperationException("Geçerli bir telefon numarası girin.");
        }

        var code = GenerateCode();
        user.Phone = normalizedPhone;
        user.SmsOtpCodeHash = BCrypt.Net.BCrypt.HashPassword(code);
        user.SmsOtpExpiresAtUtc = DateTime.UtcNow.AddMinutes(5);
        await _users.UpdateAsync(user, ct);

        // Production: entegre SMS sağlayıcı (Netgsm, Twilio vb.)
        _logger.LogInformation(
            "SMS OTP (dev): UserId={UserId} Phone={Phone} Code={Code}",
            userId,
            normalizedPhone,
            code);
    }

    public async Task VerifySmsOtpAsync(Guid userId, string phone, string code, CancellationToken ct = default)
    {
        var user = await _users.GetByIdAsync(userId, ct)
            ?? throw new InvalidOperationException("Kullanıcı bulunamadı.");

        if (!string.Equals(user.Phone?.Trim(), phone.Trim(), StringComparison.Ordinal))
        {
            throw new InvalidOperationException("Telefon numarası eşleşmiyor.");
        }

        if (!IsValidCode(user.SmsOtpCodeHash, user.SmsOtpExpiresAtUtc, code))
        {
            throw new InvalidOperationException("SMS kodu geçersiz veya süresi dolmuş.");
        }

        user.PhoneVerified = true;
        user.SmsOtpCodeHash = null;
        user.SmsOtpExpiresAtUtc = null;
        await _users.UpdateAsync(user, ct);
    }

    private static string GenerateCode() =>
        RandomNumberGenerator.GetInt32(100000, 1_000_000)
            .ToString(CultureInfo.InvariantCulture);

    private static bool IsValidCode(string? hash, DateTime? expiresAt, string code)
    {
        if (string.IsNullOrWhiteSpace(hash) || expiresAt is null || expiresAt < DateTime.UtcNow)
        {
            return false;
        }

        return BCrypt.Net.BCrypt.Verify(code.Trim(), hash);
    }
}
