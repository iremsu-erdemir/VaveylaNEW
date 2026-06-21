using System.Net.Sockets;
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

    public async Task SendResetCodeAsync(
        string toEmail,
        string resetCode,
        CancellationToken cancellationToken)
    {
        if (!EmailConfigurationValidator.IsSmtpConfigured(_emailSettings))
        {
            LogDevelopmentCodeHint(toEmail, resetCode, "SMTP yapılandırması eksik");
            throw new SmtpSendException(
                EmailConfigurationDiagnostics.GetUserFacingSmtpErrorMessage(_environment),
                "Email:SmtpHost, Username, Password veya FromAddress eksik.");
        }

        var username = _emailSettings.Username.Trim();
        var password = _emailSettings.Password.Replace(" ", string.Empty).Trim();
        var fromAddress = _emailSettings.FromAddress.Trim();

        var message = new MimeMessage();
        message.From.Add(new MailboxAddress(_emailSettings.FromName, fromAddress));
        message.To.Add(MailboxAddress.Parse(toEmail));
        message.Subject = "Vaveyla - Şifre Sıfırlama Doğrulama Kodu";
        message.Body = new TextPart("plain") { Text = BuildBody(resetCode) };

        var secureSocket = ResolveSecureSocketOptions(_emailSettings.SmtpPort, _emailSettings.EnableSsl);
        var timeoutMs = Math.Clamp(_emailSettings.SmtpTimeoutSeconds, 5, 120) * 1000;

        using var client = new SmtpClient { Timeout = timeoutMs };
        using var timeoutCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeoutCts.CancelAfter(timeoutMs);

        try
        {
            await client.ConnectAsync(
                _emailSettings.SmtpHost.Trim(),
                _emailSettings.SmtpPort,
                secureSocket,
                timeoutCts.Token);

            await client.AuthenticateAsync(username, password, timeoutCts.Token);
            await client.SendAsync(message, timeoutCts.Token);
            await client.DisconnectAsync(true, timeoutCts.Token);
            _logger.LogInformation(
                "Şifre sıfırlama e-postası gönderildi. Alıcı={Email}, Host={Host}, Port={Port}",
                toEmail,
                _emailSettings.SmtpHost,
                _emailSettings.SmtpPort);
        }
        catch (Exception ex)
        {
            LogSmtpFailure(ex, toEmail, resetCode);
            throw new SmtpSendException(
                EmailConfigurationDiagnostics.GetUserFacingSmtpErrorMessage(_environment),
                ex.Message,
                ex);
        }
    }

    private void LogSmtpFailure(Exception ex, string toEmail, string resetCode)
    {
        var category = ClassifySmtpException(ex);
        _logger.LogError(
            ex,
            "SMTP gönderimi başarısız [{Category}]. Host={Host}, Port={Port}, Alıcı={Email}, "
            + "EnableSsl={EnableSsl}, ExceptionType={ExceptionType}",
            category,
            _emailSettings.SmtpHost,
            _emailSettings.SmtpPort,
            toEmail,
            _emailSettings.EnableSsl,
            ex.GetType().Name);

        if (_environment.IsDevelopment())
        {
            LogDevelopmentCodeHint(
                toEmail,
                resetCode,
                $"Hata kategorisi: {category} (yalnızca geliştirici logu; istemciye başarı dönülmez)");
        }
    }

    private void LogDevelopmentCodeHint(string toEmail, string resetCode, string reason)
    {
        if (!_environment.IsDevelopment())
        {
            return;
        }

        _logger.LogWarning(
            "[DEV-ONLY] {Reason}. Alıcı={Email}, Kod={ResetCode}. "
            + "Not: @vaveyla.com adresleri gerçek posta kutusu değildir; gerçek Gmail ile test edin.",
            reason,
            toEmail,
            resetCode);
    }

    private static string ClassifySmtpException(Exception ex)
    {
        for (var current = ex; current is not null; current = current.InnerException)
        {
            if (current is OperationCanceledException)
            {
                return "ConnectionTimeout";
            }

            if (current is SocketException socketEx)
            {
                return socketEx.SocketErrorCode switch
                {
                    SocketError.TimedOut => "ConnectionTimeout",
                    _ => "ConnectionFailed",
                };
            }

            if (current is SslHandshakeException)
            {
                return "SslTlsFailure";
            }

            if (current is AuthenticationException)
            {
                return "AuthenticationFailed";
            }

            var message = current.Message;
            if (message.Contains("535", StringComparison.OrdinalIgnoreCase) ||
                message.Contains("authentication", StringComparison.OrdinalIgnoreCase) ||
                message.Contains("credentials", StringComparison.OrdinalIgnoreCase) ||
                message.Contains("username and password", StringComparison.OrdinalIgnoreCase))
            {
                return "InvalidCredentialsOrGmailRejected";
            }

            if (message.Contains("timed out", StringComparison.OrdinalIgnoreCase) ||
                message.Contains("timeout", StringComparison.OrdinalIgnoreCase))
            {
                return "ConnectionTimeout";
            }
        }

        return "SmtpSendFailed";
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
            "Şifre sıfırlama talebiniz alındı.\n\n" +
            $"Doğrulama kodunuz: {resetCode}\n\n" +
            "Bu kod 10 dakika boyunca geçerlidir.\n" +
            "Bu işlemi siz yapmadıysanız bu e-postayı dikkate almayabilirsiniz.";
    }
}
