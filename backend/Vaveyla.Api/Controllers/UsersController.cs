using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;
using Vaveyla.Api.Data;
using Vaveyla.Api.DTOs;
using Vaveyla.Api.Models;
using Vaveyla.Api.Services;

namespace Vaveyla.Api.Controllers;

[ApiController]
[Route("api/users")]
public sealed class UsersController : ControllerBase
{
    private readonly IUserRepository _users;
    private readonly IWebHostEnvironment _environment;
    private readonly IImageModerationService _imageModerationService;

    public UsersController(
        IUserRepository users,
        IWebHostEnvironment environment,
        IImageModerationService imageModerationService)
    {
        _users = users;
        _environment = environment;
        _imageModerationService = imageModerationService;
    }

    [HttpGet("{userId:guid}/profile")]
    public async Task<ActionResult<UserProfileDto>> GetProfile(
        [FromRoute] Guid userId,
        CancellationToken cancellationToken)
    {
        if (userId == Guid.Empty)
        {
            return BadRequest(new { message = "User id is required." });
        }

        var user = await _users.GetByIdAsync(userId, cancellationToken);
        if (user is null)
        {
            return NotFound(new { message = "User not found." });
        }

        return Ok(MapProfile(user, userId));
    }

    [HttpPost("{userId:guid}/profile-photo")]
    public async Task<ActionResult<UserProfileDto>> UploadProfilePhoto(
        [FromRoute] Guid userId,
        [FromForm] IFormFile file,
        CancellationToken cancellationToken)
    {
        if (userId == Guid.Empty)
        {
            return BadRequest(new { message = "User id is required." });
        }

        if (file.Length == 0)
        {
            return BadRequest(new { message = "File is required." });
        }

        await using (var stream = file.OpenReadStream())
        {
            var moderationResult = await _imageModerationService.CheckAsync(
                stream,
                file.ContentType,
                cancellationToken);
            if (!moderationResult.Allowed)
            {
                return BadRequest(new
                {
                    message = "Uygunsuz içerik tespit edildi. Lütfen farklı bir fotoğraf seçin."
                });
            }
        }

        var user = await _users.GetByIdAsync(userId, cancellationToken);
        if (user is null)
        {
            return NotFound(new { message = "User not found." });
        }

        var relativePath = await SaveUploadAsync(userId, file, cancellationToken);
        user.ProfilePhotoPath = relativePath;
        await _users.UpdateAsync(user, cancellationToken);
        return Ok(MapProfile(user, userId));
    }

    [HttpPut("{userId:guid}/profile")]
    public async Task<ActionResult<UserProfileDto>> UpdateProfile(
        [FromRoute] Guid userId,
        [FromBody] UpdateUserProfileRequest request,
        CancellationToken cancellationToken)
    {
        if (userId == Guid.Empty)
        {
            return BadRequest(new { message = "User id is required." });
        }

        var fullName = request.FullName?.Trim() ?? string.Empty;
        if (string.IsNullOrWhiteSpace(fullName))
        {
            return BadRequest(new { message = "Full name is required." });
        }

        var email = request.Email?.Trim().ToLowerInvariant() ?? string.Empty;
        if (string.IsNullOrWhiteSpace(email))
        {
            return BadRequest(new { message = "Email is required." });
        }

        try
        {
            _ = new System.Net.Mail.MailAddress(email);
        }
        catch
        {
            return BadRequest(new { message = "Email is invalid." });
        }

        var user = await _users.GetByIdAsync(userId, cancellationToken);
        if (user is null)
        {
            return NotFound(new { message = "User not found." });
        }

        var existingByEmail = await _users.GetByEmailAsync(email, cancellationToken);
        if (existingByEmail is not null && existingByEmail.UserId != userId)
        {
            return Conflict(new { message = "Email already registered." });
        }

        user.FullName = fullName;
        user.Email = email;
        user.Phone = string.IsNullOrWhiteSpace(request.Phone) ? null : request.Phone.Trim();
        user.Address = string.IsNullOrWhiteSpace(request.Address) ? null : request.Address.Trim();
        await _users.UpdateAsync(user, cancellationToken);
        return Ok(MapProfile(user, userId));
    }

