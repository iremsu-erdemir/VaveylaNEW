using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Data;
using Vaveyla.Api.Exceptions;
using Vaveyla.Api.Models;
using Vaveyla.Api.Services;

namespace Vaveyla.Api.Controllers;

[ApiController]
[Route("api/customer")]
public sealed class CustomerOrdersController : ControllerBase
{
    private readonly ICustomerOrdersRepository _repository;
    private readonly ICustomerCartRepository _cartRepository;
    private readonly IRestaurantOwnerRepository _restaurantRepo;
    private readonly ICartCalculationService _calculationService;
    private readonly ICouponService _couponService;
    private readonly INotificationService _notificationService;
    private readonly VaveylaDbContext _dbContext;
    private readonly IUserRepository _usersRepository;
    private readonly IDeliveryRulesService _deliveryRules;
    private readonly IOrderLifecycleService _orderLifecycle;

    public CustomerOrdersController(
        ICustomerOrdersRepository repository,
        ICustomerCartRepository cartRepository,
        IRestaurantOwnerRepository restaurantRepo,
        ICartCalculationService calculationService,
        ICouponService couponService,
        INotificationService notificationService,
        VaveylaDbContext dbContext,
        IUserRepository usersRepository,
        IDeliveryRulesService deliveryRules,
        IOrderLifecycleService orderLifecycle)
    {
        _repository = repository;
        _cartRepository = cartRepository;
        _restaurantRepo = restaurantRepo;
        _calculationService = calculationService;
        _couponService = couponService;
        _notificationService = notificationService;
        _dbContext = dbContext;
        _usersRepository = usersRepository;
        _deliveryRules = deliveryRules;
        _orderLifecycle = orderLifecycle;
    }

    [HttpGet("orders")]
    public async Task<ActionResult<List<object>>> GetOrders(
        [FromQuery] Guid customerUserId,
        CancellationToken cancellationToken)
    {
        if (customerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Customer user id is required." });
        }

        var orders = await _repository.GetOrdersForCustomerAsync(customerUserId, cancellationToken);
        var restaurantIds = orders
            .Select(x => x.RestaurantId)
            .Distinct()
            .ToList();
        var menuMap = new Dictionary<Guid, List<MenuItem>>();
        var restaurantById = new Dictionary<Guid, Restaurant>();
        foreach (var restaurantId in restaurantIds)
        {
            var menuItems = await _restaurantRepo.GetMenuItemsAsync(restaurantId, cancellationToken);
            menuMap[restaurantId] = menuItems;
            var rest = await _restaurantRepo.GetRestaurantByIdAsync(restaurantId, cancellationToken);
            if (rest != null)
            {
                restaurantById[restaurantId] = rest;
            }
        }

        var courierFromChat = await CustomerOrderCourierHelper.GetCourierUserIdsFromDeliveryChatAsync(
            _dbContext,
            customerUserId,
            orders.Select(o => o.OrderId).ToList(),
            cancellationToken);

        var courierIds = orders
            .Select(o => CustomerOrderCustomerDisplay.ResolveCourierUserIdForCustomer(
                o,
                courierFromChat))
            .Where(id => id.HasValue)
            .Select(id => id!.Value)
            .Distinct()
            .ToList();
        var courierNames = courierIds.Count == 0
            ? new Dictionary<Guid, string>()
            : await _dbContext.Users.AsNoTracking()
                .Where(u => courierIds.Contains(u.UserId))
                .ToDictionaryAsync(
                    u => u.UserId,
                    u => string.IsNullOrWhiteSpace(u.FullName) ? "Kurye" : u.FullName.Trim(),
                    cancellationToken);

        var result = orders.Select(o =>
        {
            var cid = CustomerOrderCustomerDisplay.ResolveCourierUserIdForCustomer(
                o,
                courierFromChat);
            restaurantById.TryGetValue(o.RestaurantId, out var rr);
            var rLat = o.RestaurantLat ?? rr?.Latitude;
            var rLng = o.RestaurantLng ?? rr?.Longitude;
            var rAddr = !string.IsNullOrWhiteSpace(o.RestaurantAddress)
                ? o.RestaurantAddress
                : rr?.Address;
            return new
            {
                id = o.OrderId,
                restaurantId = o.RestaurantId,
                items = o.Items,
                total = o.Total,
                status = CustomerOrderCustomerDisplay.MapStatusForCustomerApp(o),
                assignedCourierUserId = o.AssignedCourierUserId,
                time = o.CreatedAtUtc.ToLocalTime().ToString("HH:mm"),
                date = o.CreatedAtUtc.ToLocalTime().ToString("dd.MM.yyyy"),
                imagePath = NormalizeImagePath(ResolveOrderImagePath(
                    o.Items,
                    menuMap.TryGetValue(o.RestaurantId, out var menuItems) ? menuItems : new List<MenuItem>())),
                preparationMinutes = (int?)null,
                customerLat = o.CustomerLat,
                customerLng = o.CustomerLng,
                courierLat = o.CourierLat,
                courierLng = o.CourierLng,
                courierLocationUpdatedAtUtc = o.CourierLocationUpdatedAtUtc,
                courierName = cid.HasValue && courierNames.TryGetValue(cid.Value, out var cn)
                    ? cn
                    : null,
                restaurantLat = rLat,
                restaurantLng = rLng,
                restaurantAddress = rAddr,
                restaurantName = string.IsNullOrWhiteSpace(rr?.Name) ? null : rr.Name.Trim(),
                deliveryAddress = o.DeliveryAddress,
                deliveryAddressDetail = o.DeliveryAddressDetail,
                customerName = string.IsNullOrWhiteSpace(o.CustomerName) ? null : o.CustomerName.Trim(),
                customerPhone = string.IsNullOrWhiteSpace(o.CustomerPhone) ? null : o.CustomerPhone.Trim(),
            };
        }).ToList();

        return Ok(result);
    }

