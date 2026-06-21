using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Data;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Services;

public interface IDeliveryRulesService
{
    Task<DeliveryValidationResponse> ValidateDeliveryAsync(
        DeliveryValidationRequest request,
        CancellationToken ct = default);

    Task<(decimal DeliveryFee, double DistanceKm, bool IsDeliverable, string? Message)> ComputeDeliveryAsync(
        Guid restaurantId,
        double? customerLat,
        double? customerLng,
        decimal subtotalAfterDiscount,
        CancellationToken ct = default);
}

public sealed class DeliveryRulesService : IDeliveryRulesService
{
    private readonly VaveylaDbContext _db;

    public DeliveryRulesService(VaveylaDbContext db)
    {
        _db = db;
    }

    public async Task<DeliveryValidationResponse> ValidateDeliveryAsync(
        DeliveryValidationRequest request,
        CancellationToken ct = default)
    {
        var (fee, distanceKm, deliverable, message) = await ComputeDeliveryAsync(
            request.RestaurantId,
            request.CustomerLat,
            request.CustomerLng,
            0,
            ct);

        var restaurant = await _db.Restaurants.AsNoTracking()
            .Where(r => r.RestaurantId == request.RestaurantId)
            .Select(r => new { r.MinimumOrderAmount, r.MaxDeliveryDistanceKm })
            .FirstOrDefaultAsync(ct);

        return new DeliveryValidationResponse(
            deliverable,
            distanceKm,
            fee,
            restaurant?.MinimumOrderAmount,
            restaurant?.MaxDeliveryDistanceKm,
            message);
    }

    public async Task<(decimal DeliveryFee, double DistanceKm, bool IsDeliverable, string? Message)> ComputeDeliveryAsync(
        Guid restaurantId,
        double? customerLat,
        double? customerLng,
        decimal subtotalAfterDiscount,
        CancellationToken ct = default)
    {
        var restaurant = await _db.Restaurants.AsNoTracking()
            .FirstOrDefaultAsync(r => r.RestaurantId == restaurantId, ct);

        if (restaurant is null)
        {
            return (0, 0, false, "Pastane bulunamadı.");
        }

        if (!restaurant.Latitude.HasValue || !restaurant.Longitude.HasValue ||
            !customerLat.HasValue || !customerLng.HasValue)
        {
            return (0, 0, true, null);
        }

        var distanceKm = HaversineKm(
            restaurant.Latitude.Value,
            restaurant.Longitude.Value,
            customerLat.Value,
            customerLng.Value);

        if (distanceKm > (double)restaurant.MaxDeliveryDistanceKm)
        {
            return (
                0,
                distanceKm,
                false,
                $"Teslimat bölgesi dışındasınız ({distanceKm:F1} km). Maksimum: {restaurant.MaxDeliveryDistanceKm:F0} km.");
        }

        if (restaurant.FreeDeliveryThreshold.HasValue &&
            subtotalAfterDiscount >= restaurant.FreeDeliveryThreshold.Value)
        {
            return (0, distanceKm, true, null);
        }

        var fee = Math.Round((decimal)distanceKm * restaurant.DeliveryFeePerKm, 0, MidpointRounding.AwayFromZero);
        return (fee, distanceKm, true, null);
    }

    public static double HaversineKm(double lat1, double lon1, double lat2, double lon2)
    {
        const double earthRadiusKm = 6371;
        var dLat = DegreesToRadians(lat2 - lat1);
        var dLon = DegreesToRadians(lon2 - lon1);
        var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
                Math.Cos(DegreesToRadians(lat1)) * Math.Cos(DegreesToRadians(lat2)) *
                Math.Sin(dLon / 2) * Math.Sin(dLon / 2);
        var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
        return earthRadiusKm * c;
    }

    private static double DegreesToRadians(double degrees) => degrees * Math.PI / 180;
}
