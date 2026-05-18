using System.Collections.Generic;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Data;
using Vaveyla.Api.Models;
using Vaveyla.Api.Services;

namespace Vaveyla.Api.Controllers;

[ApiController]
[Route("api/owner")]
public sealed class RestaurantOwnerController : ControllerBase
{
    private readonly IRestaurantOwnerRepository _repository;
    private readonly ICustomerOrdersRepository _customerOrdersRepository;
    private readonly IWebHostEnvironment _environment;
    private readonly VaveylaDbContext _dbContext;
    private readonly INotificationService _notificationService;
    private readonly IUserRepository _usersRepository;
    private readonly IUserSuspensionService _suspension;
    private readonly IImageModerationService _imageModerationService;

    public RestaurantOwnerController(
        IRestaurantOwnerRepository repository,
        ICustomerOrdersRepository customerOrdersRepository,
        IWebHostEnvironment environment,
        VaveylaDbContext dbContext,
        INotificationService notificationService,
        IUserRepository usersRepository,
        IUserSuspensionService suspension,
        IImageModerationService imageModerationService)
    {
        _repository = repository;
        _customerOrdersRepository = customerOrdersRepository;
        _environment = environment;
        _dbContext = dbContext;
        _notificationService = notificationService;
        _usersRepository = usersRepository;
        _suspension = suspension;
        _imageModerationService = imageModerationService;
    }

    [HttpPost("uploads/menu")]
    [ApiExplorerSettings(IgnoreApi = true)]
    public async Task<ActionResult<object>> UploadMenuImage(
        [FromQuery] Guid ownerUserId,
        [FromForm] IFormFile file,
        CancellationToken cancellationToken)
    {
        if (ownerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Owner user id is required." });
        }

        await EnsureOwnerCanOperateAsync(ownerUserId, cancellationToken);

        if (file.Length == 0)
        {
            return BadRequest(new { message = "File is required." });
        }

        var relativePath = await SaveUploadAsync(ownerUserId, "menu", file, cancellationToken);
        return Ok(new { url = BuildPublicUrl(relativePath) });
    }

    [HttpPost("uploads/restaurant-photo")]
    [ApiExplorerSettings(IgnoreApi = true)]
    public async Task<ActionResult<object>> UploadRestaurantPhoto(
        [FromQuery] Guid ownerUserId,
        [FromForm] IFormFile file,
        CancellationToken cancellationToken)
    {
        if (ownerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Owner user id is required." });
        }

        await EnsureOwnerCanOperateAsync(ownerUserId, cancellationToken);

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

        var relativePath = await SaveUploadAsync(ownerUserId, "restaurant", file, cancellationToken);
        return Ok(new { url = BuildPublicUrl(relativePath) });
    }

    [HttpGet("menu")]
    public async Task<ActionResult<List<MenuItemDto>>> GetMenu(
        [FromQuery] Guid ownerUserId,
        CancellationToken cancellationToken)
    {
        if (ownerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Owner user id is required." });
        }

        var restaurant = await _repository.GetOrCreateRestaurantAsync(ownerUserId, cancellationToken);
        var items = await _repository.GetMenuItemsAsync(restaurant.RestaurantId, cancellationToken);
        var response = items
            .Select(item => new MenuItemDto(
                item.MenuItemId,
                item.CategoryName,
                item.Name,
                item.Price,
                item.SaleUnit,
                item.ImagePath,
                item.IsAvailable,
                item.IsFeatured))
            .ToList();
        return Ok(response);
    }

    [HttpPost("menu")]
    public async Task<ActionResult<MenuItemDto>> CreateMenuItem(
        [FromQuery] Guid ownerUserId,
        [FromBody] CreateMenuItemRequest request,
        CancellationToken cancellationToken)
    {
        if (ownerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Owner user id is required." });
        }

        await EnsureOwnerCanOperateAsync(ownerUserId, cancellationToken);

        var restaurant = await _repository.GetOrCreateRestaurantAsync(ownerUserId, cancellationToken);
        var saleUnit = request.SaleUnit is 0 or 1
            ? request.SaleUnit!.Value
            : ProductSaleUnit.PerKilogram;

        var item = new MenuItem
        {
            MenuItemId = Guid.NewGuid(),
            RestaurantId = restaurant.RestaurantId,
            CategoryName = string.IsNullOrWhiteSpace(request.CategoryName) ? null : request.CategoryName.Trim(),
            Name = request.Name.Trim(),
            Price = request.Price,
            ImagePath = request.ImagePath?.Trim() ?? string.Empty,
            IsAvailable = request.IsAvailable ?? true,
            IsFeatured = request.IsFeatured ?? false,
            SaleUnit = saleUnit,
            CreatedAtUtc = DateTime.UtcNow,
        };

        await _repository.AddMenuItemAsync(item, cancellationToken);
        return Ok(new MenuItemDto(
            item.MenuItemId,
            item.CategoryName,
            item.Name,
            item.Price,
            item.SaleUnit,
            item.ImagePath,
            item.IsAvailable,
            item.IsFeatured));
    }

