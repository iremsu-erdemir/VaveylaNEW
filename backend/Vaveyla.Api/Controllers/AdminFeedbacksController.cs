using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Vaveyla.Api.DTOs;
using Vaveyla.Api.Services;

namespace Vaveyla.Api.Controllers;

[ApiController]
[Route("api/admin/feedbacks")]
[Authorize(Roles = "Admin")]
public sealed class AdminFeedbacksController : ControllerBase
{
    private readonly IFeedbackAppService _feedback;

    public AdminFeedbacksController(IFeedbackAppService feedback)
    {
        _feedback = feedback;
    }

    [HttpGet]
    public async Task<ActionResult<List<FeedbackAdminListItemDto>>> List(CancellationToken cancellationToken)
    {
        var items = await _feedback.GetAdminFeedbacksAsync(cancellationToken);
        return Ok(items);
    }

    [HttpPost("{id:int}/action")]
    public async Task<IActionResult> ApplyAction(
        [FromRoute] int id,
        [FromBody] AdminFeedbackActionRequest request,
        CancellationToken cancellationToken)
    {
        if (id <= 0)
        {
            return BadRequest(new { message = "Geçerli geri bildirim id gerekli." });
        }

        var adminIdClaim = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrEmpty(adminIdClaim) || !Guid.TryParse(adminIdClaim, out var adminId))
        {
            return Unauthorized();
        }

        try
        {
            await _feedback.ApplyAdminActionAsync(id, adminId, request, cancellationToken);
            return NoContent();
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }
}
