using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Data;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Services;

public interface IOrderLifecycleService
{
    Task<OrderDetailDto?> GetOrderDetailAsync(Guid orderId, Guid customerUserId, CancellationToken ct = default);
    Task CancelOrderAsync(Guid orderId, Guid customerUserId, CancelOrderRequest request, CancellationToken ct = default);
    Task<RefundRequestDto> CreateRefundRequestAsync(Guid orderId, Guid customerUserId, CreateRefundRequestBody request, CancellationToken ct = default);
    Task<List<RefundRequestDto>> GetRefundRequestsForCustomerAsync(Guid customerUserId, CancellationToken ct = default);
    Task<RefundRequestDto> ResolveRefundRequestAsync(Guid refundRequestId, Guid resolverUserId, string resolverRole, ResolveRefundRequest request, CancellationToken ct = default);
    Task<ReorderResultDto> ReorderAsync(Guid orderId, Guid customerUserId, CancellationToken ct = default);
    Task AppendStatusHistoryAsync(CustomerOrder order, CustomerOrderStatus status, string? note, string? actorRole, Guid? actorUserId, CancellationToken ct);
}

public sealed class OrderLifecycleService : IOrderLifecycleService
{
    private readonly VaveylaDbContext _db;
    private readonly ICustomerCartRepository _cartRepository;
    private readonly INotificationService _notificationService;

    public OrderLifecycleService(
        VaveylaDbContext db,
        ICustomerCartRepository cartRepository,
        INotificationService notificationService)
    {
        _db = db;
        _cartRepository = cartRepository;
        _notificationService = notificationService;
    }

    public async Task<OrderDetailDto?> GetOrderDetailAsync(
        Guid orderId,
        Guid customerUserId,
        CancellationToken ct = default)
    {
        var order = await _db.CustomerOrders
            .Include(o => o.LineItems)
            .Include(o => o.StatusHistory)
            .FirstOrDefaultAsync(o => o.OrderId == orderId && o.CustomerUserId == customerUserId, ct);

        if (order is null)
        {
            return null;
        }

        var restaurant = await _db.Restaurants.AsNoTracking()
            .FirstOrDefaultAsync(r => r.RestaurantId == order.RestaurantId, ct);

        string? courierName = null;
        if (order.AssignedCourierUserId.HasValue)
        {
            courierName = await _db.Users.AsNoTracking()
                .Where(u => u.UserId == order.AssignedCourierUserId.Value)
                .Select(u => u.FullName)
                .FirstOrDefaultAsync(ct);
        }

        var lineItems = order.LineItems.Count > 0
            ? order.LineItems
            : await BuildLineItemsFromMenuAsync(order, ct);

        var history = order.StatusHistory
            .OrderBy(h => h.CreatedAtUtc)
            .Select(h => new OrderStatusHistoryDto(
                CustomerOrderCustomerDisplay.MapStatusForCustomerApp(
                    new CustomerOrder { Status = h.Status }),
                h.Note,
                h.ActorRole,
                h.CreatedAtUtc))
            .ToList();

        var minAmount = restaurant?.MinimumOrderAmount;
        var subtotal = order.Subtotal > 0 ? order.Subtotal : order.Total - order.DeliveryFee + order.TotalDiscount;

        return new OrderDetailDto(
            order.OrderId,
            order.OrderId.ToString("N")[..8].ToUpperInvariant(),
            order.RestaurantId,
            restaurant?.Name,
            CustomerOrderCustomerDisplay.MapStatusForCustomerApp(order),
            order.CreatedAtUtc,
            order.DeliveryAddress,
            order.DeliveryAddressDetail,
            courierName,
            order.PaymentMethod,
            order.OrderNotes,
            subtotal,
            order.DeliveryFee,
            order.TotalDiscount,
            order.CouponDiscountAmount ?? 0,
            order.Total,
            minAmount,
            !minAmount.HasValue || subtotal >= minAmount.Value,
            FormatCancelReason(order.CancellationReason),
            order.RejectionReason,
            lineItems.Select(li => new OrderLineItemDto(
                li.LineItemId,
                li.ProductId,
                li.ProductName,
                li.ImagePath,
                li.Quantity,
                li.WeightKg,
                li.SaleUnit,
                li.UnitPrice,
                li.LineTotal,
                li.VariationJson)).ToList(),
            history,
            CanCustomerCancel(order),
            CanCustomerRequestRefund(order),
            order.Status != CustomerOrderStatus.Cancelled);
    }

