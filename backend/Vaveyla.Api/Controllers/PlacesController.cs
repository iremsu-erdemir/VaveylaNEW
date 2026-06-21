using System.Globalization;
using Microsoft.AspNetCore.Mvc;
using System.Text;
using System.Text.Json;

namespace Vaveyla.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class PlacesController : ControllerBase
{
    private static readonly HttpClient HttpClient = new HttpClient();
    private readonly string _googleApiKey;
    private readonly ILogger<PlacesController> _logger;

    public PlacesController(IConfiguration configuration, ILogger<PlacesController> logger)
    {
        _googleApiKey = configuration["GoogleMaps:ApiKey"]?.Trim() ?? string.Empty;
        _logger = logger;
    }

    [HttpGet("autocomplete")]
    public async Task<IActionResult> GetPlaceAutocomplete(
        [FromQuery] string input,
        [FromQuery] string sessiontoken,
        [FromQuery] string components = "country:tr",
        [FromQuery] string language = "tr",
        [FromQuery] string types = "address",
        [FromQuery] double? latitude = null,
        [FromQuery] double? longitude = null,
        [FromQuery] int radiusMeters = 50000)
    {
        if (string.IsNullOrWhiteSpace(input))
        {
            return BadRequest("Input parameter is required.");
        }
        if (string.IsNullOrWhiteSpace(_googleApiKey))
        {
            return StatusCode(500, new { error = "Google Maps API key is missing." });
        }

        var hasBias = latitude.HasValue && longitude.HasValue &&
                      latitude.Value is >= -90 and <= 90 &&
                      longitude.Value is >= -180 and <= 180 &&
                      radiusMeters is >= 100 and <= 500000;

        try
        {
            // Legacy Places API first: many keys only have "Places API" enabled, not "Places API (New)".
            // Google returns HTTP 200 even for REQUEST_DENIED, so we must parse JSON status.
            var (legacyOk, legacyBody) = await CallLegacyAutocompleteAsync(
                input,
                sessiontoken,
                components,
                language,
                types,
                hasBias ? latitude : null,
                hasBias ? longitude : null,
                hasBias ? radiusMeters : null);
            if (legacyOk)
            {
                _logger.LogInformation("Places autocomplete: legacy API OK.");
                return Content(legacyBody ?? "{}", "application/json");
            }

            object payload;
            if (hasBias)
            {
                payload = new
                {
                    input,
                    languageCode = language,
                    sessionToken = string.IsNullOrWhiteSpace(sessiontoken) ? Guid.NewGuid().ToString() : sessiontoken,
                    includedRegionCodes = new[] { "tr" },
                    locationBias = new
                    {
                        circle = new
                        {
                            center = new { latitude = latitude!.Value, longitude = longitude!.Value },
                            radius = (double)radiusMeters,
                        },
                    },
                };
            }
            else
            {
                payload = new
                {
                    input,
                    languageCode = language,
                    sessionToken = string.IsNullOrWhiteSpace(sessiontoken) ? Guid.NewGuid().ToString() : sessiontoken,
                    includedRegionCodes = new[] { "tr" },
                };
            }

            var content = new StringContent(
                JsonSerializer.Serialize(payload),
                Encoding.UTF8,
                "application/json");
            var request = new HttpRequestMessage(
                HttpMethod.Post,
                "https://places.googleapis.com/v1/places:autocomplete");
            request.Headers.Add("X-Goog-Api-Key", _googleApiKey);
            request.Headers.Add(
                "X-Goog-FieldMask",
                "suggestions.placePrediction.placeId,suggestions.placePrediction.text.text,suggestions.placePrediction.structuredFormat.mainText.text,suggestions.placePrediction.structuredFormat.secondaryText.text");
            request.Content = content;

            var response = await HttpClient.SendAsync(request);
            var body = await response.Content.ReadAsStringAsync();

            if (response.IsSuccessStatusCode)
            {
                var transformed = TransformAutocompleteResponse(body);
                return Content(transformed, "application/json");
            }

            _logger.LogWarning("Places autocomplete (new API) failed: {Status} {Body}", response.StatusCode, body);
            return Content(legacyBody ?? "{}", "application/json");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Places autocomplete failed unexpectedly.");
            return StatusCode(500, new { error = ex.Message });
        }
    }

