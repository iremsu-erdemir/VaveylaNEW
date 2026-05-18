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

    public AuthController(
        IUserRepository users,
        IJwtService jwtService,
        ILogger<AuthController> logger,
        IPasswordResetEmailSender passwordResetEmailSender)
    {
        _users = users;
        _jwtService = jwtService;
        _logger = logger;
        _passwordResetEmailSender = passwordResetEmailSender;
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
        var codeHash = BCrypt.Net.BCrypt.HashPassword(resetCode);
        var expiresAtUtc = DateTime.UtcNow.AddMinutes(10);
        await _users.UpdatePasswordResetChallengeAsync(
            user.UserId,
            codeHash,
            expiresAtUtc,
            cancellationToken);

        try
        {
            await _passwordResetEmailSender.SendResetCodeAsync(
                user.Email,
                resetCode,
                cancellationToken);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Password reset e-mail could not be sent for {Email}.", email);
            return StatusCode(500, new
            {
                message = "Doğrulama kodu gönderilemedi. Lütfen daha sonra tekrar deneyin.",
            });
        }

        return Ok(new { message = "Doğrulama kodu e-posta adresinize gönderildi." });
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

        var passwordHash = BCrypt.Net.BCrypt.HashPassword(newPassword);
        await _users.UpdatePasswordAndClearResetAsync(user.UserId, passwordHash, cancellationToken);

        return Ok(new { message = "Şifreniz başarıyla güncellendi." });
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