    public async Task CancelOrderAsync(
        Guid orderId,
        Guid customerUserId,
        CancelOrderRequest request,
        CancellationToken ct = default)
    {
        var order = await _db.CustomerOrders
            .FirstOrDefaultAsync(o => o.OrderId == orderId && o.CustomerUserId == customerUserId, ct)
            ?? throw new InvalidOperationException("Sipariş bulunamadı.");

        if (!CanCustomerCancel(order))
        {
            throw new InvalidOperationException("Bu sipariş iptal edilemez.");
        }

        var previousStatus = order.Status;
        order.Status = CustomerOrderStatus.Cancelled;
        order.CancellationReason = request.Reason;
        order.CancellationReasonNote = request.ReasonNote?.Trim();
        order.CancelledAtUtc = DateTime.UtcNow;
        order.CancelledByRole = "Customer";
        order.RejectionReason = BuildCancelMessage(request.Reason, request.ReasonNote);

        await AppendStatusHistoryAsync(order, CustomerOrderStatus.Cancelled, order.RejectionReason, "Customer", customerUserId, ct);
        await _db.SaveChangesAsync(ct);
        await _notificationService.NotifyOwnerOrderStatusChangedAsync(
            order,
            previousStatus,
            ct);
    }

    public async Task<RefundRequestDto> CreateRefundRequestAsync(
        Guid orderId,
        Guid customerUserId,
        CreateRefundRequestBody request,
        CancellationToken ct = default)
    {
        var order = await _db.CustomerOrders
            .Include(o => o.RefundRequests)
            .FirstOrDefaultAsync(o => o.OrderId == orderId && o.CustomerUserId == customerUserId, ct)
            ?? throw new InvalidOperationException("Sipariş bulunamadı.");

        if (!CanCustomerRequestRefund(order))
        {
            throw new InvalidOperationException("Bu sipariş için iade talebi oluşturulamaz.");
        }

        if (order.RefundRequests.Any(r => r.Status is RefundRequestStatus.Pending or RefundRequestStatus.Approved))
        {
            throw new InvalidOperationException("Bu sipariş için zaten aktif bir iade talebi var.");
        }

        var refund = new OrderRefundRequest
        {
            RefundRequestId = Guid.NewGuid(),
            OrderId = order.OrderId,
            CustomerUserId = customerUserId,
            RestaurantId = order.RestaurantId,
            Status = RefundRequestStatus.Pending,
            Reason = request.Reason,
            ReasonNote = request.ReasonNote?.Trim(),
            CreatedAtUtc = DateTime.UtcNow,
        };

        order.Status = CustomerOrderStatus.RefundRequested;
        _db.OrderRefundRequests.Add(refund);
        await AppendStatusHistoryAsync(
            order,
            CustomerOrderStatus.RefundRequested,
            BuildCancelMessage(request.Reason, request.ReasonNote),
            "Customer",
            customerUserId,
            ct);
        await _db.SaveChangesAsync(ct);

        return await MapRefundDtoAsync(refund, ct);
    }

    public async Task<List<RefundRequestDto>> GetRefundRequestsForCustomerAsync(
        Guid customerUserId,
        CancellationToken ct = default)
    {
        var refunds = await _db.OrderRefundRequests
            .Where(r => r.CustomerUserId == customerUserId)
            .OrderByDescending(r => r.CreatedAtUtc)
            .ToListAsync(ct);

        var result = new List<RefundRequestDto>();
        foreach (var refund in refunds)
        {
            result.Add(await MapRefundDtoAsync(refund, ct));
        }

        return result;
    }