    [HttpGet("details")]
    public async Task<IActionResult> GetPlaceDetails(
        [FromQuery] string placeId,
        [FromQuery] string sessiontoken,
        [FromQuery] string language = "tr",
        [FromQuery] string fields = "address_components,formatted_address,geometry")
    {
        if (string.IsNullOrWhiteSpace(placeId))
        {
            return BadRequest("PlaceId parameter is required.");
        }
        if (string.IsNullOrWhiteSpace(_googleApiKey))
        {
            return StatusCode(500, new { error = "Google Maps API key is missing." });
        }

        try
        {
            var (legacyOk, legacyBody) = await CallLegacyPlaceDetailsAsync(placeId, sessiontoken ?? string.Empty, language, fields);
            if (legacyOk)
            {
                _logger.LogInformation("Places details: legacy API OK.");
                return Content(legacyBody ?? "{}", "application/json");
            }

            var request = new HttpRequestMessage(
                HttpMethod.Get,
                $"https://places.googleapis.com/v1/places/{Uri.EscapeDataString(placeId)}?languageCode={Uri.EscapeDataString(language)}&sessionToken={Uri.EscapeDataString(sessiontoken ?? Guid.NewGuid().ToString())}");
            request.Headers.Add("X-Goog-Api-Key", _googleApiKey);
            request.Headers.Add(
                "X-Goog-FieldMask",
                "id,formattedAddress,addressComponents.longText,addressComponents.shortText,addressComponents.types,location.latitude,location.longitude");

            var response = await HttpClient.SendAsync(request);
            var body = await response.Content.ReadAsStringAsync();

            if (response.IsSuccessStatusCode)
            {
                var transformed = TransformDetailsResponse(body);
                return Content(transformed, "application/json");
            }

            _logger.LogWarning("Places details (new API) failed: {Status} {Body}", response.StatusCode, body);
            return Content(legacyBody ?? "{}", "application/json");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Places details failed unexpectedly.");
            return StatusCode(500, new { error = ex.Message });
        }
    }

    [HttpGet("test")]
    public IActionResult TestEndpoint()
    {
        return Ok(new { 
            message = "Places API Proxy is working!", 
            timestamp = DateTime.UtcNow,
            hasApiKey = !string.IsNullOrEmpty(_googleApiKey)
        });
    }

