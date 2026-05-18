using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Data;
using Vaveyla.Api.Models;
using Vaveyla.Api.Services;

namespace Vaveyla.Api.Controllers;

[ApiController]
[Route("api/admin/order-refunds")]
[Authorize(Roles = "Admin")]
public sealed class AdminOrderRefundsController : ControllerBase
{
    private readonly VaveylaDbContext _db;
    private readonly IOrderLifecycleService _lifecycle;

    public AdminOrderRefundsController(VaveylaDbContext db, IOrderLifecycleService lifecycle)
    {
        _db = db;
        _lifecycle = lifecycle;
    }

    [HttpGet]
    public async Task<ActionResult<List<object>>> List(
        [FromQuery] RefundRequestStatus? status,
        CancellationToken ct)
    {
        var query = _db.OrderRefundRequests.AsNoTracking().AsQueryable();
        if (status.HasValue)
        {
            query = query.Where(r => r.Status == status.Value);
        }

        var items = await query
            .OrderByDescending(r => r.CreatedAtUtc)
            .Take(200)
            .Select(r => new
            {
                r.RefundRequestId,
                r.OrderId,
                r.CustomerUserId,
                r.RestaurantId,
                r.Status,
                r.Reason,
                r.ReasonNote,
                r.RestaurantResponse,
                r.CreatedAtUtc,
                r.ResolvedAtUtc,
            })
            .ToListAsync(ct);

        return Ok(items);
    }

    [HttpPut("{refundRequestId:guid}/resolve")]
    public async Task<ActionResult<RefundRequestDto>> Resolve(
        [FromRoute] Guid refundRequestId,
        [FromBody] ResolveRefundRequest request,
        CancellationToken ct)
    {
        var adminId = Guid.TryParse(
            User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value,
            out var id)
            ? id
            : Guid.Empty;

        try
        {
            var result = await _lifecycle.ResolveRefundRequestAsync(
                refundRequestId,
                adminId,
                "Admin",
                request,
                ct);
            return Ok(result);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpGet("audit-logs")]
    public async Task<ActionResult<List<object>>> GetDeletionAuditLogs(
        [FromQuery] Guid? userId,
        CancellationToken ct)
    {
        var query = _db.AccountDeletionAuditLogs.AsNoTracking().AsQueryable();
        if (userId.HasValue)
        {
            query = query.Where(a => a.UserId == userId.Value);
        }

        var logs = await query
            .OrderByDescending(a => a.CreatedAtUtc)
            .Take(100)
            .Select(a => new
            {
                a.AuditId,
                a.UserId,
                a.Action,
                a.IpAddress,
                a.CreatedAtUtc,
            })
            .ToListAsync(ct);

        return Ok(logs);
    }
}
