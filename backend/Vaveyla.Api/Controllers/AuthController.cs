using Microsoft.AspNetCore.Mvc;
using System.Globalization;
using System.Linq;
using System.Security.Cryptography;
using Vaveyla.Api.Data;
using Vaveyla.Api.Models;
using Vaveyla.Api.Services;

namespace Vaveyla.Api.Controllers;

[ApiController]
[Route("api/auth")]
public sealed class AuthController : ControllerBase
{
    private readonly IUserRepository _users;
    private readonly IJwtService _jwtService;
    private readonly ILogger<AuthController> _logger;
    private readonly IPasswordResetEmailSender _passwordResetEmailSender;
    private readonly IVerificationService _verification;

    public AuthController(
        IUserRepository users,
        IJwtService jwtService,
        ILogger<AuthController> logger,
        IPasswordResetEmailSender passwordResetEmailSender,
        IVerificationService verification)
    {
        _users = users;
        _jwtService = jwtService;
        _logger = logger;
        _passwordResetEmailSender = passwordResetEmailSender;
        _verification = verification;
    }

    [HttpPost("register")]
    public async Task<ActionResult<AuthResponse>> Register(
        [FromBody] RegisterRequest request,
        CancellationToken cancellationToken)
    {
        if (!request.IsPrivacyPolicyAccepted || !request.IsTermsOfServiceAccepted)
        {
            return BadRequest(new { message = "Privacy policy and terms consent are required." });
        }

        if (request.RoleId == (int)UserRole.Admin)
        {
            return BadRequest(new
            {
                message = "Sistemde zaten bir admin hesabı bulunmaktadır.",
            });
        }

        var email = request.Email.Trim().ToLowerInvariant();
        var password = request.Password.Trim();
        if (!TryValidatePassword(password, out var passwordValidationError))
        {
            return BadRequest(new { message = passwordValidationError });
        }

        var existing = await _users.GetByEmailAsync(email, cancellationToken);
        if (existing is not null)
        {
            return Conflict(new { message = "Email already registered." });
        }

        var role = (UserRole)request.RoleId;
        if (role == UserRole.Admin)
        {
            if (await _users.AnyAdminExistsAsync(cancellationToken))
            {
                return Conflict(new
                {
                    message = "Sistemde zaten bir admin hesabı bulunmaktadır.",
                });
            }
        }

        var user = new User
        {
            UserId = Guid.NewGuid(),
            FullName = request.FullName.Trim(),
            Email = email,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(password),
            Role = role,
            IsPrivacyPolicyAccepted = request.IsPrivacyPolicyAccepted,
            IsTermsOfServiceAccepted = request.IsTermsOfServiceAccepted,
            CreatedAtUtc = DateTime.UtcNow,
            NotificationEnabled = true,
        };

        await _users.CreateAsync(user, cancellationToken);

        try
        {
            await _verification.SendEmailVerificationAsync(user.UserId, cancellationToken);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Kayıt sonrası e-posta doğrulama gönderilemedi: {Email}", email);
        }

        var token = _jwtService.GenerateToken(user);
        return Ok(new AuthResponse
        {
            UserId = user.UserId,
            Role = user.Role,
            FullName = user.FullName,
            Token = token,
            IsSuspended = user.IsSuspended,
            SuspendedUntilUtc = user.SuspendedUntilUtc,
            NotificationEnabled = user.NotificationEnabled,
        });
    }

    private static bool TryValidatePassword(string password, out string? errorMessage)
    {
        if (string.IsNullOrWhiteSpace(password) || password.Length < 6)
        {
            errorMessage = "Password must be at least 6 characters long.";
            return false;
        }

        if (!password.Any(char.IsUpper))
        {
            errorMessage = "Password must contain at least one uppercase letter.";
            return false;
        }

        if (!password.Any(char.IsLower))
        {
            errorMessage = "Password must contain at least one lowercase letter.";
            return false;
        }

        if (!password.Any(char.IsDigit))
        {
            errorMessage = "Password must contain at least one number.";
            return false;
        }

        if (!password.Any(c => !char.IsLetterOrDigit(c)))
        {
            errorMessage = "Password must contain at least one special character.";
            return false;
        }

        errorMessage = null;
        return true;
    }

