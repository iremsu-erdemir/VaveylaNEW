using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Vaveyla.Api.Models;
using Vaveyla.Api.Services;

namespace Vaveyla.Api.Controllers;

[ApiController]
[Route("api/coupons")]
[AllowAnonymous]
public sealed class CouponsController : ControllerBase
{
    private readonly ICouponService _couponService;

    public CouponsController(ICouponService couponService)
    {
        _couponService = couponService;
    }

    /// <summary>Kupon kodunu gir, cüzdana ekle (onay bekleyecek).</summary>
    [HttpPost("apply-code")]
    public async Task<ActionResult<ApplyCouponCodeResponse>> ApplyCode(
        [FromQuery] Guid customerUserId,
        [FromBody] ApplyCouponCodeRequest request,
        CancellationToken ct)
    {
        if (customerUserId == Guid.Empty)
            return BadRequest(new { message = "Customer user id is required." });

        if (string.IsNullOrWhiteSpace(request.Code))
            return BadRequest(new { message = "Kupon kodu giriniz." });

        var result = await _couponService.ApplyCodeAsync(customerUserId, request.Code, ct);
        if (result == null)
            return NotFound(new { message = "Geçersiz veya süresi dolmuş kupon kodu." });

        return Ok(result);
    }

    /// <summary>Kullanıcının kuponlarını listele (Kuponlarım / Kampanyalar).</summary>
    [HttpGet("my")]
    public async Task<ActionResult<List<UserCouponDto>>> GetMyCoupons(
        [FromQuery] Guid customerUserId,
        CancellationToken ct)
    {
        if (customerUserId == Guid.Empty)
            return BadRequest(new { message = "Customer user id is required." });

        var list = await _couponService.GetMyCouponsAsync(customerUserId, ct);
        return Ok(list);
    }
}
