using System.Collections.Generic;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Data;
using Vaveyla.Api.Models;
using Vaveyla.Api.Services;

namespace Vaveyla.Api.Controllers;

[ApiController]
[Route("api/customer/chats")]
public sealed class CustomerChatsController : ControllerBase
{
    private readonly ICustomerChatsRepository _repository;
    private readonly VaveylaDbContext _dbContext;
    private readonly INotificationService _notificationService;

    public CustomerChatsController(
        ICustomerChatsRepository repository,
        VaveylaDbContext dbContext,
        INotificationService notificationService)
    {
        _repository = repository;
        _dbContext = dbContext;
        _notificationService = notificationService;
    }

    [HttpGet("messages")]
    public async Task<ActionResult<object>> GetMessages(
        [FromQuery] Guid customerUserId,
        [FromQuery] Guid restaurantId,
        CancellationToken cancellationToken,
        [FromQuery] int limit = 100)
    {
        if (customerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Customer user id is required." });
        }
        if (restaurantId == Guid.Empty)
        {
            return BadRequest(new { message = "Restaurant id is required." });
        }

        var messages = await _repository.GetMessagesAsync(
            customerUserId,
            restaurantId,
            limit,
            cancellationToken);
        var customerName = await _dbContext.Users
            .Where(x => x.UserId == customerUserId)
            .Select(x => x.FullName)
            .FirstOrDefaultAsync(cancellationToken);
        var restaurantOwnerName = await _dbContext.Restaurants
            .Where(x => x.RestaurantId == restaurantId)
            .Join(
                _dbContext.Users,
                r => r.OwnerUserId,
                u => u.UserId,
                (_, u) => u.FullName)
            .FirstOrDefaultAsync(cancellationToken);

        return Ok(new
        {
            items = messages.Select(x => MapMessage(x, customerName, restaurantOwnerName)),
            totalCount = messages.Count,
        });
    }

    [HttpPost("messages")]
    public async Task<ActionResult<object>> SendCustomerMessage(
        [FromQuery] Guid customerUserId,
        [FromBody] SendCustomerMessageRequest request,
        CancellationToken cancellationToken)
    {
        if (customerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Customer user id is required." });
        }
        if (request.RestaurantId == Guid.Empty)
        {
            return BadRequest(new { message = "Restaurant id is required." });
        }
        if (string.IsNullOrWhiteSpace(request.Message))
        {
            return BadRequest(new { message = "Message is required." });
        }

        if (ProfanityValidator.ContainsProfanity(request.Message))
        {
            return BadRequest(new
            {
                message = "Mesajınız uygunsuz ifadeler içeriyor. Lütfen saygılı bir dil kullanın.",
            });
        }

        var customerExists = await _dbContext.Users.AnyAsync(
            x => x.UserId == customerUserId,
            cancellationToken);
        if (!customerExists)
        {
            return NotFound(new { message = "Customer not found." });
        }

        var restaurant = await _dbContext.Restaurants.FirstOrDefaultAsync(
            x => x.RestaurantId == request.RestaurantId,
            cancellationToken);
        if (restaurant is null)
        {
            return NotFound(new { message = "Restaurant not found." });
        }

        var created = await _repository.AddMessageAsync(
            new RestaurantChatMessage
            {
                ChatMessageId = Guid.NewGuid(),
                RestaurantId = request.RestaurantId,
                CustomerUserId = customerUserId,
                SenderUserId = customerUserId,
                SenderType = "customer",
                Message = request.Message.Trim(),
                CreatedAtUtc = DateTime.UtcNow,
            },
            cancellationToken);

        // Notify restaurant owner about incoming customer message.
        if (restaurant.OwnerUserId != Guid.Empty)
        {
            await _notificationService.SendToUserAsync(
                restaurant.OwnerUserId,
                NotificationType.Generic,
                "Yeni sohbet mesajı",
                request.Message.Trim(),
                null,
                new Dictionary<string, object?>
                {
                    ["restaurantId"] = restaurant.RestaurantId,
                    ["customerUserId"] = customerUserId,
                },
                cancellationToken);
        }

        var customerName = await _dbContext.Users
            .Where(x => x.UserId == customerUserId)
            .Select(x => x.FullName)
            .FirstOrDefaultAsync(cancellationToken);
        var restaurantOwnerName = await _dbContext.Users
            .Where(x => x.UserId == restaurant.OwnerUserId)
            .Select(x => x.FullName)
            .FirstOrDefaultAsync(cancellationToken);

        return Ok(MapMessage(created, customerName, restaurantOwnerName));
    }

