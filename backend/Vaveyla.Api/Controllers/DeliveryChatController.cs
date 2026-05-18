using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Vaveyla.Api.Data;
using Vaveyla.Api.Hubs;
using Vaveyla.Api.Models;
using Vaveyla.Api.Services;

namespace Vaveyla.Api.Controllers;

[ApiController]
[Route("api/orders")]
public sealed class DeliveryChatController : ControllerBase
{
    private readonly ICustomerOrdersRepository _orders;
    private readonly IDeliveryChatRepository _chat;
    private readonly INotificationService _notifications;
    private readonly IHubContext<TrackingHub> _trackingHub;

    public DeliveryChatController(
        ICustomerOrdersRepository orders,
        IDeliveryChatRepository chat,
        INotificationService notifications,
        IHubContext<TrackingHub> trackingHub)
    {
        _orders = orders;
        _chat = chat;
        _notifications = notifications;
        _trackingHub = trackingHub;
    }

    [HttpGet("{orderId:guid}/delivery-chat/messages")]
    public async Task<ActionResult<List<object>>> GetMessages(
        [FromRoute] Guid orderId,
        [FromQuery] Guid userId,
        CancellationToken cancellationToken)
    {
        if (userId == Guid.Empty)
        {
            return BadRequest(new { message = "userId gerekli." });
        }

        var order = await _orders.GetOrderAsync(orderId, cancellationToken);
        if (order is null)
        {
            return NotFound(new { message = "Sipariş bulunamadı." });
        }

        if (!CanAccess(order, userId))
        {
            return StatusCode(403, new { message = "Bu sipariş için sohbete erişemezsiniz." });
        }

        var list = await _chat.GetMessagesForOrderAsync(orderId, cancellationToken);
        return Ok(list.Select(MapMessage).ToList());
    }

    [HttpPost("{orderId:guid}/delivery-chat/messages")]
    public async Task<ActionResult<object>> PostMessage(
        [FromRoute] Guid orderId,
        [FromQuery] Guid userId,
        [FromBody] PostDeliveryChatBody body,
        CancellationToken cancellationToken)
    {
        if (userId == Guid.Empty)
        {
            return BadRequest(new { message = "userId gerekli." });
        }

        var text = body.Message?.Trim() ?? string.Empty;
        if (text.Length == 0 || text.Length > 1500)
        {
            return BadRequest(new { message = "Mesaj 1–1500 karakter olmalı." });
        }

        if (ProfanityValidator.ContainsProfanity(text))
        {
            return BadRequest(new
            {
                message = "Mesajınız uygunsuz ifadeler içeriyor. Lütfen saygılı bir dil kullanın.",
            });
        }

        var order = await _orders.GetOrderAsync(orderId, cancellationToken);
        if (order is null)
        {
            return NotFound(new { message = "Sipariş bulunamadı." });
        }

        if (!CanAccess(order, userId))
        {
            return StatusCode(403, new { message = "Bu sipariş için mesaj gönderemezsiniz." });
        }

        var msg = new DeliveryChatMessage
        {
            MessageId = Guid.NewGuid(),
            OrderId = orderId,
            SenderUserId = userId,
            Message = text,
            CreatedAtUtc = DateTime.UtcNow,
        };

        var saved = await _chat.AddMessageAsync(msg, cancellationToken);

        await _trackingHub.Clients
            .Group(TrackingHub.GroupName(orderId.ToString()))
            .SendAsync("delivery_chat_message", MapMessage(saved), cancellationToken);

        Guid? recipient =
            order.CustomerUserId == userId
                ? order.AssignedCourierUserId
                : order.CustomerUserId;

        if (recipient.HasValue && recipient.Value != userId)
        {
            var preview = text.Length > 120 ? string.Concat(text.AsSpan(0, 120), "…") : text;
            var title =
                order.CustomerUserId == userId
                    ? "Müşteriden yeni mesaj"
                    : "Kuryeden yeni mesaj";
            var shortId = orderId.ToString();
            if (shortId.Length > 8)
            {
                shortId = shortId[..8];
            }

            await _notifications.SendToUserAsync(
                recipient.Value,
                NotificationType.DeliveryChatMessage,
                title,
                $"#{shortId} · {preview}",
                orderId,
                new Dictionary<string, object?>
                {
                    ["orderId"] = orderId.ToString(),
                    ["messageId"] = saved.MessageId.ToString(),
                    ["senderUserId"] = userId.ToString(),
                },
                cancellationToken);
        }

        return Ok(MapMessage(saved));
    }

