using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Vaveyla.Api.Models;
using Vaveyla.Api.Services;

namespace Vaveyla.Api.Controllers;

[ApiController]
[Route("api/recommendations")]
public sealed class RecommendationsController : ControllerBase
{
    private readonly IRecommendationService _recommendationService;

    public RecommendationsController(IRecommendationService recommendationService)
    {
        _recommendationService = recommendationService;
    }

    /// <summary>
    /// Kural tabanlı tatlı önerileri. Kullanıcı kimliği yalnızca JWT
    /// <see cref="ClaimTypes.NameIdentifier"/> üzerinden alınır. preference: chocolate | fruit | light | any
    /// </summary>
    [Authorize(Roles = nameof(UserRole.Customer))]
    [HttpGet]
    public async Task<ActionResult<RecommendationsResponse>> GetRecommendations(
        [FromQuery] string? preference,
        CancellationToken cancellationToken)
    {
        var userIdValue = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(userIdValue) || !Guid.TryParse(userIdValue, out var userId))
        {
            return Unauthorized();
        }

        var result = await _recommendationService.GetRecommendationsAsync(
            userId,
            preference,
            cancellationToken);

        return Ok(result);
    }
}