    [HttpPatch("{userId:guid}/settings")]
    public async Task<ActionResult<UserProfileDto>> PatchSettings(
        [FromRoute] Guid userId,
        [FromBody] PatchUserSettingsRequest request,
        CancellationToken cancellationToken)
    {
        if (userId == Guid.Empty)
        {
            return BadRequest(new { message = "User id is required." });
        }

        var user = await _users.GetByIdAsync(userId, cancellationToken);
        if (user is null)
        {
            return NotFound(new { message = "User not found." });
        }

        user.NotificationEnabled = request.NotificationEnabled;
        await _users.UpdateAsync(user, cancellationToken);
        return Ok(MapProfile(user, userId));
    }

    [HttpGet("{userId:guid}/addresses")]
    public async Task<ActionResult<List<UserAddressDto>>> GetAddresses(
        [FromRoute] Guid userId,
        CancellationToken cancellationToken)
    {
        if (userId == Guid.Empty)
        {
            return BadRequest(new { message = "User id is required." });
        }

        var user = await _users.GetByIdAsync(userId, cancellationToken);
        if (user is null)
        {
            return NotFound(new { message = "User not found." });
        }

        var addresses = await _users.GetAddressesAsync(userId, cancellationToken);
        return Ok(addresses.Select(MapAddress).ToList());
    }

    [HttpPost("{userId:guid}/addresses")]
    public async Task<ActionResult<UserAddressDto>> CreateAddress(
        [FromRoute] Guid userId,
        [FromBody] CreateUserAddressRequest request,
        CancellationToken cancellationToken)
    {
        if (userId == Guid.Empty)
        {
            return BadRequest(new { message = "User id is required." });
        }

        var user = await _users.GetByIdAsync(userId, cancellationToken);
        if (user is null)
        {
            return NotFound(new { message = "User not found." });
        }

        var addresses = await _users.GetAddressesAsync(userId, cancellationToken);
        var shouldSelect = request.IsSelected || addresses.Count == 0;
        if (shouldSelect)
        {
            await ClearAddressSelectionAsync(userId, null, cancellationToken);
        }

        var address = new UserAddress
        {
            AddressId = Guid.NewGuid(),
            UserId = userId,
            Label = request.Label.Trim(),
            AddressLine = request.AddressLine.Trim(),
            AddressDetail = string.IsNullOrWhiteSpace(request.AddressDetail)
                ? null
                : request.AddressDetail.Trim(),
            IsSelected = shouldSelect
        };

        var created = await _users.AddAddressAsync(address, cancellationToken);
        return Ok(MapAddress(created));
    }

    [HttpPut("{userId:guid}/addresses/{addressId:guid}")]
    public async Task<ActionResult<UserAddressDto>> UpdateAddress(
        [FromRoute] Guid userId,
        [FromRoute] Guid addressId,
        [FromBody] UpdateUserAddressRequest request,
        CancellationToken cancellationToken)
    {
        if (userId == Guid.Empty || addressId == Guid.Empty)
        {
            return BadRequest(new { message = "User id and address id are required." });
        }

        var address = await _users.GetAddressByIdAsync(userId, addressId, cancellationToken);
        if (address is null)
        {
            return NotFound(new { message = "Address not found." });
        }

        if (request.IsSelected)
        {
            await ClearAddressSelectionAsync(userId, addressId, cancellationToken);
        }
        else if (address.IsSelected)
        {
            var allAddresses = await _users.GetAddressesAsync(userId, cancellationToken);
            var fallback = allAddresses.FirstOrDefault(x => x.AddressId != addressId);
            if (fallback is not null)
            {
                fallback.IsSelected = true;
            }
        }

        address.Label = request.Label.Trim();
        address.AddressLine = request.AddressLine.Trim();
        address.AddressDetail = string.IsNullOrWhiteSpace(request.AddressDetail)
            ? null
            : request.AddressDetail.Trim();
        address.IsSelected = request.IsSelected;

        await _users.SaveChangesAsync(cancellationToken);
        return Ok(MapAddress(address));
    }