    [HttpDelete("messages/{messageId:guid}")]
    public async Task<ActionResult> DeleteCustomerMessage(
        [FromRoute] Guid messageId,
        [FromQuery] Guid customerUserId,
        CancellationToken cancellationToken)
    {
        if (messageId == Guid.Empty)
        {
            return BadRequest(new { message = "Message id is required." });
        }
        if (customerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Customer user id is required." });
        }

        var deleted = await _repository.DeleteCustomerMessageAsync(
            messageId,
            customerUserId,
            cancellationToken);
        if (!deleted)
        {
            return NotFound(new { message = "Message not found or cannot be deleted." });
        }

        return NoContent();
    }

    [HttpGet("conversations")]
    public async Task<ActionResult<List<CustomerChatConversationDto>>> GetChatConversations(
        [FromQuery] Guid customerUserId,
        CancellationToken cancellationToken)
    {
        if (customerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Customer user id is required." });
        }

        var hiddenRestaurantIds = await _dbContext.CustomerChatInboxHides.AsNoTracking()
            .Where(h => h.CustomerUserId == customerUserId && h.RestaurantId != null)
            .Select(h => h.RestaurantId!.Value)
            .ToListAsync(cancellationToken);
        var hiddenOrderIds = await _dbContext.CustomerChatInboxHides.AsNoTracking()
            .Where(h => h.CustomerUserId == customerUserId && h.OrderId != null)
            .Select(h => h.OrderId!.Value)
            .ToListAsync(cancellationToken);
        var hiddenRestaurantSet = hiddenRestaurantIds.ToHashSet();
        var hiddenOrderSet = hiddenOrderIds.ToHashSet();

        var messages = await _dbContext.RestaurantChatMessages
            .Where(x => x.CustomerUserId == customerUserId)
            .OrderByDescending(x => x.CreatedAtUtc)
            .ToListAsync(cancellationToken);

        List<CustomerChatConversationDto> restaurantConversations;
        if (messages.Count == 0)
        {
            restaurantConversations = new List<CustomerChatConversationDto>();
        }
        else
        {
            var restaurantIds = messages
                .Select(x => x.RestaurantId)
                .Distinct()
                .ToList();

            var restaurantNames = await _dbContext.Restaurants
                .Where(r => restaurantIds.Contains(r.RestaurantId))
                .ToDictionaryAsync(r => r.RestaurantId, r => r.Name, cancellationToken);

            restaurantConversations = messages
                .GroupBy(x => x.RestaurantId)
                .Select(group =>
                {
                    var latest = group
                        .OrderByDescending(x => x.CreatedAtUtc)
                        .First();

                    restaurantNames.TryGetValue(group.Key, out var restaurantName);

                    return new CustomerChatConversationDto(
                        group.Key,
                        restaurantName ?? "Pastane",
                        latest.Message ?? string.Empty,
                        latest.SenderType ?? "customer",
                        latest.CreatedAtUtc,
                        group.Count(),
                        Kind: "restaurant",
                        OrderId: null,
                        CourierName: null,
                        OrderItemsPreview: null);
                })
                .ToList();

            restaurantConversations = restaurantConversations
                .Where(c => !hiddenRestaurantSet.Contains(c.RestaurantId))
                .ToList();
        }

        var deliveryRows = await (
            from m in _dbContext.DeliveryChatMessages.AsNoTracking()
            join o in _dbContext.CustomerOrders.AsNoTracking() on m.OrderId equals o.OrderId
            where o.CustomerUserId == customerUserId && m.DeletedAtUtc == null
            select new { Message = m, Order = o }
        ).ToListAsync(cancellationToken);

        // Müşterinin tüm siparişleri (iptal dahil) — Siparişler sekmesiyle uyumlu sohbet geçmişi.
        var ordersForDeliveryInbox = await _dbContext.CustomerOrders.AsNoTracking()
            .Where(o => o.CustomerUserId == customerUserId)
            .OrderByDescending(o => o.CourierLocationUpdatedAtUtc ?? o.CreatedAtUtc)
            .Take(100)
            .ToListAsync(cancellationToken);

        var orderIdsForCourierLookup = ordersForDeliveryInbox
            .Select(o => o.OrderId)
            .Concat(deliveryRows.Select(r => r.Message.OrderId))
            .Distinct()
            .ToList();

        var courierUserIdFromChat = await CustomerOrderCourierHelper.GetCourierUserIdsFromDeliveryChatAsync(
            _dbContext,
            customerUserId,
            orderIdsForCourierLookup,
            cancellationToken);

        Guid? ResolveCourierUserId(CustomerOrder order) =>
            CustomerOrderCustomerDisplay.ResolveCourierUserIdForCustomer(
                order,
                courierUserIdFromChat);

        var allCourierUserIds = deliveryRows
            .Select(r => ResolveCourierUserId(r.Order))
            .Concat(ordersForDeliveryInbox.Select(ResolveCourierUserId))
            .Where(id => id.HasValue)
            .Select(id => id!.Value)
            .Distinct()
            .ToList();

        var courierDisplayNames = allCourierUserIds.Count == 0
            ? new Dictionary<Guid, string>()
            : await _dbContext.Users.AsNoTracking()
                .Where(u => allCourierUserIds.Contains(u.UserId))
                .ToDictionaryAsync(
                    u => u.UserId,
                    u => string.IsNullOrWhiteSpace(u.FullName) ? "Kurye" : u.FullName.Trim(),
                    cancellationToken);

        string CourierLabel(Guid? courierUserId)
        {
            if (!courierUserId.HasValue)
            {
                return "Kurye";
            }

            return courierDisplayNames.TryGetValue(courierUserId.Value, out var n)
                ? n
                : "Kurye";
        }

        var deliveryConversations = deliveryRows
            .GroupBy(x => x.Message.OrderId)
            .Select(g =>
            {
                var row = g.OrderByDescending(x => x.Message.CreatedAtUtc).First();
                var latest = row.Message;
                var order = row.Order;
                var senderType = latest.SenderUserId == customerUserId
                    ? "customer"
                    : "courier";
                var resolvedCourier = ResolveCourierUserId(order);
                var courierNameForDto = resolvedCourier.HasValue
                    ? CourierLabel(resolvedCourier)
                    : null;
                var preview = OrderItemsPreviewLine(order);
                var title = BuildCourierInboxTitle(order, courierNameForDto);
                return new CustomerChatConversationDto(
                    Guid.Empty,
                    title,
                    latest.Message ?? string.Empty,
                    senderType,
                    latest.CreatedAtUtc,
                    g.Count(),
                    Kind: "delivery",
                    OrderId: latest.OrderId,
                    CourierName: courierNameForDto,
                    OrderItemsPreview: preview);
            })
            .ToList();

        var fromMessageOrderIds = deliveryConversations
            .Select(d => d.OrderId)
            .Where(id => id.HasValue)
            .Select(id => id!.Value)
            .ToHashSet();

        var placeholderDelivery = new List<CustomerChatConversationDto>();
        foreach (var order in ordersForDeliveryInbox)
        {
            if (fromMessageOrderIds.Contains(order.OrderId))
            {
                continue;
            }

            var sortTime = order.CourierLocationUpdatedAtUtc ?? order.CreatedAtUtc;
            var resolvedCourier = ResolveCourierUserId(order);
            var courierNameForDto = resolvedCourier.HasValue
                ? CourierLabel(resolvedCourier)
                : null;
            var preview = OrderItemsPreviewLine(order);
            var title = BuildCourierInboxTitle(order, courierNameForDto);
            var placeholderText = order.Status == CustomerOrderStatus.Cancelled
                ? "Bu sipariş iptal edildi."
                : resolvedCourier.HasValue
                    ? "Henüz mesaj yok."
                    : "Kurye atanana kadar bekleyin veya mesaj bırakın.";
            placeholderDelivery.Add(new CustomerChatConversationDto(
                Guid.Empty,
                title,
                placeholderText,
                "courier",
                sortTime,
                0,
                Kind: "delivery",
                OrderId: order.OrderId,
                CourierName: courierNameForDto,
                OrderItemsPreview: preview));
        }

        var allDelivery = deliveryConversations
            .Concat(placeholderDelivery)
            .Where(d => d.OrderId is null || !hiddenOrderSet.Contains(d.OrderId.Value))
            .OrderByDescending(x => x.LastMessageAtUtc)
            .ToList();

        var merged = restaurantConversations
            .Concat(allDelivery)
            .OrderByDescending(x => x.LastMessageAtUtc)
            .ToList();

        return Ok(merged);
    }

