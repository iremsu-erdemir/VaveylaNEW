namespace Vaveyla.Api.Services;

public interface IPasswordResetEmailSender
{
    Task SendResetCodeAsync(string toEmail, string resetCode, CancellationToken cancellationToken);
}