    [HttpPost("orders")]
    public async Task<ActionResult<object>> CreateOrder(
        [FromQuery] Guid customerUserId,
        [FromBody] CreateCustomerOrderRequest request,
        CancellationToken cancellationToken)
    {
        if (customerUserId == Guid.Empty)
            return BadRequest(new { message = "Customer user id is required." });

        try
        {
            var cartItems = await _cartRepository.GetCartAsync(customerUserId, cancellationToken);
            if (cartItems.Count == 0)
                return BadRequest(new { message = "Sepet boş. Sipariş oluşturulamaz." });

            var restaurantId = cartItems[0].RestaurantId;
            var calcRequest = new CalculateCartRequest(
                restaurantId,
                cartItems.Select(c => new CalculateCartItemRequest(
                    c.ProductId,
                    c.Quantity,
                    c.UnitPrice,
                    c.WeightKg,
                    c.SaleUnit)).ToList(),
                customerUserId,
                request.UserCouponId,
                request.CustomerLat,
                request.CustomerLng);
            var calcResult = await _calculationService.CalculateCartAsync(calcRequest, cancellationToken);

            var (deliveryFee, distanceKm, isDeliverable, deliveryMessage) =
                await _deliveryRules.ComputeDeliveryAsync(
                    restaurantId,
                    request.CustomerLat,
                    request.CustomerLng,
                    calcResult.FinalPrice,
                    cancellationToken);

            if (!isDeliverable)
            {
                return BadRequest(new { message = deliveryMessage ?? "Teslimat bölgesi dışındasınız." });
            }

            var restaurantRules = await _restaurantRepo.GetRestaurantByIdAsync(restaurantId, cancellationToken);
            if (restaurantRules?.MinimumOrderAmount is > 0 &&
                calcResult.FinalPrice < restaurantRules.MinimumOrderAmount.Value)
            {
                var gap = restaurantRules.MinimumOrderAmount.Value - calcResult.FinalPrice;
                return BadRequest(new
                {
                    message = $"Minimum sipariş tutarı {restaurantRules.MinimumOrderAmount.Value:F0} TL. "
                              + $"Eksik: {gap:F0} TL.",
                });
            }

            var grandTotal = calcResult.FinalPrice + deliveryFee;

            if (request.UserCouponId.HasValue && calcResult.CouponDiscountAmount <= 0)
            {
                var message = string.IsNullOrWhiteSpace(calcResult.CouponRejectReason)
                    ? "Kupon uygulanamadı. Lütfen kupon şartlarını kontrol edin."
                    : calcResult.CouponRejectReason;
                return BadRequest(new { message });
            }

            var itemsStr = string.Join(", ", cartItems.Select(c =>
                c.SaleUnit == ProductSaleUnit.PerSlice
                    ? $"{c.Quantity}x {c.ProductName} ({c.Quantity} dilim)"
                    : $"{c.Quantity}x {c.ProductName} ({c.WeightKg} kg)"));

            var order = new CustomerOrder
            {
                OrderId = Guid.NewGuid(),
                CustomerUserId = customerUserId,
                RestaurantId = restaurantId,
                Items = itemsStr,
                Subtotal = calcResult.FinalPrice,
                DeliveryFee = deliveryFee,
                Total = (int)Math.Round(grandTotal),
                TotalDiscount = calcResult.TotalDiscount,
                RestaurantEarning = calcResult.RestaurantEarning,
                PlatformEarning = calcResult.PlatformEarning,
                DeliveryAddress = request.DeliveryAddress.Trim(),
                DeliveryAddressDetail = string.IsNullOrWhiteSpace(request.DeliveryAddressDetail) ? null : request.DeliveryAddressDetail.Trim(),
                CustomerLat = request.CustomerLat,
                CustomerLng = request.CustomerLng,
                CustomerName = request.CustomerName?.Trim(),
                CustomerPhone = request.CustomerPhone?.Trim(),
                PaymentMethod = request.PaymentMethod?.Trim(),
                OrderNotes = request.OrderNotes?.Trim(),
                Status = CustomerOrderStatus.Pending,
                CreatedAtUtc = DateTime.UtcNow,
                AppliedUserCouponId = calcResult.AppliedUserCouponId,
                CouponDiscountAmount = calcResult.CouponDiscountAmount > 0 ? calcResult.CouponDiscountAmount : null,
            };

            order.LineItems = cartItems.Select(c =>
            {
                var lineOriginal = c.SaleUnit == ProductSaleUnit.PerSlice
                    ? (decimal)c.UnitPrice * c.Quantity
                    : (decimal)c.UnitPrice * c.WeightKg * c.Quantity;
                return new CustomerOrderLineItem
                {
                    LineItemId = Guid.NewGuid(),
                    OrderId = order.OrderId,
                    ProductId = c.ProductId,
                    ProductName = c.ProductName,
                    ImagePath = c.ImagePath,
                    Quantity = c.Quantity,
                    WeightKg = c.WeightKg,
                    SaleUnit = c.SaleUnit,
                    UnitPrice = c.UnitPrice,
                    LineTotal = lineOriginal,
                };
            }).ToList();

            var restaurant = await _restaurantRepo.GetRestaurantByIdAsync(restaurantId, cancellationToken);
            if (restaurant != null)
            {
                order.RestaurantAddress = restaurant.Address;
                order.RestaurantLat = restaurant.Latitude;
                order.RestaurantLng = restaurant.Longitude;
            }

            if (string.IsNullOrWhiteSpace(order.CustomerName) ||
                string.IsNullOrWhiteSpace(order.CustomerPhone))
            {
                var user = await _usersRepository.GetByIdAsync(customerUserId, cancellationToken);
                if (user != null)
                {
                    if (string.IsNullOrWhiteSpace(order.CustomerName) &&
                        !string.IsNullOrWhiteSpace(user.FullName))
                    {
                        order.CustomerName = user.FullName.Trim();
                    }

                    if (string.IsNullOrWhiteSpace(order.CustomerPhone) &&
                        !string.IsNullOrWhiteSpace(user.Phone))
                    {
                        order.CustomerPhone = user.Phone.Trim();
                    }
                }
            }

            await _repository.CreateOrderAsync(order, cancellationToken);
            await _orderLifecycle.AppendStatusHistoryAsync(
                order,
                CustomerOrderStatus.Pending,
                "Sipariş oluşturuldu",
                "Customer",
                customerUserId,
                cancellationToken);
            await _dbContext.SaveChangesAsync(cancellationToken);

            // Sipariş kaydedildi; sunucu sepetini temizle (müşteri uygulaması da clearCart çağırır).
            await _cartRepository.ClearCartAsync(customerUserId, cancellationToken);

            if (calcResult.AppliedUserCouponId.HasValue)
            {
                var marked = await _couponService.MarkCouponAsUsedAsync(
                    calcResult.AppliedUserCouponId.Value,
                    order.OrderId,
                    cancellationToken);
                if (!marked)
                    return StatusCode(500, new { message = "Kupon kullanılamadı. Lütfen tekrar deneyin." });
            }

            await _notificationService.NotifyOrderCreatedAsync(order, cancellationToken);

            return Ok(new
            {
                id = order.OrderId,
                status = "pending",
                total = order.Total,
            });
        }
        catch (ForbiddenOperationException ex)
        {
            return StatusCode(403, new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { message = "Sipariş oluşturulurken hata oluştu.", detail = ex.Message });
        }
    }