    [HttpPut("menu/{menuItemId:guid}")]
    public async Task<ActionResult<MenuItemDto>> UpdateMenuItem(
        [FromQuery] Guid ownerUserId,
        [FromRoute] Guid menuItemId,
        [FromBody] UpdateMenuItemRequest request,
        CancellationToken cancellationToken)
    {
        if (ownerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Owner user id is required." });
        }

        await EnsureOwnerCanOperateAsync(ownerUserId, cancellationToken);

        var restaurant = await _repository.GetOrCreateRestaurantAsync(ownerUserId, cancellationToken);
        var item = await _repository.GetMenuItemAsync(restaurant.RestaurantId, menuItemId, cancellationToken);
        if (item is null)
        {
            return NotFound(new { message = "Menu item not found." });
        }

        if (!string.IsNullOrWhiteSpace(request.Name))
        {
            item.Name = request.Name.Trim();
        }

        if (request.Price.HasValue)
        {
            item.Price = request.Price.Value;
        }

        if (request.ImagePath is not null)
        {
            item.ImagePath = request.ImagePath;
        }

        if (request.IsAvailable.HasValue)
        {
            item.IsAvailable = request.IsAvailable.Value;
        }

        if (request.IsFeatured.HasValue)
        {
            item.IsFeatured = request.IsFeatured.Value;
        }

        if (request.CategoryName is not null)
        {
            item.CategoryName = string.IsNullOrWhiteSpace(request.CategoryName) ? null : request.CategoryName.Trim();
        }

        if (request.SaleUnit.HasValue && request.SaleUnit.Value <= 1)
        {
            item.SaleUnit = request.SaleUnit.Value;
        }

        await _repository.UpdateMenuItemAsync(item, cancellationToken);
        return Ok(new MenuItemDto(
            item.MenuItemId,
            item.CategoryName,
            item.Name,
            item.Price,
            item.SaleUnit,
            item.ImagePath,
            item.IsAvailable,
            item.IsFeatured));
    }

    [HttpDelete("menu/{menuItemId:guid}")]
    public async Task<ActionResult> DeleteMenuItem(
        [FromQuery] Guid ownerUserId,
        [FromRoute] Guid menuItemId,
        CancellationToken cancellationToken)
    {
        if (ownerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Owner user id is required." });
        }

        await EnsureOwnerCanOperateAsync(ownerUserId, cancellationToken);

        var restaurant = await _repository.GetOrCreateRestaurantAsync(ownerUserId, cancellationToken);
        var removed = await _repository.DeleteMenuItemAsync(restaurant.RestaurantId, menuItemId, cancellationToken);
        if (!removed)
        {
            return NotFound(new { message = "Menu item not found." });
        }

        return NoContent();
    }

    [HttpGet("orders")]
    public async Task<ActionResult<List<RestaurantOrderDto>>> GetOrders(
        [FromQuery] Guid ownerUserId,
        CancellationToken cancellationToken)
    {
        if (ownerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Owner user id is required." });
        }

        var restaurant = await _repository.GetOrCreateRestaurantAsync(ownerUserId, cancellationToken);
        var customerOrders = await _customerOrdersRepository.GetOrdersForRestaurantAsync(
            restaurant.RestaurantId,
            cancellationToken);
        var menuItems = await _repository.GetMenuItemsAsync(restaurant.RestaurantId, cancellationToken);
        var courierIds = customerOrders
            .Select(o => o.AssignedCourierUserId)
            .Where(x => x.HasValue)
            .Select(x => x!.Value)
            .Distinct()
            .ToList();
        var courierNames = await GetCourierNameMapAsync(courierIds, cancellationToken);
        var reassignmentOrderIds = customerOrders
            .Where(o => o.Status == CustomerOrderStatus.AwaitingCourierReassignment)
            .Select(o => o.OrderId)
            .ToList();
        var releaseReasons = await _customerOrdersRepository.GetLatestCourierRefusalReasonsByOrderIdsAsync(
            reassignmentOrderIds,
            cancellationToken);
        var response = customerOrders
            .Select(order => MapCustomerOrder(
                order,
                menuItems,
                courierNames,
                releaseReasons))
            .ToList();
        return Ok(response);
    }

    [HttpGet("couriers")]
    public async Task<ActionResult<List<CourierAccountDto>>> GetCourierAccounts(
        [FromQuery] Guid ownerUserId,
        CancellationToken cancellationToken)
    {
        if (ownerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Owner user id is required." });
        }

        _ = await _repository.GetOrCreateRestaurantAsync(ownerUserId, cancellationToken);

        var utcNow = DateTime.UtcNow;
        var couriers = await _dbContext.Users.AsNoTracking()
            .Where(u =>
                u.Role == UserRole.Courier &&
                !u.IsPermanentlyBanned &&
                (u.SuspendedUntilUtc == null || u.SuspendedUntilUtc <= utcNow))
            .OrderBy(u => u.FullName)
            .ThenBy(u => u.Email)
            .Select(u => new CourierAccountDto(
                u.UserId,
                string.IsNullOrWhiteSpace(u.FullName) ? (u.Email ?? "Kurye") : u.FullName.Trim(),
                u.Email,
                u.Phone))
            .ToListAsync(cancellationToken);

        return Ok(couriers);
    }

