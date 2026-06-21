using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Data;
using Vaveyla.Api.Models;
using Vaveyla.Api.Services;

namespace Vaveyla.Api.Controllers;

[ApiController]
[Route("api/restaurant-owner/refund-requests")]
[Authorize(Roles = "RestaurantOwner")]
public sealed class RestaurantOwnerRefundsController : ControllerBase
{
    private readonly VaveylaDbContext _db;
    private readonly IRestaurantOwnerRepository _ownerRepo;
    private readonly IOrderLifecycleService _lifecycle;

    public RestaurantOwnerRefundsController(
        VaveylaDbContext db,
        IRestaurantOwnerRepository ownerRepo,
        IOrderLifecycleService lifecycle)
    {
        _db = db;
        _ownerRepo = ownerRepo;
        _lifecycle = lifecycle;
    }

    [HttpGet]
    public async Task<ActionResult<List<object>>> List(
        [FromQuery] Guid ownerUserId,
        CancellationToken ct)
    {
        var restaurant = await _ownerRepo.GetRestaurantAsync(ownerUserId, ct);
        if (restaurant is null)
        {
            return NotFound(new { message = "Restoran bulunamadı." });
        }

        var items = await _db.OrderRefundRequests.AsNoTracking()
            .Where(r => r.RestaurantId == restaurant.RestaurantId &&
                        r.Status == RefundRequestStatus.Pending)
            .OrderByDescending(r => r.CreatedAtUtc)
            .Select(r => new
            {
                r.RefundRequestId,
                r.OrderId,
                r.Reason,
                r.ReasonNote,
                r.CreatedAtUtc,
            })
            .ToListAsync(ct);

        return Ok(items);
    }

    [HttpPut("{refundRequestId:guid}/resolve")]
    public async Task<ActionResult<RefundRequestDto>> Resolve(
        [FromQuery] Guid ownerUserId,
        [FromRoute] Guid refundRequestId,
        [FromBody] ResolveRefundRequest request,
        CancellationToken ct)
    {
        var restaurant = await _ownerRepo.GetRestaurantAsync(ownerUserId, ct);
        if (restaurant is null)
        {
            return NotFound(new { message = "Restoran bulunamadı." });
        }

        var refund = await _db.OrderRefundRequests
            .FirstOrDefaultAsync(
                r => r.RefundRequestId == refundRequestId &&
                     r.RestaurantId == restaurant.RestaurantId,
                ct);
        if (refund is null)
        {
            return NotFound(new { message = "İade talebi bulunamadı." });
        }

        try
        {
            var result = await _lifecycle.ResolveRefundRequestAsync(
                refundRequestId,
                ownerUserId,
                "RestaurantOwner",
                request,
                ct);
            return Ok(result);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }
}
