using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Vaveyla.Api.DTOs;
using Vaveyla.Api.Services;

namespace Vaveyla.Api.Controllers;

[ApiController]
[Route("api/feedbacks")]
public sealed class FeedbacksController : ControllerBase
{
    private readonly IFeedbackAppService _feedback;

    public FeedbacksController(IFeedbackAppService feedback)
    {
        _feedback = feedback;
    }

    /// <summary>Müşteri şikayeti. Kimlik JWT içinden alınır; route'ta userId kullanılmaz.</summary>
    [Authorize(Roles = "Customer")]
    [HttpPost]
    public async Task<ActionResult<object>> Create([FromBody] CreateCustomerFeedbackRequest request, CancellationToken cancellationToken)
    {
        var sub = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrEmpty(sub) || !Guid.TryParse(sub, out var customerId))
        {
            return Unauthorized();
        }

        try
        {
            var id = await _feedback.CreateCustomerFeedbackAsync(customerId, request, cancellationToken);
            return Ok(new { id });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }
}
