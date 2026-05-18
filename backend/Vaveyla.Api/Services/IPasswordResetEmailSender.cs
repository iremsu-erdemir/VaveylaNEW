namespace Vaveyla.Api.Services;

public interface IPasswordResetEmailSender
{
    /// <summary>
    /// Doğrulama kodunu gönderir. Başarısız olursa <see cref="SmtpSendException"/> fırlatır.
    /// </summary>
    Task SendResetCodeAsync(string toEmail, string resetCode, CancellationToken cancellationToken);
}
