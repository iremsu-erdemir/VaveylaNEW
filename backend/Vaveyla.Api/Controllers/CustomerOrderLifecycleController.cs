using Microsoft.AspNetCore.Mvc;
using Vaveyla.Api.Models;
using Vaveyla.Api.Services;

namespace Vaveyla.Api.Controllers;

[ApiController]
[Route("api/customer")]
public sealed class CustomerOrderLifecycleController : ControllerBase
{
    private readonly IOrderLifecycleService _lifecycle;
    private readonly IDeliveryRulesService _deliveryRules;

    public CustomerOrderLifecycleController(
        IOrderLifecycleService lifecycle,
        IDeliveryRulesService deliveryRules)
    {
        _lifecycle = lifecycle;
        _deliveryRules = deliveryRules;
    }

    [HttpGet("orders/{orderId:guid}")]
    public async Task<ActionResult<OrderDetailDto>> GetOrderDetail(
        [FromQuery] Guid customerUserId,
        [FromRoute] Guid orderId,
        CancellationToken ct)
    {
        if (customerUserId == Guid.Empty)
            return BadRequest(new { message = "Customer user id is required." });

        var detail = await _lifecycle.GetOrderDetailAsync(orderId, customerUserId, ct);
        return detail is null
            ? NotFound(new { message = "Sipariş bulunamadı." })
            : Ok(detail);
    }

    [HttpPost("orders/{orderId:guid}/cancel")]
    public async Task<IActionResult> CancelOrder(
        [FromQuery] Guid customerUserId,
        [FromRoute] Guid orderId,
        [FromBody] CancelOrderRequest request,
        CancellationToken ct)
    {
        if (customerUserId == Guid.Empty)
            return BadRequest(new { message = "Customer user id is required." });

        try
        {
            await _lifecycle.CancelOrderAsync(orderId, customerUserId, request, ct);
            return Ok(new { message = "Sipariş iptal edildi." });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPost("orders/{orderId:guid}/refund-request")]
    public async Task<ActionResult<RefundRequestDto>> CreateRefundRequest(
        [FromQuery] Guid customerUserId,
        [FromRoute] Guid orderId,
        [FromBody] CreateRefundRequestBody request,
        CancellationToken ct)
    {
        if (customerUserId == Guid.Empty)
            return BadRequest(new { message = "Customer user id is required." });

        try
        {
            var result = await _lifecycle.CreateRefundRequestAsync(orderId, customerUserId, request, ct);
            return Ok(result);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpGet("refund-requests")]
    public async Task<ActionResult<List<RefundRequestDto>>> GetRefundRequests(
        [FromQuery] Guid customerUserId,
        CancellationToken ct)
    {
        if (customerUserId == Guid.Empty)
            return BadRequest(new { message = "Customer user id is required." });

        var list = await _lifecycle.GetRefundRequestsForCustomerAsync(customerUserId, ct);
        return Ok(list);
    }

    [HttpPost("orders/{orderId:guid}/reorder")]
    public async Task<ActionResult<ReorderResultDto>> Reorder(
        [FromQuery] Guid customerUserId,
        [FromRoute] Guid orderId,
        CancellationToken ct)
    {
        if (customerUserId == Guid.Empty)
            return BadRequest(new { message = "Customer user id is required." });

        try
        {
            var result = await _lifecycle.ReorderAsync(orderId, customerUserId, ct);
            return Ok(result);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPost("delivery/validate")]
    public async Task<ActionResult<DeliveryValidationResponse>> ValidateDelivery(
        [FromBody] DeliveryValidationRequest request,
        CancellationToken ct)
    {
        var result = await _deliveryRules.ValidateDeliveryAsync(request, ct);
        return Ok(result);
    }
}