    [HttpDelete("{userId:guid}/addresses/{addressId:guid}")]
    public async Task<IActionResult> DeleteAddress(
        [FromRoute] Guid userId,
        [FromRoute] Guid addressId,
        CancellationToken cancellationToken)
    {
        if (userId == Guid.Empty || addressId == Guid.Empty)
        {
            return BadRequest(new { message = "User id and address id are required." });
        }

        var address = await _users.GetAddressByIdAsync(userId, addressId, cancellationToken);
        if (address is null)
        {
            return NotFound(new { message = "Address not found." });
        }

        var wasSelected = address.IsSelected;
        await _users.DeleteAddressAsync(address, cancellationToken);

        if (wasSelected)
        {
            var remaining = await _users.GetAddressesAsync(userId, cancellationToken);
            var fallback = remaining.FirstOrDefault();
            if (fallback is not null)
            {
                fallback.IsSelected = true;
                await _users.SaveChangesAsync(cancellationToken);
            }
        }

        return NoContent();
    }

    [HttpGet("{userId:guid}/payment-cards")]
    public async Task<ActionResult<List<PaymentCardDto>>> GetPaymentCards(
        [FromRoute] Guid userId,
        CancellationToken cancellationToken)
    {
        if (userId == Guid.Empty)
        {
            return BadRequest(new { message = "User id is required." });
        }

        var user = await _users.GetByIdAsync(userId, cancellationToken);
        if (user is null)
        {
            return NotFound(new { message = "User not found." });
        }

        var cards = await _users.GetPaymentCardsAsync(userId, cancellationToken);
        return Ok(cards.Select(MapPaymentCard).ToList());
    }

    [HttpPost("{userId:guid}/payment-cards")]
    public async Task<ActionResult<PaymentCardDto>> CreatePaymentCard(
        [FromRoute] Guid userId,
        [FromBody] CreatePaymentCardRequest request,
        CancellationToken cancellationToken)
    {
        if (userId == Guid.Empty)
        {
            return BadRequest(new { message = "User id is required." });
        }

        var user = await _users.GetByIdAsync(userId, cancellationToken);
        if (user is null)
        {
            return NotFound(new { message = "User not found." });
        }

        var card = new PaymentCard
        {
            PaymentCardId = Guid.NewGuid(),
            UserId = userId,
            CardholderName = request.CardholderName.Trim(),
            CardNumber = request.CardNumber.Trim(),
            Expiration = request.Expiration.Trim(),
            CVC = request.CVC.Trim(),
            BankName = string.IsNullOrWhiteSpace(request.BankName)
                ? "BANK NAME"
                : request.BankName.Trim(),
            CardAlias = request.CardAlias.Trim(),
            CreatedAtUtc = DateTime.UtcNow,
        };

        var created = await _users.AddPaymentCardAsync(card, cancellationToken);
        return Ok(MapPaymentCard(created));
    }

    [HttpPut("{userId:guid}/payment-cards/{paymentCardId:guid}")]
    public async Task<ActionResult<PaymentCardDto>> UpdatePaymentCard(
        [FromRoute] Guid userId,
        [FromRoute] Guid paymentCardId,
        [FromBody] UpdatePaymentCardRequest request,
        CancellationToken cancellationToken)
    {
        if (userId == Guid.Empty || paymentCardId == Guid.Empty)
        {
            return BadRequest(new { message = "User id and payment card id are required." });
        }

        var card = await _users.GetPaymentCardByIdAsync(userId, paymentCardId, cancellationToken);
        if (card is null)
        {
            return NotFound(new { message = "Payment card not found." });
        }

        card.CardholderName = request.CardholderName.Trim();
        card.CardNumber = request.CardNumber.Trim();
        card.Expiration = request.Expiration.Trim();
        card.CVC = request.CVC.Trim();
        card.BankName = string.IsNullOrWhiteSpace(request.BankName)
            ? "BANK NAME"
            : request.BankName.Trim();
        card.CardAlias = request.CardAlias.Trim();

        await _users.SaveChangesAsync(cancellationToken);
        return Ok(MapPaymentCard(card));
    }