    [HttpGet("orders/{orderId:guid}/review-products")]
    public async Task<ActionResult<List<object>>> GetReviewProducts(
        [FromQuery] Guid customerUserId,
        [FromRoute] Guid orderId,
        CancellationToken cancellationToken)
    {
        if (customerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Customer user id is required." });
        }

        var order = await _repository.GetOrderAsync(orderId, cancellationToken);
        if (order is null)
        {
            return NotFound(new { message = "Order not found." });
        }
        if (order.CustomerUserId != customerUserId)
        {
            return NotFound(new { message = "Order not found." });
        }

        var menuItems = await _restaurantRepo.GetMenuItemsAsync(order.RestaurantId, cancellationToken);
        var orderedNames = ExtractOrderItemNames(order.Items);
        var matched = MatchOrderedMenuItems(orderedNames, menuItems);

        var result = matched.Select(x => new
        {
            id = x.MenuItemId,
            name = x.Name,
            imagePath = NormalizeImagePath(x.ImagePath ?? string.Empty),
        }).ToList();

        return Ok(result);
    }

    [HttpGet("purchased-products")]
    public async Task<ActionResult<List<object>>> GetPurchasedProducts(
        [FromQuery] Guid customerUserId,
        CancellationToken cancellationToken)
    {
        if (customerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Customer user id is required." });
        }

        var orders = await _repository.GetOrdersForCustomerAsync(customerUserId, cancellationToken);
        var delivered = orders
            .Where(o => o.Status == CustomerOrderStatus.Delivered)
            .ToList();

        var unique = new Dictionary<Guid, MenuItem>();
        foreach (var order in delivered)
        {
            var menuItems = await _restaurantRepo.GetMenuItemsAsync(order.RestaurantId, cancellationToken);
            var orderedNames = ExtractOrderItemNames(order.Items);
            foreach (var item in MatchOrderedMenuItems(orderedNames, menuItems))
            {
                unique[item.MenuItemId] = item;
            }
        }

        var result = unique.Values
            .OrderBy(x => x.Name)
            .Select(x => new
            {
                id = x.MenuItemId,
                name = x.Name,
                categoryName = x.CategoryName,
                imagePath = NormalizeImagePath(x.ImagePath ?? string.Empty),
            })
            .ToList();

        return Ok(result);
    }

