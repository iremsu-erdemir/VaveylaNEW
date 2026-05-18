using Vaveyla.Api.Models;

namespace Vaveyla.Api.Data;

/// <summary>
/// Müşteri uygulamasında sipariş satırı: havuzda (kurye atanmamış) <see cref="CustomerOrderStatus.Assigned"/>
/// ile gerçekten atanmış kurye ayrımı.
/// </summary>
public static class CustomerOrderCustomerDisplay
{
    public static bool IsAwaitingCourierAssignment(CustomerOrder order) =>
        order.Status == CustomerOrderStatus.AwaitingCourierReassignment ||
        (order.Status == CustomerOrderStatus.Assigned && !order.AssignedCourierUserId.HasValue);

    public static Guid? ResolveCourierUserIdForCustomer(
        CustomerOrder order,
        IReadOnlyDictionary<Guid, Guid> courierUserIdFromChat)
    {
        if (IsAwaitingCourierAssignment(order))
        {
            return null;
        }

        if (order.AssignedCourierUserId.HasValue)
        {
            return order.AssignedCourierUserId.Value;
        }

        return courierUserIdFromChat.TryGetValue(order.OrderId, out var uid) ? uid : null;
    }

    public static string MapStatusForCustomerApp(CustomerOrder order)
    {
        if (IsAwaitingCourierAssignment(order))
        {
            return "awaitingCourier";
        }

        return order.Status switch
        {
            CustomerOrderStatus.Pending => "pending",
            CustomerOrderStatus.Preparing => "preparing",
            CustomerOrderStatus.Assigned => "assigned",
            CustomerOrderStatus.InTransit => "inTransit",
            CustomerOrderStatus.Delivered => "completed",
            CustomerOrderStatus.Cancelled => "canceled",
            CustomerOrderStatus.AwaitingCourierReassignment => "awaitingCourier",
            CustomerOrderStatus.RefundRequested => "refundRequested",
            _ => "pending",
        };
    }
}
