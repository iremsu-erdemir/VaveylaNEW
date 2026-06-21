using Vaveyla.Api.Models;

namespace Vaveyla.Api.Services;

public static class CartResponseExtensions
{
    public static CalculateCartResponse WithDeliveryRules(
        this CalculateCartResponse response,
        decimal deliveryFee,
        decimal? minimumOrderAmount,
        double? distanceKm,
        bool isDeliverable,
        string? deliveryMessage)
    {
        var subtotal = response.FinalPrice;
        var meetsMin = !minimumOrderAmount.HasValue || subtotal >= minimumOrderAmount.Value;
        var gap = meetsMin ? 0 : minimumOrderAmount!.Value - subtotal;
        var grandTotal = isDeliverable && meetsMin ? subtotal + deliveryFee : subtotal;

        return response with
        {
            Subtotal = subtotal,
            DeliveryFee = deliveryFee,
            MinimumOrderAmount = minimumOrderAmount,
            MeetsMinimumOrder = meetsMin,
            MinimumOrderGap = gap,
            DistanceKm = distanceKm,
            IsDeliverable = isDeliverable,
            DeliveryMessage = deliveryMessage,
            FinalPrice = grandTotal,
            CustomerPaidAmount = grandTotal,
        };
    }
}