    private static string MapStatus(CustomerOrderStatus status)
    {
        return status switch
        {
            CustomerOrderStatus.Pending => "pending",
            CustomerOrderStatus.Preparing => "preparing",
            CustomerOrderStatus.Assigned => "assigned",
            CustomerOrderStatus.InTransit => "inTransit",
            CustomerOrderStatus.Delivered => "completed",
            CustomerOrderStatus.Cancelled => "canceled",
            CustomerOrderStatus.AwaitingCourierReassignment => "awaitingCourier",
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

    private string NormalizeImagePath(string imagePath)
    {
        if (string.IsNullOrWhiteSpace(imagePath))
        {
            return string.Empty;
        }

        if (imagePath.StartsWith("http://", StringComparison.OrdinalIgnoreCase) ||
            imagePath.StartsWith("https://", StringComparison.OrdinalIgnoreCase) ||
            imagePath.StartsWith("assets/", StringComparison.OrdinalIgnoreCase))
        {
            return imagePath.Trim();
        }

        var normalized = imagePath.Trim().TrimStart('/');
        return $"{Request.Scheme}://{Request.Host}/{normalized}";
    }

    private static List<string> ExtractOrderItemNames(string itemsText)
    {
        var result = new List<string>();
        if (string.IsNullOrWhiteSpace(itemsText))
        {
            return result;
        }

        var parts = itemsText.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        foreach (var part in parts)
        {
            var value = part.Trim();
            var xIndex = value.IndexOf('x');
            if (xIndex > 0)
            {
                var quantityText = value[..xIndex].Trim();
                if (int.TryParse(quantityText, out _))
                {
                    value = value[(xIndex + 1)..].Trim();
                }
            }

            if (!string.IsNullOrWhiteSpace(value))
            {
                result.Add(value);
            }
        }

        return result;
    }

    private static List<MenuItem> MatchOrderedMenuItems(
        IReadOnlyList<string> orderedNames,
        IReadOnlyList<MenuItem> menuItems)
    {
        var matched = new List<MenuItem>();
        var used = new HashSet<Guid>();

        foreach (var orderedName in orderedNames)
        {
            var normalizedOrdered = orderedName.Trim().ToLowerInvariant();
            if (string.IsNullOrWhiteSpace(normalizedOrdered))
            {
                continue;
            }

            var exact = menuItems.FirstOrDefault(x =>
                !string.IsNullOrWhiteSpace(x.Name) &&
                x.Name.Trim().Equals(orderedName, StringComparison.OrdinalIgnoreCase));
            if (exact != null && used.Add(exact.MenuItemId))
            {
                matched.Add(exact);
                continue;
            }

            var fuzzy = menuItems.FirstOrDefault(x =>
                !string.IsNullOrWhiteSpace(x.Name) &&
                (normalizedOrdered.Contains(x.Name.Trim().ToLowerInvariant()) ||
                 x.Name.Trim().ToLowerInvariant().Contains(normalizedOrdered)));
            if (fuzzy != null && used.Add(fuzzy.MenuItemId))
            {
                matched.Add(fuzzy);
            }
        }

        return matched;
    }
}

public sealed record CreateCustomerOrderRequest(
    Guid RestaurantId,
    string Items,
    int Total,
    string DeliveryAddress,
    string? DeliveryAddressDetail,
    double? CustomerLat,
    double? CustomerLng,
    string? CustomerName,
    string? CustomerPhone,
    Guid? UserCouponId = null,
    string? PaymentMethod = null,
    string? OrderNotes = null);
