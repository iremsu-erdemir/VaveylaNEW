using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Vaveyla.Api.Data;
using Vaveyla.Api.Hubs;
using Vaveyla.Api.Models;
using Vaveyla.Api.Services;

namespace Vaveyla.Api.Controllers;

[ApiController]
[Route("api/location")]
public sealed class LocationController : ControllerBase
{
    private readonly ICustomerOrdersRepository _ordersRepository;
    private readonly IUserRepository _usersRepository;
    private readonly IRestaurantOwnerRepository _restaurantRepo;
    private readonly IHubContext<TrackingHub> _hubContext;
    private readonly IUserSuspensionService _suspension;

    public LocationController(
        ICustomerOrdersRepository ordersRepository,
        IUserRepository usersRepository,
        IRestaurantOwnerRepository restaurantRepo,
        IHubContext<TrackingHub> hubContext,
        IUserSuspensionService suspension)
    {
        _ordersRepository = ordersRepository;
        _usersRepository = usersRepository;
        _restaurantRepo = restaurantRepo;
        _hubContext = hubContext;
        _suspension = suspension;
    }

    [HttpPost("orders/{orderId:guid}/start")]
    public async Task<IActionResult> StartTracking(
        [FromRoute] Guid orderId,
        [FromQuery] Guid courierUserId,
        CancellationToken cancellationToken)
    {
        var order = await _ordersRepository.GetOrderAsync(orderId, cancellationToken);
        if (order is null)
        {
            return NotFound(new { message = "Order not found." });
        }

        if (order.AssignedCourierUserId is null || order.AssignedCourierUserId.Value != courierUserId)
        {
            return Conflict(new { message = "Order is not assigned to this courier." });
        }

        if (order.Status == CustomerOrderStatus.Delivered)
        {
            return BadRequest(new { message = "Teslim edilmiş sipariş için takip başlatılamaz." });
        }

        var courierStart = await _usersRepository.GetByIdAsync(courierUserId, cancellationToken);
        _suspension.ThrowIfOperationallyBlocked(
            courierStart,
            "Hesabınız askıda veya kalıcı olarak kapatılmış; takip başlatılamaz.");

        await _hubContext.Clients
            .Group(TrackingHub.GroupName(orderId.ToString()))
            .SendAsync(
                "tracking_status_changed",
                new { orderId, isTrackingActive = true, timestampUtc = DateTime.UtcNow },
                cancellationToken);

        return NoContent();
    }

    [HttpPost("orders/{orderId:guid}/stop")]
    public async Task<IActionResult> StopTracking(
        [FromRoute] Guid orderId,
        [FromQuery] Guid courierUserId,
        CancellationToken cancellationToken)
    {
        var order = await _ordersRepository.GetOrderAsync(orderId, cancellationToken);
        if (order is null)
        {
            return NotFound(new { message = "Order not found." });
        }

        if (order.AssignedCourierUserId is null || order.AssignedCourierUserId.Value != courierUserId)
        {
            return Conflict(new { message = "Order is not assigned to this courier." });
        }

        var courierStop = await _usersRepository.GetByIdAsync(courierUserId, cancellationToken);
        _suspension.ThrowIfOperationallyBlocked(
            courierStop,
            "Hesabınız askıda veya kalıcı olarak kapatılmış; takip durdurulamaz.");

        await _hubContext.Clients
            .Group(TrackingHub.GroupName(orderId.ToString()))
            .SendAsync(
                "tracking_status_changed",
                new { orderId, isTrackingActive = false, timestampUtc = DateTime.UtcNow },
                cancellationToken);

        return NoContent();
    }