    [HttpPost("login")]
    public async Task<ActionResult<AuthResponse>> Login(
        [FromBody] LoginRequest request,
        CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid)
        {
            var firstError = ModelState.Values
                .SelectMany(v => v.Errors)
                .Select(e => e.ErrorMessage)
                .FirstOrDefault(m => !string.IsNullOrEmpty(m));
            return BadRequest(new
            {
                message = firstError ?? "E-posta ve şifre alanları zorunludur."
            });
        }

        var email = request.Email.Trim().ToLowerInvariant();
        var password = request.Password.Trim();
        var user = await _users.GetByEmailAsync(email, cancellationToken);
        if (user is null)
        {
            return Unauthorized(new { message = "Invalid credentials." });
        }

        var validPassword = BCrypt.Net.BCrypt.Verify(password, user.PasswordHash);
        if (!validPassword)
        {
            return Unauthorized(new { message = "Invalid credentials." });
        }

        if (user.IsPermanentlyBanned)
        {
            return Unauthorized(new { message = "Hesabınız kalıcı olarak kapatılmıştır." });
        }

        var token = _jwtService.GenerateToken(user);
        return Ok(new AuthResponse
        {
            UserId = user.UserId,
            Role = user.Role,
            FullName = user.FullName,
            Token = token,
            IsSuspended = user.IsSuspended,
            SuspendedUntilUtc = user.SuspendedUntilUtc,
            NotificationEnabled = user.NotificationEnabled,
        });
    }

    [HttpPost("forgot-password/request-code")]
    public async Task<IActionResult> RequestPasswordResetCode(
        [FromBody] ForgotPasswordRequest request,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Email))
        {
            return BadRequest(new { message = "Geçerli bir e-posta adresi girin." });
        }

        var email = request.Email.Trim().ToLowerInvariant();
        if (!email.Contains('@') || !email.Contains('.'))
        {
            return BadRequest(new { message = "Geçerli bir e-posta adresi girin." });
        }

        var user = await _users.GetByEmailAsync(email, cancellationToken);
        if (user is null)
        {
            return NotFound(new
            {
                message =
                    "Bu e-posta ile kayıtlı bir hesap bulunamadı. "
                    + "Şifre sıfırlamak için kayıt olurken kullandığınız adresi girin.",
            });
        }

        var resetCode = GenerateResetCode();

        try
        {
            await _passwordResetEmailSender.SendResetCodeAsync(
                user.Email,
                resetCode,
                cancellationToken);
        }
        catch (SmtpSendException ex)
        {
            _logger.LogWarning(
                "Şifre sıfırlama e-postası gönderilemedi; kod veritabanına yazılmadı. Email={Email}",
                email);
            return StatusCode(503, new { message = ex.UserMessage });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Şifre sıfırlama e-postası beklenmeyen hata. Email={Email}", email);
            return StatusCode(500, new
            {
                message = EmailConfigurationDiagnostics.SmtpFailedProductionMessage,
            });
        }

        var codeHash = BCrypt.Net.BCrypt.HashPassword(resetCode);
        var expiresAtUtc = DateTime.UtcNow.AddMinutes(10);
        await _users.UpdatePasswordResetChallengeAsync(
            user.UserId,
            codeHash,
            expiresAtUtc,
            cancellationToken);

        return Ok(new { message = EmailConfigurationDiagnostics.SentUserMessage });
    }

    [HttpPost("forgot-password/verify-code")]
    public async Task<IActionResult> VerifyPasswordResetCode(
        [FromBody] VerifyResetCodeRequest request,
        CancellationToken cancellationToken)
    {
        var email = request.Email.Trim().ToLowerInvariant();
        var code = request.Code.Trim();
        var user = await _users.GetByEmailAsync(email, cancellationToken);
        if (user is null || !IsValidResetCode(user, code))
        {
            return BadRequest(new { message = "Kod geçersiz veya süresi dolmuş." });
        }

        await _users.UpdatePasswordResetVerifiedAsync(
            user.UserId,
            DateTime.UtcNow,
            cancellationToken);

        return Ok(new { message = "Kod doğrulandı." });
    }

    [HttpPost("forgot-password/reset-password")]
    public async Task<IActionResult> ResetPassword(
        [FromBody] ResetPasswordRequest request,
        CancellationToken cancellationToken)
    {
        var newPassword = request.NewPassword.Trim();
        if (!TryValidatePassword(newPassword, out var passwordValidationError))
        {
            return BadRequest(new { message = passwordValidationError });
        }

        var email = request.Email.Trim().ToLowerInvariant();
        var code = request.Code.Trim();
        var user = await _users.GetByEmailAsync(email, cancellationToken);
        if (user is null || !IsValidResetCode(user, code))
        {
            return BadRequest(new { message = "Kod geçersiz veya süresi dolmuş." });
        }

        if (!string.IsNullOrWhiteSpace(user.PasswordResetTokenUsedHash) &&
            BCrypt.Net.BCrypt.Verify(code, user.PasswordResetTokenUsedHash))
        {
            return BadRequest(new { message = "Bu kod daha önce kullanılmış." });
        }

        var passwordHash = BCrypt.Net.BCrypt.HashPassword(newPassword);
        var usedTokenHash = BCrypt.Net.BCrypt.HashPassword(code);
        await _users.UpdatePasswordAndClearResetAsync(
            user.UserId,
            passwordHash,
            usedTokenHash,
            cancellationToken);

        return Ok(new { message = "Şifreniz başarıyla güncellendi." });
    }

    [HttpPost("verify-email/send")]
    public async Task<IActionResult> SendEmailVerification(
        [FromQuery] Guid userId,
        CancellationToken cancellationToken)
    {
        if (userId == Guid.Empty)
            return BadRequest(new { message = "User id is required." });

        try
        {
            await _verification.SendEmailVerificationAsync(userId, cancellationToken);
            return Ok(new { message = "Doğrulama kodu e-posta adresinize gönderildi." });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPost("verify-email")]
    public async Task<IActionResult> VerifyEmail(
        [FromQuery] Guid userId,
        [FromBody] VerifyEmailRequest request,
        CancellationToken cancellationToken)
    {
        if (userId == Guid.Empty)
            return BadRequest(new { message = "User id is required." });

        try
        {
            await _verification.VerifyEmailAsync(userId, request.Code, cancellationToken);
            return Ok(new { message = "E-posta doğrulandı." });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPost("verify-sms/send")]
    public async Task<IActionResult> SendSmsOtp(
        [FromQuery] Guid userId,
        [FromBody] SendSmsOtpRequest request,
        CancellationToken cancellationToken)
    {
        if (userId == Guid.Empty)
            return BadRequest(new { message = "User id is required." });

        try
        {
            await _verification.SendSmsOtpAsync(userId, request.Phone, cancellationToken);
            return Ok(new { message = "SMS doğrulama kodu gönderildi." });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPost("verify-sms")]
    public async Task<IActionResult> VerifySmsOtp(
        [FromQuery] Guid userId,
        [FromBody] VerifySmsOtpRequest request,
        CancellationToken cancellationToken)
    {
        if (userId == Guid.Empty)
            return BadRequest(new { message = "User id is required." });

        try
        {
            await _verification.VerifySmsOtpAsync(userId, request.Phone, request.Code, cancellationToken);
            return Ok(new { message = "Telefon doğrulandı." });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    private static string GenerateResetCode()
    {
        return RandomNumberGenerator.GetInt32(100000, 1_000_000)
            .ToString(CultureInfo.InvariantCulture);
    }

    private static bool IsValidResetCode(User user, string code)
    {
        if (string.IsNullOrWhiteSpace(code) ||
            string.IsNullOrWhiteSpace(user.PasswordResetCodeHash) ||
            user.PasswordResetCodeExpiresAtUtc is null)
        {
            return false;
        }

        if (user.PasswordResetCodeExpiresAtUtc < DateTime.UtcNow)
        {
            return false;
        }

        return BCrypt.Net.BCrypt.Verify(code, user.PasswordResetCodeHash);
    }
}