    [HttpPut("orders/{orderId:guid}/assign-courier")]
    public async Task<ActionResult<RestaurantOrderDto>> AssignCourierToOrder(
        [FromQuery] Guid ownerUserId,
        [FromRoute] Guid orderId,
        [FromBody] AssignCourierToOrderRequest request,
        CancellationToken cancellationToken)
    {
        if (ownerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Owner user id is required." });
        }

        if (request.CourierUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Courier user id is required." });
        }

        await EnsureOwnerCanOperateAsync(ownerUserId, cancellationToken);

        var restaurant = await _repository.GetOrCreateRestaurantAsync(ownerUserId, cancellationToken);
        var order = await _customerOrdersRepository.GetOrderAsync(orderId, cancellationToken);
        if (order is null)
        {
            return NotFound(new { message = "Order not found." });
        }

        if (order.RestaurantId != restaurant.RestaurantId)
        {
            return NotFound(new { message = "Order not found." });
        }

        var courier = await _usersRepository.GetByIdAsync(request.CourierUserId, cancellationToken);
        if (courier is null || courier.Role != UserRole.Courier)
        {
            return BadRequest(new { message = "Geçerli bir kurye hesabı seçin." });
        }

        _suspension.ThrowIfOperationallyBlocked(
            courier,
            "Seçilen kurye hesabı askıda veya kalıcı olarak kapatılmış; atama yapılamaz.");

        if (order.Status == CustomerOrderStatus.Cancelled ||
            order.Status == CustomerOrderStatus.Delivered)
        {
            return BadRequest(new { message = "Bu siparişe kurye atanamaz." });
        }

        if (order.Status == CustomerOrderStatus.InTransit)
        {
            return BadRequest(new { message = "Sipariş yolda; kurye değiştirilemez." });
        }

        if (order.Status != CustomerOrderStatus.Assigned &&
            order.Status != CustomerOrderStatus.AwaitingCourierReassignment)
        {
            return BadRequest(new
            {
                message = "Kurye ataması siparişi \"Hazır\" işaretledikten (teslimata hazır) sonra yapılabilir.",
            });
        }

        order.AssignedCourierUserId = request.CourierUserId;
        order.Status = CustomerOrderStatus.Assigned;
        await _customerOrdersRepository.UpdateOrderStatusAsync(order, cancellationToken);
        await _customerOrdersRepository.ClearCourierOrderRefusalAsync(
            order.OrderId,
            request.CourierUserId,
            cancellationToken);
        await _notificationService.NotifyCourierAcceptedAsync(
            order,
            cancellationToken,
            notifyOwner: false);

        var menuItems = await _repository.GetMenuItemsAsync(restaurant.RestaurantId, cancellationToken);
        var courierNames = await GetCourierNameMapAsync(
            new[] { request.CourierUserId },
            cancellationToken);
        return Ok(MapCustomerOrder(order, menuItems, courierNames));
    }

    [HttpPost("orders")]
    public async Task<ActionResult<RestaurantOrderDto>> CreateOrder(
        [FromQuery] Guid ownerUserId,
        [FromBody] CreateOrderRequest request,
        CancellationToken cancellationToken)
    {
        if (ownerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Owner user id is required." });
        }

        await EnsureOwnerCanOperateAsync(ownerUserId, cancellationToken);

        var restaurant = await _repository.GetOrCreateRestaurantAsync(ownerUserId, cancellationToken);
        var status = RestaurantOrderStatus.Pending;
        if (!string.IsNullOrWhiteSpace(request.Status) &&
            !TryParseOrderStatus(request.Status, out status))
        {
            return BadRequest(new { message = "Invalid order status." });
        }
        if (request.PreparationMinutes is <= 0)
        {
            return BadRequest(new { message = "Preparation minutes must be greater than zero." });
        }

        var createdAtUtc = request.CreatedAtUtc?.ToUniversalTime() ?? DateTime.UtcNow;
        var order = new RestaurantOrder
        {
            OrderId = Guid.NewGuid(),
            RestaurantId = restaurant.RestaurantId,
            Items = request.Items.Trim(),
            ImagePath = request.ImagePath?.Trim(),
            PreparationMinutes = request.PreparationMinutes,
            Total = request.Total,
            Status = status,
            CreatedAtUtc = createdAtUtc,
        };

        await _repository.AddOrderAsync(order, cancellationToken);
        var menuItems = await _repository.GetMenuItemsAsync(restaurant.RestaurantId, cancellationToken);
        return Ok(MapOrder(order, menuItems));
    }

    [HttpPut("orders/{orderId:guid}/status")]
    public async Task<ActionResult<RestaurantOrderDto>> UpdateOrderStatus(
        [FromQuery] Guid ownerUserId,
        [FromRoute] Guid orderId,
        [FromBody] UpdateOrderStatusRequest request,
        CancellationToken cancellationToken)
    {
        if (ownerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Owner user id is required." });
        }

        var restaurant = await _repository.GetOrCreateRestaurantAsync(ownerUserId, cancellationToken);
        var order = await _customerOrdersRepository.GetOrderAsync(orderId, cancellationToken);
        if (order is null)
        {
            return NotFound(new { message = "Order not found." });
        }
        if (order.RestaurantId != restaurant.RestaurantId)
        {
            return NotFound(new { message = "Order not found." });
        }

        if (!TryParseOrderStatus(request.Status, out var status))
        {
            return BadRequest(new { message = "Invalid order status." });
        }

        if (status != RestaurantOrderStatus.Rejected)
        {
            await EnsureOwnerCanOperateAsync(ownerUserId, cancellationToken);
        }

        var previousStatus = order.Status;
        order.Status = MapRestaurantToCustomerStatus(status);
        if (status == RestaurantOrderStatus.Rejected)
        {
            var reason = request.RejectionReason?.Trim();
            order.RejectionReason = string.IsNullOrWhiteSpace(reason)
                ? "Siparişiniz reddedildi."
                : reason;
        }
        else if (order.RejectionReason != null)
        {
            order.RejectionReason = null;
        }

        await _customerOrdersRepository.UpdateOrderStatusAsync(order, cancellationToken);
        await _notificationService.NotifyOwnerOrderStatusChangedAsync(
            order,
            previousStatus,
            cancellationToken);

        // Restaurant rejection: reason stored on order + customer notification.
        if (status == RestaurantOrderStatus.Rejected)
        {
            var reason = order.RejectionReason ?? "Siparişiniz reddedildi.";

            await _notificationService.SendToUserAsync(
                order.CustomerUserId,
                NotificationType.Generic,
                "Sipariş Reddedildi",
                reason,
                order.OrderId,
                data: new Dictionary<string, object?>
                {
                    ["restaurantId"] = order.RestaurantId
                },
                cancellationToken: cancellationToken);
        }
        var menuItems = await _repository.GetMenuItemsAsync(restaurant.RestaurantId, cancellationToken);
        var nameIds = order.AssignedCourierUserId.HasValue
            ? new[] { order.AssignedCourierUserId.Value }
            : Array.Empty<Guid>();
        var courierNames = await GetCourierNameMapAsync(nameIds, cancellationToken);
        return Ok(MapCustomerOrder(order, menuItems, courierNames));
    }

