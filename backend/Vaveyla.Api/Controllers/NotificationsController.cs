using Microsoft.AspNetCore.Mvc;
using Vaveyla.Api.Models;
using Vaveyla.Api.Services;

namespace Vaveyla.Api.Controllers;

[ApiController]
[Route("api/notifications")]
public sealed class NotificationsController : ControllerBase
{
    private readonly INotificationService _notificationService;

    public NotificationsController(INotificationService notificationService)
    {
        _notificationService = notificationService;
    }

    [HttpGet]
    public async Task<ActionResult<List<NotificationDto>>> GetHistory(
        [FromQuery] Guid userId,
        CancellationToken cancellationToken,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        [FromQuery] bool? isRead = null)
    {
        if (userId == Guid.Empty)
        {
            return BadRequest(new { message = "User id is required." });
        }

        var notifications = await _notificationService.GetUserNotificationsAsync(
            userId,
            page,
            pageSize,
            isRead,
            cancellationToken);
        return Ok(notifications);
    }

    [HttpGet("unread-count")]
    public async Task<ActionResult<object>> GetUnreadCount(
        [FromQuery] Guid userId,
        CancellationToken cancellationToken)
    {
        if (userId == Guid.Empty)
        {
            return BadRequest(new { message = "User id is required." });
        }

        var count = await _notificationService.GetUnreadCountAsync(userId, cancellationToken);
        return Ok(new { unreadCount = count });
    }

    [HttpPut("{notificationId:guid}/read")]
    public async Task<ActionResult> MarkAsRead(
        [FromRoute] Guid notificationId,
        [FromQuery] Guid userId,
        CancellationToken cancellationToken)
    {
        if (userId == Guid.Empty)
        {
            return BadRequest(new { message = "User id is required." });
        }

        var updated = await _notificationService.MarkAsReadAsync(userId, notificationId, cancellationToken);
        if (!updated)
        {
            return NotFound(new { message = "Notification not found." });
        }

        return NoContent();
    }

    [HttpPut("read-all")]
    public async Task<ActionResult> MarkAllAsRead(
        [FromQuery] Guid userId,
        CancellationToken cancellationToken)
    {
        if (userId == Guid.Empty)
        {
            return BadRequest(new { message = "User id is required." });
        }

        await _notificationService.MarkAllAsReadAsync(userId, cancellationToken);
        return NoContent();
    }

    [HttpPost("device-token")]
    public async Task<ActionResult> RegisterDeviceToken(
        [FromBody] RegisterDeviceTokenRequest request,
        CancellationToken cancellationToken)
    {
        if (request.UserId == Guid.Empty)
        {
            return BadRequest(new { message = "User id is required." });
        }
        if (string.IsNullOrWhiteSpace(request.Platform))
        {
            return BadRequest(new { message = "Platform is required." });
        }
        if (string.IsNullOrWhiteSpace(request.Token))
        {
            return BadRequest(new { message = "Token is required." });
        }

        await _notificationService.RegisterDeviceTokenAsync(
            request.UserId,
            request.Platform,
            request.Token,
            cancellationToken);
        return NoContent();
    }

    [HttpPost("send")]
    public async Task<ActionResult<object>> SendNotification(
        [FromBody] CreateNotificationRequest request,
        CancellationToken cancellationToken)
    {
        if (!TryParseType(request.Type, out var type))
        {
            return BadRequest(new { message = "Invalid notification type." });
        }
        if (string.IsNullOrWhiteSpace(request.Title) || string.IsNullOrWhiteSpace(request.Message))
        {
            return BadRequest(new { message = "Title and message are required." });
        }

        if (request.UserId.HasValue)
        {
            var sent = await _notificationService.SendToUserAsync(
                request.UserId.Value,
                type,
                request.Title,
                request.Message,
                request.RelatedOrderId,
                request.Data,
                cancellationToken);
            if (sent is null)
            {
                return Ok(new { skipped = true, message = "Notifications are disabled for this user." });
            }

            return Ok(sent);
        }

        if (request.RoleId.HasValue)
        {
            var role = request.RoleId.Value switch
            {
                1 => UserRole.RestaurantOwner,
                2 => UserRole.Customer,
                3 => UserRole.Courier,
                _ => (UserRole?)null,
            };
            if (!role.HasValue)
            {
                return BadRequest(new { message = "Invalid role id." });
            }

            var count = await _notificationService.SendToRoleAsync(
                role.Value,
                type,
                request.Title,
                request.Message,
                request.RelatedOrderId,
                request.Data,
                cancellationToken);
            return Ok(new { sentCount = count });
        }

        return BadRequest(new { message = "Either userId or roleId is required." });
    }

    private static bool TryParseType(string value, out NotificationType type)
    {
        type = NotificationType.Generic;
        if (string.IsNullOrWhiteSpace(value))
        {
            return false;
        }

        if (Enum.TryParse<NotificationType>(value.Trim(), ignoreCase: true, out var parsed))
        {
            type = parsed;
            return true;
        }

        return int.TryParse(value, out var intValue) &&
               Enum.IsDefined(typeof(NotificationType), intValue) &&
               Assign((NotificationType)intValue, out type);
    }

    private static bool Assign(NotificationType source, out NotificationType target)
    {
        target = source;
        return true;
    }
}