    [HttpPost("update")]
    public async Task<IActionResult> UpdateLocation(
        [FromBody] LocationUpdateDto request,
        CancellationToken cancellationToken)
    {
        var order = await _ordersRepository.GetOrderAsync(request.OrderId, cancellationToken);
        if (order is null)
        {
            return NotFound(new { message = "Order not found." });
        }

        if (order.AssignedCourierUserId is null ||
            order.AssignedCourierUserId.Value != request.CourierUserId)
        {
            return Conflict(new { message = "Order is not assigned to this courier." });
        }

        var courierUpdate = await _usersRepository.GetByIdAsync(request.CourierUserId, cancellationToken);
        _suspension.ThrowIfOperationallyBlocked(
            courierUpdate,
            "Hesabınız askıda veya kalıcı olarak kapatılmış; konum paylaşılamaz.");

        var timestamp = request.TimestampUtc?.ToUniversalTime() ?? DateTime.UtcNow;
        order.CourierLat = request.Lat;
        order.CourierLng = request.Lng;
        order.CourierLocationUpdatedAtUtc = timestamp;
        await _ordersRepository.UpdateOrderStatusAsync(order, cancellationToken);
        await _ordersRepository.AddCourierLocationAsync(new CourierLocationLog
        {
            CourierLocationLogId = Guid.NewGuid(),
            OrderId = order.OrderId,
            CourierUserId = request.CourierUserId,
            Latitude = request.Lat,
            Longitude = request.Lng,
            TimestampUtc = timestamp,
            CreatedAtUtc = DateTime.UtcNow,
        }, cancellationToken);

        var courier = await _usersRepository.GetByIdAsync(request.CourierUserId, cancellationToken);
        var courierDetails = courier is null
            ? null
            : BuildCourierDetails(courier, request.CourierUserId);

        await _hubContext.Clients
            .Group(TrackingHub.GroupName(request.OrderId.ToString()))
            .SendAsync(
                "location_updated",
                new
                {
                    orderId = request.OrderId,
                    lat = request.Lat,
                    lng = request.Lng,
                    bearing = request.Bearing,
                    timestampUtc = timestamp,
                    courier = courierDetails,
                },
                cancellationToken);

        return NoContent();
    }

    [HttpGet("orders/{orderId:guid}/snapshot")]
    public async Task<ActionResult<TrackingSnapshotDto>> GetTrackingSnapshot(
        [FromRoute] Guid orderId,
        [FromQuery] Guid customerUserId,
        CancellationToken cancellationToken)
    {
        var order = await _ordersRepository.GetOrderAsync(orderId, cancellationToken);
        if (order is null)
        {
            return NotFound(new { message = "Order not found." });
        }

        if (order.CustomerUserId != customerUserId)
        {
            return NotFound(new { message = "Order not found." });
        }

        CourierDetailsDto? courierDetails = null;
        if (order.AssignedCourierUserId.HasValue)
        {
            var courier = await _usersRepository.GetByIdAsync(order.AssignedCourierUserId.Value, cancellationToken);
            if (courier is not null)
            {
                courierDetails = BuildCourierDetails(courier, order.AssignedCourierUserId.Value);
            }
        }

        var rr = await _restaurantRepo.GetRestaurantByIdAsync(order.RestaurantId, cancellationToken);
        var rLat = order.RestaurantLat ?? rr?.Latitude;
        var rLng = order.RestaurantLng ?? rr?.Longitude;
        var rAddr = !string.IsNullOrWhiteSpace(order.RestaurantAddress)
            ? order.RestaurantAddress
            : rr?.Address;

        return Ok(new TrackingSnapshotDto(
            order.OrderId,
            order.Items,
            order.DeliveryAddress,
            order.CustomerLat,
            order.CustomerLng,
            order.CourierLat,
            order.CourierLng,
            null,
            order.CourierLocationUpdatedAtUtc,
            order.Status == CustomerOrderStatus.Assigned || order.Status == CustomerOrderStatus.InTransit,
            courierDetails,
            rLat,
            rLng,
            rAddr,
            string.IsNullOrWhiteSpace(rr?.Name) ? null : rr.Name.Trim(),
            string.IsNullOrWhiteSpace(order.CustomerName) ? null : order.CustomerName.Trim(),
            string.IsNullOrWhiteSpace(order.CustomerPhone) ? null : order.CustomerPhone.Trim()));
    }

    private CourierDetailsDto BuildCourierDetails(User courier, Guid courierUserId)
    {
        var fullName = courier.FullName?.Trim() ?? string.Empty;
        var split = fullName.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        var firstName = split.FirstOrDefault() ?? fullName;
        var lastName = split.Length > 1 ? string.Join(' ', split.Skip(1)) : string.Empty;
        var photoUrl = BuildPublicUrl(courier.ProfilePhotoPath);

        return new CourierDetailsDto(
            courierUserId,
            firstName,
            lastName,
            fullName,
            courier.Phone,
            photoUrl);
    }

    private string? BuildPublicUrl(string? relativePath)
    {
        if (string.IsNullOrWhiteSpace(relativePath))
        {
            return null;
        }

        var normalized = relativePath.Trim().TrimStart('/');
        return $"{Request.Scheme}://{Request.Host}/{normalized}";
    }
}