    [HttpGet("settings")]
    public async Task<ActionResult<RestaurantSettingsDto>> GetSettings(
        [FromQuery] Guid ownerUserId,
        CancellationToken cancellationToken)
    {
        if (ownerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Owner user id is required." });
        }

        var restaurant = await _repository.GetOrCreateRestaurantAsync(ownerUserId, cancellationToken);
        var reviews = await _repository.GetReviewsAsync(restaurant.RestaurantId, cancellationToken);
        var campaigns = await _dbContext.Campaigns
            .AsNoTracking()
            .Where(c => c.RestaurantId == restaurant.RestaurantId)
            .OrderByDescending(c => c.CreatedAtUtc)
            .ToListAsync(cancellationToken);
        var settings = BuildSettingsDto(restaurant, reviews, campaigns);
        return Ok(settings);
    }

    [HttpPut("settings")]
    public async Task<ActionResult<RestaurantSettingsDto>> UpdateSettings(
        [FromQuery] Guid ownerUserId,
        [FromBody] UpdateRestaurantSettingsRequest request,
        CancellationToken cancellationToken)
    {
        if (ownerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Owner user id is required." });
        }

        await EnsureOwnerCanOperateAsync(ownerUserId, cancellationToken);

        var restaurant = await _repository.GetOrCreateRestaurantAsync(ownerUserId, cancellationToken);
        if (!string.IsNullOrWhiteSpace(request.RestaurantName))
        {
            restaurant.Name = request.RestaurantName.Trim();
        }

        if (!string.IsNullOrWhiteSpace(request.RestaurantType))
        {
            restaurant.Type = request.RestaurantType.Trim();
        }

        if (!string.IsNullOrWhiteSpace(request.Address))
        {
            restaurant.Address = request.Address.Trim();
        }

        if (request.Latitude.HasValue)
        {
            restaurant.Latitude = request.Latitude.Value;
        }

        if (request.Longitude.HasValue)
        {
            restaurant.Longitude = request.Longitude.Value;
        }

        if (!string.IsNullOrWhiteSpace(request.Phone))
        {
            restaurant.Phone = request.Phone.Trim();
        }

        if (!string.IsNullOrWhiteSpace(request.WorkingHours))
        {
            restaurant.WorkingHours = request.WorkingHours.Trim();
        }

        if (request.OrderNotifications.HasValue)
        {
            restaurant.OrderNotifications = request.OrderNotifications.Value;
        }

        if (request.IsOpen.HasValue)
        {
            restaurant.IsOpen = request.IsOpen.Value;
        }

        if (request.RestaurantPhotoPath is not null)
        {
            restaurant.PhotoPath = request.RestaurantPhotoPath;
        }

        if (request.RestaurantDiscountPercent.HasValue)
        {
            var pct = request.RestaurantDiscountPercent.Value;
            if (pct <= 0 || pct > 100)
            {
                restaurant.RestaurantDiscountPercent = null;
                restaurant.RestaurantDiscountApproved = false;
            }
            else
            {
                restaurant.RestaurantDiscountPercent = pct;
                restaurant.RestaurantDiscountApproved = false;
            }
        }

        await _repository.UpdateRestaurantAsync(restaurant, cancellationToken);

        var reviews = await _repository.GetReviewsAsync(restaurant.RestaurantId, cancellationToken);
        var campaigns = await _dbContext.Campaigns
            .AsNoTracking()
            .Where(c => c.RestaurantId == restaurant.RestaurantId)
            .OrderByDescending(c => c.CreatedAtUtc)
            .ToListAsync(cancellationToken);
        var settings = BuildSettingsDto(restaurant, reviews, campaigns);
        return Ok(settings);
    }

