using Microsoft.Extensions.Configuration;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Services;

public static class EmailConfigurationDiagnostics
{
    private const string UserSecretsId = "vaveyla-api-local-dev";

    public const string SmtpFailedDevelopmentMessage =
        "E-posta gönderilemedi. SMTP ayarlarını kontrol edin.";

    public const string SmtpFailedProductionMessage =
        "Doğrulama kodu gönderilemedi. Lütfen daha sonra tekrar deneyin.";

    public const string SentUserMessage =
        "Doğrulama kodu e-posta adresinize gönderildi.";

    public static void LogStartupConfiguration(
        IConfiguration configuration,
        IHostEnvironment environment,
        ILogger logger)
    {
        var settings = configuration
            .GetSection(EmailSettings.SectionName)
            .Get<EmailSettings>() ?? new EmailSettings();

        var sources = ResolveActiveSources(configuration, environment);
        var passwordStatus = string.IsNullOrWhiteSpace(settings.Password) ? "BOŞ" : "DOLU (loglanmaz)";

        logger.LogInformation(
            "E-posta yapılandırması — Ortam={Environment}, Kaynaklar=[{Sources}], "
            + "SmtpHost={SmtpHost}, SmtpPort={SmtpPort}, EnableSsl={EnableSsl}, "
            + "Username={Username}, FromAddress={FromAddress}, Password={PasswordStatus}",
            environment.EnvironmentName,
            sources,
            string.IsNullOrWhiteSpace(settings.SmtpHost) ? "(boş)" : settings.SmtpHost,
            settings.SmtpPort,
            settings.EnableSsl,
            MaskOrEmpty(settings.Username),
            MaskOrEmpty(settings.FromAddress),
            passwordStatus);

        if (!EmailConfigurationValidator.IsSmtpConfigured(settings))
        {
            var missing = string.Join(", ", EmailConfigurationValidator.GetMissingFields(settings));
            logger.LogWarning(
                "SMTP yapılandırması eksik ({MissingFields}). Şifre sıfırlama e-postası gönderilemez. "
                + "Kurulum: backend/Vaveyla.Api/README.md",
                missing);
        }
    }

    public static string ResolveActiveSources(IConfiguration configuration, IHostEnvironment environment)
    {
        var sources = new List<string> { "appsettings.json" };

        if (environment.IsDevelopment())
        {
            sources.Add("appsettings.Development.json");
        }

        if (configuration is IConfigurationRoot root)
        {
            foreach (var provider in root.Providers)
            {
                var name = provider.GetType().Name;
                if (name.Contains("UserSecrets", StringComparison.OrdinalIgnoreCase))
                {
                    sources.Add("UserSecrets");
                }
                else if (name.Contains("EnvironmentVariables", StringComparison.OrdinalIgnoreCase))
                {
                    sources.Add("EnvironmentVariables");
                }
                else if (name.Contains("CommandLine", StringComparison.OrdinalIgnoreCase))
                {
                    sources.Add("CommandLine");
                }
            }
        }

        if (File.Exists(GetUserSecretsPath()))
        {
            if (!sources.Contains("UserSecrets"))
            {
                sources.Add("UserSecrets(dosya)");
            }
        }

        return string.Join(" → ", sources.Distinct());
    }

    public static string GetUserFacingSmtpErrorMessage(IHostEnvironment environment) =>
        environment.IsDevelopment()
            ? SmtpFailedDevelopmentMessage
            : SmtpFailedProductionMessage;

    private static string GetUserSecretsPath() =>
        Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "Microsoft",
            "UserSecrets",
            UserSecretsId,
            "secrets.json");

    private static string MaskOrEmpty(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return "(boş)";
        }

        var trimmed = value.Trim();
        var at = trimmed.IndexOf('@');
        if (at <= 1)
        {
            return "***";
        }

        return $"{trimmed[0]}***{trimmed[at..]}";
    }
}
