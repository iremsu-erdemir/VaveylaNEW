using Vaveyla.Api.Models;

namespace Vaveyla.Api.Services;

public static class EmailConfigurationValidator
{
    public static bool IsSmtpConfigured(EmailSettings settings)
    {
        return !string.IsNullOrWhiteSpace(settings.SmtpHost) &&
               !string.IsNullOrWhiteSpace(settings.FromAddress) &&
               !string.IsNullOrWhiteSpace(settings.Username) &&
               !string.IsNullOrWhiteSpace(settings.Password);
    }

    public static IReadOnlyList<string> GetMissingFields(EmailSettings settings)
    {
        var missing = new List<string>();
        if (string.IsNullOrWhiteSpace(settings.SmtpHost))
        {
            missing.Add("Email:SmtpHost");
        }

        if (string.IsNullOrWhiteSpace(settings.FromAddress))
        {
            missing.Add("Email:FromAddress");
        }

        if (string.IsNullOrWhiteSpace(settings.Username))
        {
            missing.Add("Email:Username");
        }

        if (string.IsNullOrWhiteSpace(settings.Password))
        {
            missing.Add("Email:Password");
        }

        return missing;
    }
}