    /// <summary>Yalnızca restoran indirim yüzdesini günceller. Diğer ayarlara dokunmaz.</summary>
    [HttpPut("settings/discount")]
    public async Task<ActionResult<RestaurantSettingsDto>> UpdateDiscount(
        [FromQuery] Guid ownerUserId,
        [FromBody] UpdateDiscountRequest request,
        CancellationToken cancellationToken)
    {
        if (ownerUserId == Guid.Empty)
            return BadRequest(new { message = "Owner user id is required." });

        await EnsureOwnerCanOperateAsync(ownerUserId, cancellationToken);

        var restaurant = await _repository.GetOrCreateRestaurantAsync(ownerUserId, cancellationToken);

        if (request.RestaurantDiscountPercent.HasValue && request.RestaurantDiscountPercent.Value > 0)
        {
            var hasCampaigns = await _dbContext.Campaigns
                .AnyAsync(c => c.RestaurantId == restaurant.RestaurantId, cancellationToken);
            if (hasCampaigns)
                return BadRequest(new { message = "Zaten bir kampanyanız var. Aynı anda yalnızca bir indirim kampanyası ekleyebilirsiniz." });
        }

        decimal? newPercent = null;
        bool newApproved = false;
        if (request.RestaurantDiscountPercent.HasValue)
        {
            var pct = request.RestaurantDiscountPercent.Value;
            if (pct > 0 && pct <= 100)
            {
                newPercent = pct;
            }
        }

        restaurant.RestaurantDiscountPercent = newPercent;
        restaurant.RestaurantDiscountApproved = newApproved;
        await _repository.UpdateRestaurantAsync(restaurant, cancellationToken);

        var reviews = await _repository.GetReviewsAsync(restaurant.RestaurantId, cancellationToken);
        var campaigns = await _dbContext.Campaigns
            .AsNoTracking()
            .Where(c => c.RestaurantId == restaurant.RestaurantId)
            .OrderByDescending(c => c.CreatedAtUtc)
            .ToListAsync(cancellationToken);
        var settings = BuildSettingsDto(restaurant, reviews, campaigns);
        return Ok(settings);
    }

    /// <summary>Onaylı restoran indirimini pasifleştir veya tekrar aktifleştir. Sadece admin onayı vermiş indirimler için kullanılır.</summary>
    [HttpPut("settings/discount/toggle")]
    public async Task<ActionResult<RestaurantSettingsDto>> ToggleDiscountActive(
        [FromQuery] Guid ownerUserId,
        [FromBody] ToggleDiscountActiveRequest request,
        CancellationToken cancellationToken)
    {
        if (ownerUserId == Guid.Empty)
            return BadRequest(new { message = "Owner user id is required." });

        await EnsureOwnerCanOperateAsync(ownerUserId, cancellationToken);

        var restaurant = await _repository.GetOrCreateRestaurantAsync(ownerUserId, cancellationToken);
        if (!restaurant.RestaurantDiscountPercent.HasValue || restaurant.RestaurantDiscountPercent <= 0)
            return BadRequest(new { message = "Tanımlı indirim yok." });
        if (!restaurant.RestaurantDiscountApproved)
            return BadRequest(new { message = "İndirim henüz admin onayı bekliyor. Önce onaylanmalı." });

        restaurant.RestaurantDiscountIsActive = request.IsActive;
        await _repository.UpdateRestaurantAsync(restaurant, cancellationToken);

        var reviews = await _repository.GetReviewsAsync(restaurant.RestaurantId, cancellationToken);
        var campaigns = await _dbContext.Campaigns
            .AsNoTracking()
            .Where(c => c.RestaurantId == restaurant.RestaurantId)
            .OrderByDescending(c => c.CreatedAtUtc)
            .ToListAsync(cancellationToken);
        var settings = BuildSettingsDto(restaurant, reviews, campaigns);
        return Ok(settings);
    }

    [HttpPut("reviews/{reviewId:guid}/reply")]
    public async Task<ActionResult> UpdateReviewReply(
        [FromQuery] Guid ownerUserId,
        [FromRoute] Guid reviewId,
        [FromBody] UpdateReviewReplyRequest request,
        CancellationToken cancellationToken)
    {
        if (ownerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Owner user id is required." });
        }

        await EnsureOwnerCanOperateAsync(ownerUserId, cancellationToken);

        var restaurant = await _repository.GetOrCreateRestaurantAsync(ownerUserId, cancellationToken);
        await _repository.UpdateReviewReplyAsync(
            restaurant.RestaurantId,
            reviewId,
            request.OwnerReply.Trim(),
            cancellationToken);
        return NoContent();
    }

    [HttpGet("chats/conversations")]
    public async Task<ActionResult<List<OwnerChatConversationDto>>> GetChatConversations(
        [FromQuery] Guid ownerUserId,
        CancellationToken cancellationToken)
    {
        if (ownerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Owner user id is required." });
        }

        var restaurant = await _repository.GetOrCreateRestaurantAsync(ownerUserId, cancellationToken);
        var messages = await _dbContext.RestaurantChatMessages
            .Where(x => x.RestaurantId == restaurant.RestaurantId)
            .OrderByDescending(x => x.CreatedAtUtc)
            .ToListAsync(cancellationToken);

        var customerIds = messages
            .Select(x => x.CustomerUserId)
            .Distinct()
            .ToList();
        var customerNames = await _dbContext.Users
            .Where(x => customerIds.Contains(x.UserId))
            .ToDictionaryAsync(x => x.UserId, x => x.FullName, cancellationToken);

        var result = messages
            .GroupBy(x => x.CustomerUserId)
            .Select(group =>
            {
                var latest = group.First();
                var customerName = customerNames.TryGetValue(group.Key, out var value)
                    ? value
                    : "Müşteri";
                return new OwnerChatConversationDto(
                    group.Key,
                    customerName,
                    latest.Message,
                    latest.SenderType,
                    latest.CreatedAtUtc,
                    group.Count());
            })
            .OrderByDescending(x => x.LastMessageAtUtc)
            .ToList();

        return Ok(result);
    }

