using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Options;

namespace Vaveyla.Api.Services;

public interface IImageModerationService
{
    Task<ImageModerationResult> CheckAsync(
        Stream stream,
        string? contentType,
        ImageModerationPurpose purpose = ImageModerationPurpose.General,
        CancellationToken cancellationToken = default);
}

public enum ImageModerationPurpose
{
    General,
    ProfilePhoto,
}

public sealed record ImageModerationResult(
    bool Allowed,
    string? Reason = null);

public sealed class ImageModerationOptions
{
    public const string SectionName = "ImageModeration";

    public bool Enabled { get; set; } = true;
    public string GoogleVisionApiKey { get; set; } = string.Empty;
}

public sealed class GoogleVisionImageModerationService : IImageModerationService
{
    private static readonly HashSet<string> GeneralBlockedLikelihoods = new(StringComparer.OrdinalIgnoreCase)
    {
        "LIKELY",
        "VERY_LIKELY",
    };

    private readonly IHttpClientFactory _httpClientFactory;
    private readonly IOptions<ImageModerationOptions> _options;
    private readonly IConfiguration _configuration;
    private readonly IHostEnvironment _environment;
    private readonly ILogger<GoogleVisionImageModerationService> _logger;

    public GoogleVisionImageModerationService(
        IHttpClientFactory httpClientFactory,
        IOptions<ImageModerationOptions> options,
        IConfiguration configuration,
        IHostEnvironment environment,
        ILogger<GoogleVisionImageModerationService> logger)
    {
        _httpClientFactory = httpClientFactory;
        _options = options;
        _configuration = configuration;
        _environment = environment;
        _logger = logger;
    }

    public async Task<ImageModerationResult> CheckAsync(
        Stream stream,
        string? contentType,
        ImageModerationPurpose purpose = ImageModerationPurpose.General,
        CancellationToken cancellationToken = default)
    {
        var options = _options.Value;
        var strictProfile = purpose == ImageModerationPurpose.ProfilePhoto;

        if (!options.Enabled)
        {
            return AllowWhenUnavailable(strictProfile, "moderation_disabled");
        }

        var apiKey = ResolveApiKey();
        if (string.IsNullOrWhiteSpace(apiKey))
        {
            _logger.LogWarning(
                "Image moderation is enabled but no Vision API key is configured.");
            return AllowWhenUnavailable(strictProfile, "moderation_unavailable");
        }

        await using var memory = new MemoryStream();
        await stream.CopyToAsync(memory, cancellationToken);
        if (memory.Length == 0)
        {
            return new ImageModerationResult(false, "empty_file");
        }

        var base64 = Convert.ToBase64String(memory.ToArray());
        var payload = new
        {
            requests = new object[]
            {
                new
                {
                    image = new { content = base64 },
                    features = new object[] { new { type = "SAFE_SEARCH_DETECTION", maxResults = 1 } }
                }
            }
        };

        var requestBody = JsonSerializer.Serialize(payload);
        var request = new HttpRequestMessage(
            HttpMethod.Post,
            $"https://vision.googleapis.com/v1/images:annotate?key={apiKey}")
        {
            Content = new StringContent(requestBody, Encoding.UTF8, "application/json")
        };
        if (!string.IsNullOrWhiteSpace(contentType))
        {
            request.Content.Headers.ContentType = MediaTypeHeaderValue.Parse("application/json");
        }

        var client = _httpClientFactory.CreateClient(nameof(GoogleVisionImageModerationService));
        try
        {
            using var response = await client.SendAsync(request, cancellationToken);
            var responseBody = await response.Content.ReadAsStringAsync(cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning(
                    "Google Vision moderation request failed. Status: {StatusCode}, Body: {Body}",
                    (int)response.StatusCode,
                    responseBody);
                return AllowWhenUnavailable(strictProfile, "moderation_unavailable");
            }

            using var document = JsonDocument.Parse(responseBody);
            var root = document.RootElement;
            if (!root.TryGetProperty("responses", out var responses) || responses.GetArrayLength() == 0)
            {
                _logger.LogWarning("Google Vision returned no responses.");
                return AllowWhenUnavailable(strictProfile, "invalid_response");
            }

            var first = responses[0];
            if (!first.TryGetProperty("safeSearchAnnotation", out var safe))
            {
                _logger.LogWarning("Google Vision response missing safeSearchAnnotation.");
                return AllowWhenUnavailable(strictProfile, "invalid_response");
            }

            var adult = safe.TryGetProperty("adult", out var adultNode) ? adultNode.GetString() : "UNKNOWN";
            var racy = safe.TryGetProperty("racy", out var racyNode) ? racyNode.GetString() : "UNKNOWN";
            var violence = safe.TryGetProperty("violence", out var violenceNode) ? violenceNode.GetString() : "UNKNOWN";

            if (strictProfile)
            {
                _logger.LogInformation(
                    "Profile photo moderation scores — adult: {Adult}, racy: {Racy}, violence: {Violence}",
                    adult,
                    racy,
                    violence);
            }

            if (IsBlocked(adult, racy, violence, strictProfile))
            {
                return new ImageModerationResult(false, "nsfw_detected");
            }

            return new ImageModerationResult(true);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Image moderation call failed.");
            return AllowWhenUnavailable(strictProfile, "moderation_unavailable");
        }
    }