    [HttpPatch("{orderId:guid}/delivery-chat/messages/{messageId:guid}")]
    public async Task<ActionResult<object>> PatchMessage(
        [FromRoute] Guid orderId,
        [FromRoute] Guid messageId,
        [FromQuery] Guid userId,
        [FromBody] PatchDeliveryChatBody body,
        CancellationToken cancellationToken)
    {
        if (userId == Guid.Empty)
        {
            return BadRequest(new { message = "userId gerekli." });
        }

        var text = body.Message?.Trim() ?? string.Empty;
        if (text.Length == 0 || text.Length > 1500)
        {
            return BadRequest(new { message = "Mesaj 1–1500 karakter olmalı." });
        }

        if (ProfanityValidator.ContainsProfanity(text))
        {
            return BadRequest(new
            {
                message = "Mesajınız uygunsuz ifadeler içeriyor. Lütfen saygılı bir dil kullanın.",
            });
        }

        var order = await _orders.GetOrderAsync(orderId, cancellationToken);
        if (order is null)
        {
            return NotFound(new { message = "Sipariş bulunamadı." });
        }

        if (!CanAccess(order, userId))
        {
            return StatusCode(403, new { message = "Bu sipariş için mesaj düzenleyemezsiniz." });
        }

        var updated = await _chat.UpdateMessageAsync(
            messageId,
            orderId,
            userId,
            text,
            cancellationToken);

        if (updated is null)
        {
            return NotFound(new { message = "Mesaj bulunamadı veya silinmiş." });
        }

        return Ok(MapMessage(updated));
    }

    [HttpDelete("{orderId:guid}/delivery-chat/messages/{messageId:guid}")]
    public async Task<ActionResult> DeleteMessage(
        [FromRoute] Guid orderId,
        [FromRoute] Guid messageId,
        [FromQuery] Guid userId,
        CancellationToken cancellationToken)
    {
        if (userId == Guid.Empty)
        {
            return BadRequest(new { message = "userId gerekli." });
        }

        var order = await _orders.GetOrderAsync(orderId, cancellationToken);
        if (order is null)
        {
            return NotFound(new { message = "Sipariş bulunamadı." });
        }

        if (!CanAccess(order, userId))
        {
            return StatusCode(403, new { message = "Bu sipariş için mesaj silemezsiniz." });
        }

        var ok = await _chat.SoftDeleteMessageAsync(
            messageId,
            orderId,
            userId,
            cancellationToken);

        if (!ok)
        {
            return NotFound(new { message = "Mesaj bulunamadı veya silinmiş." });
        }

        return NoContent();
    }

    private static bool CanAccess(CustomerOrder order, Guid userId)
    {
        if (order.CustomerUserId == userId)
        {
            return true;
        }

        return order.AssignedCourierUserId.HasValue &&
               order.AssignedCourierUserId.Value == userId;
    }

    private static object MapMessage(DeliveryChatMessage m) => new
    {
        id = m.MessageId,
        orderId = m.OrderId,
        senderUserId = m.SenderUserId.ToString(),
        message = m.Message,
        createdAtUtc = m.CreatedAtUtc.ToString("o"),
        editedAtUtc = m.EditedAtUtc?.ToString("o"),
    };
}

public sealed record PostDeliveryChatBody(string Message);

public sealed record PatchDeliveryChatBody(string Message);