    [HttpDelete("chats/conversations/{customerUserId:guid}")]
    public async Task<ActionResult> DeleteChatConversation(
        [FromRoute] Guid customerUserId,
        [FromQuery] Guid ownerUserId,
        CancellationToken cancellationToken)
    {
        if (ownerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Owner user id is required." });
        }
        if (customerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Customer user id is required." });
        }

        await EnsureOwnerCanOperateAsync(ownerUserId, cancellationToken);

        var restaurant = await _repository.GetOrCreateRestaurantAsync(ownerUserId, cancellationToken);
        var messages = await _dbContext.RestaurantChatMessages
            .Where(x => x.RestaurantId == restaurant.RestaurantId && x.CustomerUserId == customerUserId)
            .ToListAsync(cancellationToken);
        if (messages.Count == 0)
        {
            return NotFound(new { message = "Conversation not found." });
        }

        _dbContext.RestaurantChatMessages.RemoveRange(messages);
        await _dbContext.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    [HttpGet("chats/messages")]
    public async Task<ActionResult<List<OwnerChatMessageDto>>> GetChatMessages(
        [FromQuery] Guid ownerUserId,
        [FromQuery] Guid customerUserId,
        CancellationToken cancellationToken,
        [FromQuery] int limit = 200)
    {
        if (ownerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Owner user id is required." });
        }
        if (customerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Customer user id is required." });
        }
        if (limit < 1) limit = 1;
        if (limit > 300) limit = 300;

        var restaurant = await _repository.GetOrCreateRestaurantAsync(ownerUserId, cancellationToken);
        var ownerName = await _dbContext.Users
            .Where(x => x.UserId == ownerUserId)
            .Select(x => x.FullName)
            .FirstOrDefaultAsync(cancellationToken);
        var customerName = await _dbContext.Users
            .Where(x => x.UserId == customerUserId)
            .Select(x => x.FullName)
            .FirstOrDefaultAsync(cancellationToken);

        var messages = await _dbContext.RestaurantChatMessages
            .Where(x => x.RestaurantId == restaurant.RestaurantId && x.CustomerUserId == customerUserId)
            .OrderByDescending(x => x.CreatedAtUtc)
            .Take(limit)
            .ToListAsync(cancellationToken);
        messages.Reverse();

        var response = messages
            .Select(x => new OwnerChatMessageDto(
                x.ChatMessageId,
                x.RestaurantId,
                x.CustomerUserId,
                x.SenderUserId,
                x.SenderType,
                string.Equals(x.SenderType, "restaurant", StringComparison.OrdinalIgnoreCase)
                    ? string.IsNullOrWhiteSpace(ownerName) ? "Pastane" : ownerName
                    : string.IsNullOrWhiteSpace(customerName) ? "Müşteri" : customerName,
                x.Message,
                x.CreatedAtUtc))
            .ToList();
        return Ok(response);
    }

    [HttpPost("chats/messages")]
    public async Task<ActionResult<OwnerChatMessageDto>> SendOwnerMessage(
        [FromQuery] Guid ownerUserId,
        [FromBody] OwnerSendChatMessageRequest request,
        CancellationToken cancellationToken)
    {
        if (ownerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Owner user id is required." });
        }
        if (request.CustomerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Customer user id is required." });
        }
        if (string.IsNullOrWhiteSpace(request.Message))
        {
            return BadRequest(new { message = "Message is required." });
        }

        await EnsureOwnerCanOperateAsync(ownerUserId, cancellationToken);

        var restaurant = await _repository.GetOrCreateRestaurantAsync(ownerUserId, cancellationToken);
        var customerExists = await _dbContext.Users.AnyAsync(
            x => x.UserId == request.CustomerUserId,
            cancellationToken);
        if (!customerExists)
        {
            return NotFound(new { message = "Customer not found." });
        }

        var message = new RestaurantChatMessage
        {
            ChatMessageId = Guid.NewGuid(),
            RestaurantId = restaurant.RestaurantId,
            CustomerUserId = request.CustomerUserId,
            SenderUserId = ownerUserId,
            SenderType = "restaurant",
            Message = request.Message.Trim(),
            CreatedAtUtc = DateTime.UtcNow,
        };
        _dbContext.RestaurantChatMessages.Add(message);
        await _dbContext.SaveChangesAsync(cancellationToken);

        // Notify customer about incoming restaurant message.
        if (request.CustomerUserId != Guid.Empty)
        {
            await _notificationService.SendToUserAsync(
                request.CustomerUserId,
                NotificationType.Generic,
                "Yeni sohbet mesajı",
                request.Message.Trim(),
                null,
                new Dictionary<string, object?>
                {
                    ["restaurantId"] = restaurant.RestaurantId,
                    ["ownerUserId"] = ownerUserId,
                },
                cancellationToken);
        }

        var ownerName = await _dbContext.Users
            .Where(x => x.UserId == ownerUserId)
            .Select(x => x.FullName)
            .FirstOrDefaultAsync(cancellationToken);
        var dto = new OwnerChatMessageDto(
            message.ChatMessageId,
            message.RestaurantId,
            message.CustomerUserId,
            message.SenderUserId,
            message.SenderType,
            string.IsNullOrWhiteSpace(ownerName) ? "Pastane" : ownerName,
            message.Message,
            message.CreatedAtUtc);
        return Ok(dto);
    }

    [HttpDelete("chats/messages/{messageId:guid}")]
    public async Task<ActionResult> DeleteOwnerMessage(
        [FromRoute] Guid messageId,
        [FromQuery] Guid ownerUserId,
        CancellationToken cancellationToken)
    {
        if (messageId == Guid.Empty)
        {
            return BadRequest(new { message = "Message id is required." });
        }
        if (ownerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Owner user id is required." });
        }

        await EnsureOwnerCanOperateAsync(ownerUserId, cancellationToken);

        var restaurant = await _repository.GetOrCreateRestaurantAsync(ownerUserId, cancellationToken);
        var message = await _dbContext.RestaurantChatMessages.FirstOrDefaultAsync(
            x => x.ChatMessageId == messageId &&
                 x.RestaurantId == restaurant.RestaurantId &&
                 x.SenderUserId == ownerUserId &&
                 x.SenderType == "restaurant",
            cancellationToken);
        if (message is null)
        {
            return NotFound(new { message = "Message not found or cannot be deleted." });
        }

        _dbContext.RestaurantChatMessages.Remove(message);
        await _dbContext.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    private static RestaurantOrderDto MapOrder(
        RestaurantOrder order,
        IReadOnlyList<MenuItem> menuItems)
    {
        var imagePath = !string.IsNullOrWhiteSpace(order.ImagePath)
            ? order.ImagePath.Trim()
            : ResolveOrderImagePath(order.Items, menuItems);
        return new RestaurantOrderDto(
            order.OrderId,
            order.CreatedAtUtc.ToLocalTime().ToString("HH:mm"),
            order.CreatedAtUtc.ToLocalTime().ToString("dd.MM.yyyy"),
            imagePath,
            order.Items,
            order.Total,
            order.Status.ToString().ToLowerInvariant(),
            order.PreparationMinutes,
            null,
            null,
            null,
            null,
            false);
    }

    private static RestaurantOrderDto MapCustomerOrder(
        CustomerOrder order,
        IReadOnlyList<MenuItem> menuItems,
        IReadOnlyDictionary<Guid, string>? courierNames = null,
        IReadOnlyDictionary<Guid, string>? courierReleaseReasons = null)
    {
        var imagePath = ResolveOrderImagePath(order.Items, menuItems);
        string? courierDisplay = null;
        if (order.AssignedCourierUserId.HasValue &&
            courierNames != null &&
            courierNames.TryGetValue(order.AssignedCourierUserId.Value, out var cn))
        {
            courierDisplay = cn;
        }

        var reassignmentRequired =
            order.Status == CustomerOrderStatus.AwaitingCourierReassignment;
        var canAssign = order.Status == CustomerOrderStatus.Assigned ||
                        reassignmentRequired;
        string? releaseReason = null;
        if (reassignmentRequired &&
            courierReleaseReasons != null &&
            courierReleaseReasons.TryGetValue(order.OrderId, out var rr))
        {
            releaseReason = rr;
        }

        return new RestaurantOrderDto(
            order.OrderId,
            order.CreatedAtUtc.ToLocalTime().ToString("HH:mm"),
            order.CreatedAtUtc.ToLocalTime().ToString("dd.MM.yyyy"),
            imagePath,
            order.Items,
            order.Total,
            MapCustomerToRestaurantStatus(order.Status),
            null,
            order.AssignedCourierUserId,
            courierDisplay,
            order.RejectionReason,
            MapFulfillmentStatus(order.Status),
            canAssign,
            reassignmentRequired,
            releaseReason);
    }

    private static string MapFulfillmentStatus(CustomerOrderStatus status)
    {
        return status switch
        {
            CustomerOrderStatus.Pending => "pending",
            CustomerOrderStatus.Preparing => "preparing",
            CustomerOrderStatus.Assigned => "assigned",
            CustomerOrderStatus.InTransit => "inTransit",
            CustomerOrderStatus.Delivered => "delivered",
            CustomerOrderStatus.Cancelled => "cancelled",
            CustomerOrderStatus.AwaitingCourierReassignment => "awaitingCourierReassignment",
            _ => "pending",
        };
    }

    private async Task<Dictionary<Guid, string>> GetCourierNameMapAsync(
        IReadOnlyList<Guid> courierUserIds,
        CancellationToken cancellationToken)
    {
        if (courierUserIds.Count == 0)
        {
            return new Dictionary<Guid, string>();
        }

        return await _dbContext.Users.AsNoTracking()
            .Where(u => courierUserIds.Contains(u.UserId))
            .ToDictionaryAsync(
                u => u.UserId,
                u => string.IsNullOrWhiteSpace(u.FullName)
                    ? (u.Email ?? "Kurye")
                    : u.FullName.Trim(),
                cancellationToken);
    }

    private static RestaurantSettingsDto BuildSettingsDto(
        Restaurant restaurant,
        List<RestaurantReview> reviews,
        List<Campaign>? campaigns = null)
    {
        var reviewCount = reviews.Count;
        var rating = reviewCount == 0
            ? 0
            : Math.Round(reviews.Average(x => x.Rating), 1);
        var ratingDistribution = reviews
            .GroupBy(x => (int)x.Rating)
            .ToDictionary(g => g.Key, g => g.Count());

        var activeCampaignDisplayText = BuildActiveCampaignDisplayText(restaurant, campaigns ?? new List<Campaign>());

        return new RestaurantSettingsDto
        {
            RestaurantId = restaurant.RestaurantId,
            RestaurantName = restaurant.Name,
            RestaurantType = restaurant.Type,
            Address = restaurant.Address,
            Latitude = restaurant.Latitude,
            Longitude = restaurant.Longitude,
            Phone = restaurant.Phone,
            WorkingHours = restaurant.WorkingHours,
            OrderNotifications = restaurant.OrderNotifications,
            IsOpen = restaurant.IsOpen,
            RestaurantPhotoPath = restaurant.PhotoPath,
            RestaurantDiscountPercent = restaurant.RestaurantDiscountPercent,
            RestaurantDiscountApproved = restaurant.RestaurantDiscountApproved,
            RestaurantDiscountIsActive = restaurant.RestaurantDiscountIsActive,
            ActiveCampaignDisplayText = activeCampaignDisplayText,
            ReviewCount = reviewCount,
            Rating = rating,
            RatingDistribution = ratingDistribution,
            Reviews = reviews
                .Select(review => new RestaurantReviewDto(
                    review.ReviewId,
                    review.CustomerName,
                    review.Rating,
                    review.Comment,
                    review.CreatedAtUtc.ToLocalTime().ToString("dd.MM.yyyy"),
                    review.OwnerReply))
                .ToList(),
        };
    }

    private static string? BuildActiveCampaignDisplayText(Restaurant restaurant, List<Campaign> campaigns)
    {
        if (restaurant.RestaurantDiscountPercent.HasValue && restaurant.RestaurantDiscountPercent > 0)
        {
            var status = !restaurant.RestaurantDiscountApproved ? "Onay bekliyor"
                : restaurant.RestaurantDiscountIsActive ? "Aktif" : "Pasif";
            return $"Restoran İndirimi %{restaurant.RestaurantDiscountPercent.Value:0} ({status})";
        }
        var campaign = campaigns
            .Where(c => c.TargetType == CampaignTargetType.Cart)
            .OrderByDescending(c => c.CreatedAtUtc)
            .FirstOrDefault();
        if (campaign == null) return null;
        var valueStr = campaign.DiscountType == CampaignDiscountType.Percentage
            ? $"%{campaign.DiscountValue:0}"
            : $"{campaign.DiscountValue:0}₺";
        var statusStr = campaign.Status == "Active" && campaign.IsActive ? "Aktif" : campaign.Status == "Pending" ? "Onay bekliyor" : "Pasif";
        return $"{campaign.Name} {valueStr} ({statusStr})";
    }

    private static bool TryParseOrderStatus(string status, out RestaurantOrderStatus parsed)
    {
        parsed = RestaurantOrderStatus.Pending;
        if (string.IsNullOrWhiteSpace(status))
        {
            return false;
        }

        return status.Trim().ToLowerInvariant() switch
        {
            "pending" => Assign(RestaurantOrderStatus.Pending, out parsed),
            "preparing" => Assign(RestaurantOrderStatus.Preparing, out parsed),
            "completed" => Assign(RestaurantOrderStatus.Completed, out parsed),
            "rejected" => Assign(RestaurantOrderStatus.Rejected, out parsed),
            _ => false,
        };
    }

    private static bool Assign(RestaurantOrderStatus status, out RestaurantOrderStatus parsed)
    {
        parsed = status;
        return true;
    }

    private static CustomerOrderStatus MapRestaurantToCustomerStatus(RestaurantOrderStatus status)
    {
        return status switch
        {
            RestaurantOrderStatus.Pending => CustomerOrderStatus.Pending,
            RestaurantOrderStatus.Preparing => CustomerOrderStatus.Preparing,
            // Owner "Hazir" means prepared and ready to be assigned to courier.
            RestaurantOrderStatus.Completed => CustomerOrderStatus.Assigned,
            RestaurantOrderStatus.Rejected => CustomerOrderStatus.Cancelled,
            _ => CustomerOrderStatus.Pending,
        };
    }

    private static string MapCustomerToRestaurantStatus(CustomerOrderStatus status)
    {
        return status switch
        {
            CustomerOrderStatus.Pending => "pending",
            CustomerOrderStatus.Preparing => "preparing",
            CustomerOrderStatus.Assigned => "completed",
            CustomerOrderStatus.AwaitingCourierReassignment => "completed",
            CustomerOrderStatus.InTransit => "completed",
            CustomerOrderStatus.Delivered => "completed",
            CustomerOrderStatus.Cancelled => "rejected",
            _ => "pending",
        };
    }

    private static string ResolveOrderImagePath(
        string itemsText,
        IReadOnlyList<MenuItem> menuItems)
    {
        if (string.IsNullOrWhiteSpace(itemsText) || menuItems.Count == 0)
        {
            return string.Empty;
        }

        var lowerItems = itemsText.ToLowerInvariant();
        foreach (var menuItem in menuItems)
        {
            var name = menuItem.Name?.Trim();
            if (string.IsNullOrWhiteSpace(name))
            {
                continue;
            }

            if (lowerItems.Contains(name.ToLowerInvariant()) &&
                !string.IsNullOrWhiteSpace(menuItem.ImagePath))
            {
                return menuItem.ImagePath.Trim();
            }
        }

        return menuItems
                   .FirstOrDefault(x => !string.IsNullOrWhiteSpace(x.ImagePath))
                   ?.ImagePath
                   ?.Trim()
               ?? string.Empty;
    }

    private async Task EnsureOwnerCanOperateAsync(Guid ownerUserId, CancellationToken cancellationToken)
    {
        var user = await _usersRepository.GetByIdAsync(ownerUserId, cancellationToken);
        _suspension.ThrowIfOperationallyBlocked(
            user,
            "Hesabınız askıda veya kalıcı olarak kapatılmış; pastane işlemi yapılamaz.");
    }

    private async Task<string> SaveUploadAsync(
        Guid ownerUserId,
        string folder,
        IFormFile file,
        CancellationToken cancellationToken)
    {
        var extension = Path.GetExtension(file.FileName);
        var fileName = $"{Guid.NewGuid():N}{extension}";
        var relativePath = Path.Combine("uploads", "owners", ownerUserId.ToString(), folder, fileName);
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

    private string BuildPublicUrl(string relativePath)
    {
        return $"{Request.Scheme}://{Request.Host}/{relativePath}";
    }
}
