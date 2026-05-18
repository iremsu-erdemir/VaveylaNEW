using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Data;

namespace Vaveyla.Api.Controllers;

[ApiController]
[Route("api/admin/orders")]
[Authorize(Roles = "Admin")]
public sealed class AdminOrdersController : ControllerBase
{
    private readonly VaveylaDbContext _db;

    public AdminOrdersController(VaveylaDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<ActionResult<List<object>>> GetAll(
        [FromQuery] int? skip,
        [FromQuery] int? take,
        CancellationToken ct)
    {
        var query = _db.CustomerOrders
            .OrderByDescending(o => o.CreatedAtUtc)
            .AsQueryable();

        if (skip.HasValue)
            query = query.Skip(skip.Value);
        if (take.HasValue)
            query = query.Take(take.Value);

        var orders = await query
            .Select(o => new
            {
                o.OrderId,
                o.CustomerUserId,
                o.RestaurantId,
                o.Items,
                o.Total,
                o.TotalDiscount,
                o.RestaurantEarning,
                o.PlatformEarning,
                o.Status,
                o.CreatedAtUtc,
            })
            .ToListAsync(ct);

        return Ok(orders);
    }

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<object>> GetById([FromRoute] Guid id, CancellationToken ct)
    {
        var order = await _db.CustomerOrders
            .Where(o => o.OrderId == id)
            .Select(o => new
            {
                o.OrderId,
                o.CustomerUserId,
                o.RestaurantId,
                o.Items,
                o.Total,
                o.TotalDiscount,
                o.RestaurantEarning,
                o.PlatformEarning,
                o.DeliveryAddress,
                o.DeliveryAddressDetail,
                o.Status,
                o.CreatedAtUtc,
                customerPaidAmount = (decimal)o.Total,
            })
            .FirstOrDefaultAsync(ct);

        if (order == null)
            return NotFound(new { message = "Sipariş bulunamadı." });

        return Ok(order);
    }
}