    [HttpDelete("{userId:guid}/payment-cards/{paymentCardId:guid}")]
    public async Task<IActionResult> DeletePaymentCard(
        [FromRoute] Guid userId,
        [FromRoute] Guid paymentCardId,
        CancellationToken cancellationToken)
    {
        if (userId == Guid.Empty || paymentCardId == Guid.Empty)
        {
            return BadRequest(new { message = "User id and payment card id are required." });
        }

        var card = await _users.GetPaymentCardByIdAsync(userId, paymentCardId, cancellationToken);
        if (card is null)
        {
            return NotFound(new { message = "Payment card not found." });
        }

        await _users.DeletePaymentCardAsync(card, cancellationToken);
        return NoContent();
    }

    private UserProfileDto MapProfile(User user, Guid routeUserId)
    {
        int? penaltyPoints = null;
        if (CallerMatchesRoute(routeUserId) &&
            user.Role is UserRole.Courier or UserRole.RestaurantOwner)
        {
            penaltyPoints = user.TotalPenaltyPoints;
        }

        return new UserProfileDto(
            user.UserId,
            user.FullName,
            user.Email,
            user.Phone,
            user.Address,
            BuildPublicUrl(user.ProfilePhotoPath),
            penaltyPoints,
            user.NotificationEnabled);
    }

    private bool CallerMatchesRoute(Guid routeUserId)
    {
        var sub = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.TryParse(sub, out var callerId) && callerId == routeUserId;
    }

    private UserAddressDto MapAddress(UserAddress address)
    {
        return new UserAddressDto(
            address.AddressId,
            address.Label,
            address.AddressLine,
            address.AddressDetail,
            address.IsSelected,
            address.CreatedAtUtc);
    }

    private PaymentCardDto MapPaymentCard(PaymentCard card)
    {
        return new PaymentCardDto(
            card.PaymentCardId,
            card.CardholderName,
            card.CardNumber,
            card.Expiration,
            card.CVC,
            card.BankName,
            card.CardAlias,
            card.CreatedAtUtc);
    }

    private string? BuildPublicUrl(string? relativePath)
    {
        if (string.IsNullOrWhiteSpace(relativePath))
        {
            return null;
        }

        return $"{Request.Scheme}://{Request.Host}/{relativePath}";
    }

    private async Task<string> SaveUploadAsync(
        Guid userId,
        IFormFile file,
        CancellationToken cancellationToken)
    {
        var extension = Path.GetExtension(file.FileName);
        var fileName = $"{Guid.NewGuid():N}{extension}";
        var relativePath = Path.Combine("uploads", "users", userId.ToString(), "profile", fileName);
        var webRootPath = _environment.WebRootPath;
        if (string.IsNullOrWhiteSpace(webRootPath))
        {
            webRootPath = Path.Combine(_environment.ContentRootPath, "wwwroot");
        }
        if (!Directory.Exists(webRootPath))
        {
            Directory.CreateDirectory(webRootPath);
        }

        var absolutePath = Path.Combine(webRootPath, relativePath);
        var directory = Path.GetDirectoryName(absolutePath);
        if (!string.IsNullOrWhiteSpace(directory))
        {
            Directory.CreateDirectory(directory);
        }

        await using var stream = System.IO.File.Create(absolutePath);
        await file.CopyToAsync(stream, cancellationToken);
        return relativePath.Replace(Path.DirectorySeparatorChar, '/');
    }

    private async Task ClearAddressSelectionAsync(
        Guid userId,
        Guid? exceptAddressId,
        CancellationToken cancellationToken)
    {
        var addresses = await _users.GetAddressesAsync(userId, cancellationToken);
        foreach (var existing in addresses)
        {
            if (exceptAddressId.HasValue && existing.AddressId == exceptAddressId.Value)
            {
                continue;
            }

            if (existing.IsSelected)
            {
                existing.IsSelected = false;
            }
        }

        await _users.SaveChangesAsync(cancellationToken);
    }
}