    /// <summary>
    /// Listeden gizlenen sohbet kimlikleri (istemci sipariş birleştirmesi için).
    /// </summary>
    [HttpGet("inbox/hidden")]
    public async Task<ActionResult<object>> GetHiddenInboxIds(
        [FromQuery] Guid customerUserId,
        CancellationToken cancellationToken)
    {
        if (customerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Customer user id is required." });
        }

        var orderIds = await _dbContext.CustomerChatInboxHides.AsNoTracking()
            .Where(h => h.CustomerUserId == customerUserId && h.OrderId != null)
            .Select(h => h.OrderId!.Value)
            .ToListAsync(cancellationToken);

        var restaurantIds = await _dbContext.CustomerChatInboxHides.AsNoTracking()
            .Where(h => h.CustomerUserId == customerUserId && h.RestaurantId != null)
            .Select(h => h.RestaurantId!.Value)
            .ToListAsync(cancellationToken);

        return Ok(new
        {
            orderIds = orderIds.Select(x => x.ToString("D")).ToList(),
            restaurantIds = restaurantIds.Select(x => x.ToString("D")).ToList(),
        });
    }

    /// <summary>Müşteri Sohbetler listesinden satırı gizler (mesajları silmez).</summary>
    [HttpPost("inbox/hide")]
    public async Task<ActionResult> HideChatInboxRow(
        [FromQuery] Guid customerUserId,
        [FromBody] HideCustomerChatInboxBody body,
        CancellationToken cancellationToken)
    {
        if (customerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Customer user id is required." });
        }

        var rid = body.RestaurantId;
        var oid = body.OrderId;
        var hasR = rid.HasValue && rid.Value != Guid.Empty;
        var hasO = oid.HasValue && oid.Value != Guid.Empty;
        if (hasR == hasO)
        {
            return BadRequest(new
            {
                message = "Tam olarak biri dolu olmalı: restaurantId veya orderId.",
            });
        }

        if (hasO)
        {
            var orderOk = await _dbContext.CustomerOrders.AsNoTracking()
                .AnyAsync(
                    o => o.OrderId == oid!.Value && o.CustomerUserId == customerUserId,
                    cancellationToken);
            if (!orderOk)
            {
                return NotFound(new { message = "Sipariş bulunamadı veya size ait değil." });
            }

            var existsOrder = await _dbContext.CustomerChatInboxHides.AnyAsync(
                h => h.CustomerUserId == customerUserId && h.OrderId == oid,
                cancellationToken);
            if (!existsOrder)
            {
                _dbContext.CustomerChatInboxHides.Add(new CustomerChatInboxHide
                {
                    HideId = Guid.NewGuid(),
                    CustomerUserId = customerUserId,
                    RestaurantId = null,
                    OrderId = oid,
                    HiddenAtUtc = DateTime.UtcNow,
                });
                await _dbContext.SaveChangesAsync(cancellationToken);
            }

            return NoContent();
        }

        var existsRest = await _dbContext.CustomerChatInboxHides.AnyAsync(
            h => h.CustomerUserId == customerUserId && h.RestaurantId == rid,
            cancellationToken);
        if (!existsRest)
        {
            _dbContext.CustomerChatInboxHides.Add(new CustomerChatInboxHide
            {
                HideId = Guid.NewGuid(),
                CustomerUserId = customerUserId,
                RestaurantId = rid,
                OrderId = null,
                HiddenAtUtc = DateTime.UtcNow,
            });
            await _dbContext.SaveChangesAsync(cancellationToken);
        }

        return NoContent();
    }

