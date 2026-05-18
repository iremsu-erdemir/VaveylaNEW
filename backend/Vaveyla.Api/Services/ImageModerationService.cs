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
        CancellationToken cancellationToken);
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
    private static readonly HashSet<string> BlockedLikelihoods = new(StringComparer.OrdinalIgnoreCase)
    {
        "LIKELY",
        "VERY_LIKELY"
    };

    private readonly IHttpClientFactory _httpClientFactory;
    private readonly IOptions<ImageModerationOptions> _options;
    private readonly ILogger<GoogleVisionImageModerationService> _logger;

    public GoogleVisionImageModerationService(
        IHttpClientFactory httpClientFactory,
        IOptions<ImageModerationOptions> options,
        ILogger<GoogleVisionImageModerationService> logger)
    {
        _httpClientFactory = httpClientFactory;
        _options = options;
        _logger = logger;
    }

    public async Task<ImageModerationResult> CheckAsync(
        Stream stream,
        string? contentType,
        CancellationToken cancellationToken)
    {
        var options = _options.Value;
        if (!options.Enabled)
        {
            return new ImageModerationResult(true);
        }

        if (string.IsNullOrWhiteSpace(options.GoogleVisionApiKey))
        {
            _logger.LogWarning("Image moderation is enabled but GoogleVisionApiKey is missing.");
            return new ImageModerationResult(false, "moderation_unavailable");
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
            $"https://vision.googleapis.com/v1/images:annotate?key={options.GoogleVisionApiKey}")
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
                return new ImageModerationResult(false, "moderation_unavailable");
            }

            using var document = JsonDocument.Parse(responseBody);
            var root = document.RootElement;
            if (!root.TryGetProperty("responses", out var responses) || responses.GetArrayLength() == 0)
            {
                return new ImageModerationResult(false, "invalid_response");
            }

            var first = responses[0];
            if (!first.TryGetProperty("safeSearchAnnotation", out var safe))
            {
                return new ImageModerationResult(false, "invalid_response");
            }

            var adult = safe.TryGetProperty("adult", out var adultNode) ? adultNode.GetString() : "UNKNOWN";
            var racy = safe.TryGetProperty("racy", out var racyNode) ? racyNode.GetString() : "UNKNOWN";
            var violence = safe.TryGetProperty("violence", out var violenceNode) ? violenceNode.GetString() : "UNKNOWN";

            if (BlockedLikelihoods.Contains(adult ?? string.Empty) ||
                BlockedLikelihoods.Contains(racy ?? string.Empty) ||
                BlockedLikelihoods.Contains(violence ?? string.Empty))
            {
                return new ImageModerationResult(false, "nsfw_detected");
            }

            return new ImageModerationResult(true);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Image moderation call failed.");
            return new ImageModerationResult(false, "moderation_unavailable");
        }
    }
}