    private string? ResolveApiKey()
    {
        var configured = _options.Value.GoogleVisionApiKey?.Trim();
        if (!string.IsNullOrWhiteSpace(configured))
        {
            return configured;
        }

        return _configuration["GoogleMaps:ApiKey"]?.Trim();
    }

    private ImageModerationResult AllowWhenUnavailable(bool strictProfile, string reason)
    {
        // Profil fotoğraflarında moderasyon atlanmaz — uygunsuz içerik geçmemeli.
        if (strictProfile)
        {
            _logger.LogWarning(
                "Blocking profile upload because moderation is unavailable ({Reason}).",
                reason);
            return new ImageModerationResult(false, reason);
        }

        if (_environment.IsDevelopment())
        {
            _logger.LogWarning(
                "Allowing upload in Development because moderation is unavailable ({Reason}).",
                reason);
            return new ImageModerationResult(true, "moderation_skipped");
        }

        return new ImageModerationResult(true, "moderation_skipped");
    }

    private static bool IsBlocked(string? adult, string? racy, string? violence, bool strictProfile)
    {
        if (strictProfile)
        {
            return IsProfilePhotoBlocked(adult, racy, violence);
        }

        return GeneralBlockedLikelihoods.Contains(adult ?? string.Empty) ||
               GeneralBlockedLikelihoods.Contains(violence ?? string.Empty);
    }

    /// <summary>
    /// Profil fotoğrafları: normal portrelerdeki racy LIKELY yanlış pozitiflerini önler,
    /// çıplaklık ve müstehcen içeriği kombinasyon kurallarıyla yakalar.
    /// </summary>
    private static bool IsProfilePhotoBlocked(string? adult, string? racy, string? violence)
    {
        if (IsLikelihoodAtLeast(violence, LikelihoodLevel.Likely))
        {
            return true;
        }

        if (IsLikelihoodAtLeast(adult, LikelihoodLevel.Likely))
        {
            return true;
        }

        if (IsLikelihoodAtLeast(racy, LikelihoodLevel.VeryLikely))
        {
            return true;
        }

        // İç çamaşırlı / suggestive görseller: adult + racy birlikte yükselir.
        if (IsLikelihoodAtLeast(adult, LikelihoodLevel.Possible) &&
            IsLikelihoodAtLeast(racy, LikelihoodLevel.Likely))
        {
            return true;
        }

        return false;
    }

    private enum LikelihoodLevel
    {
        VeryUnlikely = 0,
        Unlikely = 1,
        Possible = 2,
        Likely = 3,
        VeryLikely = 4,
    }

    private static LikelihoodLevel ParseLikelihood(string? value) =>
        value?.Trim().ToUpperInvariant() switch
        {
            "VERY_UNLIKELY" => LikelihoodLevel.VeryUnlikely,
            "UNLIKELY" => LikelihoodLevel.Unlikely,
            "POSSIBLE" => LikelihoodLevel.Possible,
            "LIKELY" => LikelihoodLevel.Likely,
            "VERY_LIKELY" => LikelihoodLevel.VeryLikely,
            _ => LikelihoodLevel.Unlikely,
        };

    private static bool IsLikelihoodAtLeast(string? value, LikelihoodLevel minimum) =>
        ParseLikelihood(value) >= minimum;
}