    private static string OrderItemsPreviewLine(CustomerOrder order)
    {
        if (string.IsNullOrWhiteSpace(order.Items))
        {
            return "Sipariş";
        }

        var s = order.Items.Trim();
        return s.Length > 48 ? string.Concat(s.AsSpan(0, 45), "\u2026") : s;
    }

    private static string BuildCourierInboxTitle(CustomerOrder order, string? courierDisplayName)
    {
        var preview = OrderItemsPreviewLine(order);
        var label = string.IsNullOrWhiteSpace(courierDisplayName)
            ? "Teslimat"
            : courierDisplayName;
        return $"{label} — {preview}";
    }

    private static object MapMessage(
        RestaurantChatMessage message,
        string? customerName,
        string? restaurantOwnerName)
    {
        var isCustomer = string.Equals(
            message.SenderType,
            "customer",
            StringComparison.OrdinalIgnoreCase);
        return new
        {
            id = message.ChatMessageId,
            restaurantId = message.RestaurantId,
            customerUserId = message.CustomerUserId,
            senderUserId = message.SenderUserId,
            senderType = message.SenderType,
            senderName = isCustomer
                ? string.IsNullOrWhiteSpace(customerName) ? "Müşteri" : customerName
                : string.IsNullOrWhiteSpace(restaurantOwnerName) ? "Pastane" : restaurantOwnerName,
            message = message.Message,
            createdAtUtc = message.CreatedAtUtc,
        };
    }
}

public sealed record SendCustomerMessageRequest(Guid RestaurantId, string Message);

public sealed record HideCustomerChatInboxBody(Guid? RestaurantId, Guid? OrderId);