    /// <summary>
    /// Calls legacy Places Autocomplete. Returns Success only when HTTP is OK and JSON status is OK or ZERO_RESULTS.
    /// Google often returns HTTP 200 with status REQUEST_DENIED — those must not be treated as success.
    /// </summary>
    private async Task<(bool Success, string? Body)> CallLegacyAutocompleteAsync(
        string input,
        string sessiontoken,
        string components,
        string language,
        string types,
        double? latitude = null,
        double? longitude = null,
        int? radiusMeters = null)
    {
        try
        {
            var token = string.IsNullOrWhiteSpace(sessiontoken) ? Guid.NewGuid().ToString() : sessiontoken;
            var url =
                "https://maps.googleapis.com/maps/api/place/autocomplete/json" +
                $"?input={Uri.EscapeDataString(input)}" +
                $"&key={Uri.EscapeDataString(_googleApiKey)}" +
                $"&sessiontoken={Uri.EscapeDataString(token)}" +
                $"&components={Uri.EscapeDataString(components)}" +
                $"&language={Uri.EscapeDataString(language)}" +
                $"&types={Uri.EscapeDataString(types)}";

            if (latitude.HasValue && longitude.HasValue && radiusMeters is > 0)
            {
                var loc =
                    latitude.Value.ToString(CultureInfo.InvariantCulture) +
                    "," +
                    longitude.Value.ToString(CultureInfo.InvariantCulture);
                url +=
                    $"&location={Uri.EscapeDataString(loc)}" +
                    $"&radius={radiusMeters.Value.ToString(CultureInfo.InvariantCulture)}";
            }

            var response = await HttpClient.GetAsync(url);
            var body = await response.Content.ReadAsStringAsync();
            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning("Places autocomplete legacy HTTP failed: {Status} {Body}", response.StatusCode, body);
                return (false, body);
            }

            if (!TryGetGooglePlacesJsonStatus(body, out var status))
            {
                _logger.LogWarning("Places autocomplete legacy: could not parse status");
                return (false, body);
            }

            if (status is "OK" or "ZERO_RESULTS")
            {
                return (true, body);
            }

            _logger.LogWarning("Places autocomplete legacy status: {Status}", status);
            return (false, body);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Places autocomplete legacy threw.");
            return (false, null);
        }
    }

    private async Task<(bool Success, string? Body)> CallLegacyPlaceDetailsAsync(
        string placeId,
        string sessiontoken,
        string language,
        string fields)
    {
        try
        {
            var token = string.IsNullOrWhiteSpace(sessiontoken) ? Guid.NewGuid().ToString() : sessiontoken;
            var url =
                "https://maps.googleapis.com/maps/api/place/details/json" +
                $"?place_id={Uri.EscapeDataString(placeId)}" +
                $"&key={Uri.EscapeDataString(_googleApiKey)}" +
                $"&sessiontoken={Uri.EscapeDataString(token)}" +
                $"&language={Uri.EscapeDataString(language)}" +
                $"&fields={Uri.EscapeDataString(fields)}";

            var response = await HttpClient.GetAsync(url);
            var body = await response.Content.ReadAsStringAsync();
            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning("Places details legacy HTTP failed: {Status} {Body}", response.StatusCode, body);
                return (false, body);
            }

            if (!TryGetGooglePlacesJsonStatus(body, out var status))
            {
                _logger.LogWarning("Places details legacy: could not parse status");
                return (false, body);
            }

            if (status == "OK")
            {
                return (true, body);
            }

            _logger.LogWarning("Places details legacy status: {Status}", status);
            return (false, body);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Places details legacy threw.");
            return (false, null);
        }
    }

    private static bool TryGetGooglePlacesJsonStatus(string body, out string? status)
    {
        status = null;
        try
        {
            using var doc = JsonDocument.Parse(body);
            if (!doc.RootElement.TryGetProperty("status", out var statusEl))
            {
                return false;
            }

            status = statusEl.GetString();
            return true;
        }
        catch
        {
            return false;
        }
    }

    private static string TransformAutocompleteResponse(string body)
    {
        using var document = JsonDocument.Parse(body);
        if (!document.RootElement.TryGetProperty("suggestions", out var suggestions) ||
            suggestions.ValueKind != JsonValueKind.Array)
        {
            return JsonSerializer.Serialize(new
            {
                status = "ZERO_RESULTS",
                predictions = Array.Empty<object>()
            });
        }

        var predictions = new List<object>();
        foreach (var suggestion in suggestions.EnumerateArray())
        {
            if (!suggestion.TryGetProperty("placePrediction", out var prediction))
            {
                continue;
            }

            var placeId = prediction.TryGetProperty("placeId", out var placeIdEl)
                ? placeIdEl.GetString() ?? string.Empty
                : string.Empty;
            var description = prediction.TryGetProperty("text", out var textEl) &&
                              textEl.TryGetProperty("text", out var descriptionEl)
                ? descriptionEl.GetString() ?? string.Empty
                : string.Empty;

            string mainText = string.Empty;
            string secondaryText = string.Empty;
            if (prediction.TryGetProperty("structuredFormat", out var formatEl))
            {
                if (formatEl.TryGetProperty("mainText", out var mainTextEl) &&
                    mainTextEl.TryGetProperty("text", out var mainTextValue))
                {
                    mainText = mainTextValue.GetString() ?? string.Empty;
                }
                if (formatEl.TryGetProperty("secondaryText", out var secondaryTextEl) &&
                    secondaryTextEl.TryGetProperty("text", out var secondaryTextValue))
                {
                    secondaryText = secondaryTextValue.GetString() ?? string.Empty;
                }
            }

            predictions.Add(new
            {
                description,
                place_id = placeId,
                structured_formatting = new
                {
                    main_text = mainText,
                    secondary_text = secondaryText
                }
            });
        }

        var status = predictions.Count == 0 ? "ZERO_RESULTS" : "OK";
        return JsonSerializer.Serialize(new
        {
            status,
            predictions
        });
    }

    private static string TransformDetailsResponse(string body)
    {
        using var document = JsonDocument.Parse(body);
        var root = document.RootElement;

        var formattedAddress = root.TryGetProperty("formattedAddress", out var addressEl)
            ? addressEl.GetString() ?? string.Empty
            : string.Empty;

        var components = new List<object>();
        if (root.TryGetProperty("addressComponents", out var componentsEl) &&
            componentsEl.ValueKind == JsonValueKind.Array)
        {
            foreach (var component in componentsEl.EnumerateArray())
            {
                var longName = component.TryGetProperty("longText", out var longEl)
                    ? longEl.GetString() ?? string.Empty
                    : string.Empty;
                var shortName = component.TryGetProperty("shortText", out var shortEl)
                    ? shortEl.GetString() ?? string.Empty
                    : string.Empty;

                var types = new List<string>();
                if (component.TryGetProperty("types", out var typesEl) &&
                    typesEl.ValueKind == JsonValueKind.Array)
                {
                    types.AddRange(typesEl.EnumerateArray().Select(type => type.GetString() ?? string.Empty));
                }

                components.Add(new
                {
                    long_name = longName,
                    short_name = shortName,
                    types
                });
            }
        }

        double lat = 0;
        double lng = 0;
        if (root.TryGetProperty("location", out var locationEl))
        {
            if (locationEl.TryGetProperty("latitude", out var latEl) &&
                latEl.TryGetDouble(out var latitude))
            {
                lat = latitude;
            }
            if (locationEl.TryGetProperty("longitude", out var lngEl) &&
                lngEl.TryGetDouble(out var longitude))
            {
                lng = longitude;
            }
        }

        return JsonSerializer.Serialize(new
        {
            status = "OK",
            result = new
            {
                formatted_address = formattedAddress,
                address_components = components,
                geometry = new
                {
                    location = new
                    {
                        lat,
                        lng
                    }
                }
            }
        });
    }
}