    public async Task<RefundRequestDto> ResolveRefundRequestAsync(
        Guid refundRequestId,
        Guid resolverUserId,
        string resolverRole,
        ResolveRefundRequest request,
        CancellationToken ct = default)
    {
        var refund = await _db.OrderRefundRequests
            .Include(r => r.Order)
            .FirstOrDefaultAsync(r => r.RefundRequestId == refundRequestId, ct)
            ?? throw new InvalidOperationException("İade talebi bulunamadı.");

        if (refund.Status != RefundRequestStatus.Pending)
        {
            throw new InvalidOperationException("Bu iade talebi zaten işlenmiş.");
        }

        refund.Status = request.Approve ? RefundRequestStatus.Approved : RefundRequestStatus.Rejected;
        refund.RestaurantResponse = request.ResponseNote?.Trim();
        refund.ResolvedAtUtc = DateTime.UtcNow;
        refund.ResolvedByUserId = resolverUserId;

        if (refund.Order is not null)
        {
            if (request.Approve)
            {
                refund.Order.Status = CustomerOrderStatus.Cancelled;
                refund.Order.RejectionReason = request.ResponseNote ?? "İade onaylandı.";
                refund.Status = RefundRequestStatus.Completed;
            }
            else
            {
                refund.Order.Status = CustomerOrderStatus.Delivered;
            }

            await AppendStatusHistoryAsync(
                refund.Order,
                refund.Order.Status,
                refund.RestaurantResponse,
                resolverRole,
                resolverUserId,
                ct);
        }

        await _db.SaveChangesAsync(ct);
        return await MapRefundDtoAsync(refund, ct);
    }

    public async Task<ReorderResultDto> ReorderAsync(
        Guid orderId,
        Guid customerUserId,
        CancellationToken ct = default)
    {
        var order = await _db.CustomerOrders
            .Include(o => o.LineItems)
            .FirstOrDefaultAsync(o => o.OrderId == orderId && o.CustomerUserId == customerUserId, ct)
            ?? throw new InvalidOperationException("Sipariş bulunamadı.");

        var lineItems = order.LineItems.Count > 0
            ? order.LineItems
            : await BuildLineItemsFromMenuAsync(order, ct);

        if (lineItems.Count == 0)
        {
            throw new InvalidOperationException("Sipariş ürünleri bulunamadı.");
        }

        var unavailable = new List<string>();
        var warnings = new List<string>();
        var added = 0;

        foreach (var line in lineItems)
        {
            var menuItem = await _db.MenuItems.AsNoTracking()
                .FirstOrDefaultAsync(m => m.MenuItemId == line.ProductId && m.RestaurantId == order.RestaurantId, ct);

            if (menuItem is null || !menuItem.IsAvailable)
            {
                unavailable.Add(line.ProductName);
                continue;
            }

            await _cartRepository.AddOrUpdateAsync(
                customerUserId,
                line.ProductId,
                line.WeightKg,
                line.Quantity,
                ct);
            added++;

            if (menuItem.Price != (int)Math.Round(line.UnitPrice))
            {
                warnings.Add($"{line.ProductName} fiyatı güncellendi.");
            }
        }

        return new ReorderResultDto(added, unavailable.Count, unavailable, warnings);
    }

    public async Task AppendStatusHistoryAsync(
        CustomerOrder order,
        CustomerOrderStatus status,
        string? note,
        string? actorRole,
        Guid? actorUserId,
        CancellationToken ct)
    {
        _db.OrderStatusHistories.Add(new OrderStatusHistory
        {
            HistoryId = Guid.NewGuid(),
            OrderId = order.OrderId,
            Status = status,
            Note = note,
            ActorRole = actorRole,
            ActorUserId = actorUserId,
            CreatedAtUtc = DateTime.UtcNow,
        });
        await Task.CompletedTask;
    }

