using Microsoft.AspNetCore.Mvc;
using Vaveyla.Api.Services;

namespace Vaveyla.Api.Controllers;

[ApiController]
[Route("api/moderation")]
public sealed class ModerationController : ControllerBase
{
    private readonly IImageModerationService _imageModerationService;

    public ModerationController(IImageModerationService imageModerationService)
    {
        _imageModerationService = imageModerationService;
    }

    [HttpPost("check-image")]
    public async Task<ActionResult<object>> CheckImageModeration(
        [FromForm] IFormFile file,
        CancellationToken cancellationToken)
    {
        if (file is null || file.Length == 0)
        {
            return BadRequest(new { allowed = false, message = "File is required." });
        }

        await using var stream = file.OpenReadStream();
        var result = await _imageModerationService.CheckAsync(
            stream,
            file.ContentType,
            cancellationToken);

        return Ok(new { allowed = result.Allowed, reason = result.Reason });
    }
}
