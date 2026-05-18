using Microsoft.AspNetCore.Mvc;
using Vaveyla.Api.Data;
using Vaveyla.Api.Exceptions;
using Vaveyla.Api.Models;
using Vaveyla.Api.Services;

namespace Vaveyla.Api.Controllers;

[ApiController]
[Route("api/customer/cart")]
public sealed class CartCalculationController : ControllerBase
{
    private readonly ICustomerCartRepository _cartRepository;
    private readonly ICartCalculationService _calculationService;

    public CartCalculationController(
        ICustomerCartRepository cartRepository,
        ICartCalculationService calculationService)
    {
        _cartRepository = cartRepository;
        _calculationService = calculationService;
    }

    [HttpPost("calculate")]
    public async Task<ActionResult<CalculateCartResponse>> CalculateCart(
        [FromQuery] Guid customerUserId,
        [FromQuery] Guid? userCouponId,
        CancellationToken cancellationToken)
    {
        if (customerUserId == Guid.Empty)
            return BadRequest(new { message = "Customer user id is required." });

        try
        {
            var cartItems = await _cartRepository.GetCartAsync(customerUserId, cancellationToken);
            if (cartItems.Count == 0)
            {
                return Ok(new CalculateCartResponse(
                    [],
                    0,
                    0,
                    0,
                    0,
                    0,
                    0));
            }

            var restaurantId = cartItems[0].RestaurantId;
            var request = new CalculateCartRequest(
                restaurantId,
                cartItems.Select(c => new CalculateCartItemRequest(
                    c.ProductId,
                    c.Quantity,
                    c.UnitPrice,
                    c.WeightKg,
                    c.SaleUnit)).ToList(),
                customerUserId,
                userCouponId);

            var result = await _calculationService.CalculateCartAsync(request, cancellationToken);
            return Ok(result);
        }
        catch (ForbiddenOperationException ex)
        {
            return StatusCode(403, new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { message = "Sepet hesaplanırken hata oluştu.", detail = ex.Message });
        }
    }
}