    private async Task<List<CustomerOrderLineItem>> BuildLineItemsFromMenuAsync(
        CustomerOrder order,
        CancellationToken ct)
    {
        var menuItems = await _db.MenuItems
            .Where(m => m.RestaurantId == order.RestaurantId)
            .ToListAsync(ct);

        var names = ExtractOrderItemNames(order.Items);
        var matched = MatchOrderedMenuItems(names, menuItems);
        return matched.Select(m => new CustomerOrderLineItem
        {
            LineItemId = Guid.NewGuid(),
            OrderId = order.OrderId,
            ProductId = m.MenuItemId,
            ProductName = m.Name,
            ImagePath = m.ImagePath,
            Quantity = 1,
            WeightKg = 1,
            SaleUnit = m.SaleUnit,
            UnitPrice = (decimal)m.Price,
            LineTotal = (decimal)m.Price,
        }).ToList();
    }

    private async Task<RefundRequestDto> MapRefundDtoAsync(OrderRefundRequest refund, CancellationToken ct)
    {
        var order = await _db.CustomerOrders.AsNoTracking()
            .FirstOrDefaultAsync(o => o.OrderId == refund.OrderId, ct);
        var restaurantName = await _db.Restaurants.AsNoTracking()
            .Where(r => r.RestaurantId == refund.RestaurantId)
            .Select(r => r.Name)
            .FirstOrDefaultAsync(ct);

        var history = await _db.OrderStatusHistories.AsNoTracking()
            .Where(h => h.OrderId == refund.OrderId)
            .OrderBy(h => h.CreatedAtUtc)
            .Select(h => new OrderStatusHistoryDto(
                h.Status.ToString(),
                h.Note,
                h.ActorRole,
                h.CreatedAtUtc))
            .ToListAsync(ct);

        return new RefundRequestDto(
            refund.RefundRequestId,
            refund.OrderId,
            refund.OrderId.ToString("N")[..8].ToUpperInvariant(),
            restaurantName,
            refund.Status,
            refund.Reason,
            refund.ReasonNote,
            refund.RestaurantResponse,
            refund.CreatedAtUtc,
            refund.ResolvedAtUtc,
            history);
    }

    public static bool CanCustomerCancel(CustomerOrder order) =>
        order.Status is CustomerOrderStatus.Pending or CustomerOrderStatus.Preparing;

    public static bool CanCustomerRequestRefund(CustomerOrder order) =>
        order.Status is CustomerOrderStatus.Delivered &&
        order.CreatedAtUtc > DateTime.UtcNow.AddDays(-7);

    private static string? FormatCancelReason(OrderCancelReason? reason) =>
        reason switch
        {
            OrderCancelReason.ChangedMind => "Fikrimi değiştirdim",
            OrderCancelReason.WrongOrder => "Yanlış sipariş",
            OrderCancelReason.LateDelivery => "Geç teslimat",
            OrderCancelReason.QualityIssue => "Kalite sorunu",
            OrderCancelReason.Other => "Diğer",
            _ => null,
        };

    private static string BuildCancelMessage(OrderCancelReason reason, string? note)
    {
        var baseMsg = FormatCancelReason(reason) ?? reason.ToString();
        return string.IsNullOrWhiteSpace(note) ? baseMsg : $"{baseMsg}: {note.Trim()}";
    }

    private static List<string> ExtractOrderItemNames(string itemsText)
    {
        var result = new List<string>();
        if (string.IsNullOrWhiteSpace(itemsText)) return result;
        foreach (var part in itemsText.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            var value = part.Trim();
            var xIndex = value.IndexOf('x');
            if (xIndex > 0 && int.TryParse(value[..xIndex].Trim(), out _))
            {
                value = value[(xIndex + 1)..].Trim();
            }

            var paren = value.IndexOf('(');
            if (paren > 0) value = value[..paren].Trim();
            if (!string.IsNullOrWhiteSpace(value)) result.Add(value);
        }

        return result;
    }

    private static List<MenuItem> MatchOrderedMenuItems(IReadOnlyList<string> orderedNames, IReadOnlyList<MenuItem> menuItems)
    {
        var matched = new List<MenuItem>();
        var used = new HashSet<Guid>();
        foreach (var orderedName in orderedNames)
        {
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
                orderedName.Contains(x.Name.Trim(), StringComparison.OrdinalIgnoreCase));
            if (fuzzy != null && used.Add(fuzzy.MenuItemId))
            {
                matched.Add(fuzzy);
            }
        }

        return matched;
    }
}
