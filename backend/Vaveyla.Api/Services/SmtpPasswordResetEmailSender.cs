using MailKit.Net.Smtp;
using MailKit.Security;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;
using MimeKit;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Services;

public sealed class SmtpPasswordResetEmailSender : IPasswordResetEmailSender
{
    private readonly EmailSettings _emailSettings;
    private readonly IHostEnvironment _environment;
    private readonly ILogger<SmtpPasswordResetEmailSender> _logger;

    public SmtpPasswordResetEmailSender(
        IOptions<EmailSettings> emailSettings,
        IHostEnvironment environment,
        ILogger<SmtpPasswordResetEmailSender> logger)
    {
        _emailSettings = emailSettings.Value;
        _environment = environment;
        _logger = logger;
    }

    public async Task SendResetCodeAsync(string toEmail, string resetCode, CancellationToken cancellationToken)
    {
        var smtpConfigured =
            !string.IsNullOrWhiteSpace(_emailSettings.SmtpHost) &&
            !string.IsNullOrWhiteSpace(_emailSettings.FromAddress) &&
            !string.IsNullOrWhiteSpace(_emailSettings.Username);

        if (!smtpConfigured)
        {
            if (_environment.IsDevelopment())
            {
                _logger.LogWarning(
                    "SMTP yapılandırılmadı. Geliştirme modunda doğrulama kodu loglanıyor. "
                    + "E-posta={Email}, Kod={ResetCode}",
                    toEmail,
                    resetCode);
                return;
            }

            _logger.LogError(
                "Password reset e-postası gönderilemedi: Email:SmtpHost, FromAddress veya Username eksik.");
            throw new InvalidOperationException(
                "E-posta servisi yapılandırılmamış. Lütfen sistem yöneticisine başvurun.");
        }

        // Gmail app passwords are 16 chars; Google often shows them with spaces — SMTP auth expects no spaces.
        var username = _emailSettings.Username?.Trim() ?? string.Empty;
        var password = (_emailSettings.Password ?? string.Empty).Replace(" ", string.Empty);

        var message = new MimeMessage();
        message.From.Add(new MailboxAddress(_emailSettings.FromName, _emailSettings.FromAddress));
        message.To.Add(MailboxAddress.Parse(toEmail));
        message.Subject = "Vaveyla - Sifre Sifirlama Dogrulama Kodu";
        message.Body = new TextPart("plain") { Text = BuildBody(resetCode) };

        var secureSocket = ResolveSecureSocketOptions(_emailSettings.SmtpPort, _emailSettings.EnableSsl);

        using var client = new SmtpClient();
        try
        {
            await client.ConnectAsync(
                _emailSettings.SmtpHost,
                _emailSettings.SmtpPort,
                secureSocket,
                cancellationToken);

            if (!string.IsNullOrWhiteSpace(username))
            {
                await client.AuthenticateAsync(username, password, cancellationToken);
            }

            await client.SendAsync(message, cancellationToken);
            await client.DisconnectAsync(true, cancellationToken);
            _logger.LogInformation("Password reset code e-mail sent to {Email}.", toEmail);
        }
        catch (Exception ex)
        {
            if (_environment.IsDevelopment())
            {
                _logger.LogWarning(
                    ex,
                    "SMTP gönderilemedi (geliştirme modu). Doğrulama kodu aşağıda — "
                    + "Gmail uygulama şifresi için: https://support.google.com/accounts/answer/185833 "
                    + "E-posta={Email}, Kod={ResetCode}",
                    toEmail,
                    resetCode);
                return;
            }

            _logger.LogError(
                ex,
                "SMTP gönderimi başarısız. Host={Host}, Port={Port}, To={Email}",
                _emailSettings.SmtpHost,
                _emailSettings.SmtpPort,
                toEmail);
            throw;
        }
    }

    private static SecureSocketOptions ResolveSecureSocketOptions(int port, bool enableSsl)
    {
        if (!enableSsl)
        {
            return SecureSocketOptions.None;
        }

        return port == 465 ? SecureSocketOptions.SslOnConnect : SecureSocketOptions.StartTls;
    }

    private static string BuildBody(string resetCode)
    {
        return
            "Sifre sifirlama talebiniz alindi.\n\n" +
            $"Dogrulama kodunuz: {resetCode}\n\n" +
            "Bu kod 10 dakika boyunca gecerlidir.\n" +
            "Eger bu islemi siz yapmadiysaniz bu e-postayi dikkate almayabilirsiniz.";
    }
}
