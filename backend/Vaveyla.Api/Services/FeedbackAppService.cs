using System.Globalization;
using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Data;
using Vaveyla.Api.DTOs;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Services;

public sealed class FeedbackAppService : IFeedbackAppService
{
    /// <summary>Kümülatif puan eşikleri: 10 uyarı, 30 küçük ihlal (yalnızca puan), 50→3g, 70→7g, 100→kalıcı ban.</summary>
    public const int ThresholdWarningPoints = 10;
    public const int ThresholdMinorPenaltyPoints = 30;
    public const int ThresholdSuspend3DaysPoints = 50;
    public const int ThresholdSuspend7DaysPoints = 70;
    public const int ThresholdPermanentBanPoints = 100;

    public const int DefaultAddPenaltyPoints = 20;
    public const int WarningActionPoints = 10;

    private readonly IFeedbackRepository _feedbackRepo;
    private readonly VaveylaDbContext _db;
    private readonly IUserSuspensionService _suspension;
    private readonly INotificationService _notifications;

    public FeedbackAppService(
        IFeedbackRepository feedbackRepo,
        VaveylaDbContext db,
        IUserSuspensionService suspension,
        INotificationService notifications)
    {
        _feedbackRepo = feedbackRepo;
        _db = db;
        _suspension = suspension;
        _notifications = notifications;
    }

    public async Task<int> CreateCustomerFeedbackAsync(
        Guid customerUserId,
        CreateCustomerFeedbackRequest request,
        CancellationToken cancellationToken)
    {
        var message = request.Message.Trim();
        if (message.Length == 0)
        {
            throw new InvalidOperationException("Mesaj boş olamaz.");
        }

        ProfanityValidator.EnsureClean(message, "Mesaj");

        if (request.TargetEntityId == Guid.Empty)
        {
            throw new InvalidOperationException("targetEntityId zorunludur.");
        }

        var customer = await _db.Users.FirstOrDefaultAsync(
            u => u.UserId == customerUserId,
            cancellationToken);
        if (customer is null || customer.Role != UserRole.Customer)
        {
            throw new InvalidOperationException("Sadece müşteri hesabı geri bildirim oluşturabilir.");
        }

        await ValidateTargetAsync(customerUserId, request.TargetType, request.TargetEntityId, cancellationToken);

        var entity = new Feedback
        {
            CustomerId = customerUserId,
            TargetType = request.TargetType,
            TargetEntityId = request.TargetEntityId,
            Message = message,
            Status = FeedbackStatus.New,
            CreatedAtUtc = DateTime.UtcNow,
        };

        await _feedbackRepo.AddFeedbackAsync(entity, cancellationToken);
        await _feedbackRepo.SaveChangesAsync(cancellationToken);
        return entity.Id;
    }

    private async Task ValidateTargetAsync(
        Guid customerUserId,
        FeedbackTargetType targetType,
        Guid targetEntityId,
        CancellationToken cancellationToken)
    {
        switch (targetType)
        {
            case FeedbackTargetType.BakeryProduct:
                var product = await _db.MenuItems.FirstOrDefaultAsync(
                    m => m.MenuItemId == targetEntityId,
                    cancellationToken);
                if (product is null)
                {
                    throw new InvalidOperationException("Ürün bulunamadı.");
                }

                if (!await CustomerHasPurchasedMenuItemAsync(
                        customerUserId,
                        targetEntityId,
                        cancellationToken))
                {
                    throw new InvalidOperationException(
                        "Yalnızca daha önce satın aldığınız ürünler için geri bildirim gönderebilirsiniz.");
                }

                break;

            case FeedbackTargetType.BakeryOrder:
                var order = await _db.CustomerOrders.FirstOrDefaultAsync(
                    o => o.OrderId == targetEntityId,
                    cancellationToken);
                if (order is null)
                {
                    throw new InvalidOperationException("Sipariş bulunamadı.");
                }

                if (order.CustomerUserId != customerUserId)
                {
                    throw new InvalidOperationException("Bu siparişe ait şikayet oluşturamazsınız.");
                }

                break;

            case FeedbackTargetType.Courier:
                var courier = await _db.Users.FirstOrDefaultAsync(
                    u => u.UserId == targetEntityId,
                    cancellationToken);
                if (courier is null || courier.Role != UserRole.Courier)
                {
                    throw new InvalidOperationException("Kurye kullanıcısı bulunamadı.");
                }

                break;

            default:
                throw new InvalidOperationException("Geçersiz hedef türü.");
        }
    }

    public async Task<List<FeedbackAdminListItemDto>> GetAdminFeedbacksAsync(
        CancellationToken cancellationToken)
    {
        var items = await _feedbackRepo.GetAllFeedbacksOrderedAsync(cancellationToken);
        var result = new List<FeedbackAdminListItemDto>(items.Count);
        foreach (var f in items)
        {
            var customer = await _db.Users.AsNoTracking()
                .FirstOrDefaultAsync(u => u.UserId == f.CustomerId, cancellationToken);
            var display = await BuildTargetDisplayAsync(f, cancellationToken);
            string? orderLabel = null;
            string? orderTitle = null;
            if (f.TargetType == FeedbackTargetType.BakeryOrder)
            {
                var o = await _db.CustomerOrders.AsNoTracking()
                    .FirstOrDefaultAsync(x => x.OrderId == f.TargetEntityId, cancellationToken);
                if (o is not null)
                {
                    orderLabel = FormatOrderNumberLabel(o.OrderId);
                    orderTitle = BuildOrderProductTitle(o.Items);
                }
            }

            result.Add(new FeedbackAdminListItemDto(
                f.Id,
                customer?.FullName.Trim() ?? "—",
                display,
                orderLabel,
                orderTitle,
                f.CreatedAtUtc,
                f.Message,
                f.Status,
                MapStatusLabel(f.Status)));
        }

        return result;
    }

    public async Task ApplyAdminActionAsync(
        int feedbackId,
        Guid adminUserId,
        AdminFeedbackActionRequest request,
        CancellationToken cancellationToken)
    {
        var feedback = await _db.Feedbacks.FirstOrDefaultAsync(
            f => f.Id == feedbackId,
            cancellationToken);
        if (feedback is null)
        {
            throw new InvalidOperationException("Geri bildirim bulunamadı.");
        }

        if (feedback.Status == FeedbackStatus.Rejected)
        {
            throw new InvalidOperationException("Reddedilmiş şikayet üzerinde işlem yapılamaz.");
        }

        var admin = await _db.Users.FirstOrDefaultAsync(u => u.UserId == adminUserId, cancellationToken);
        if (admin is null || admin.Role != UserRole.Admin)
        {
            throw new InvalidOperationException("Yetkisiz işlem.");
        }

        switch (request.Action)
        {
            case AdminActionType.RejectFeedback:
                feedback.Status = FeedbackStatus.Rejected;
                await LogAdminAsync(
                    adminUserId,
                    AdminActionType.RejectFeedback,
                    $"Şikayet reddedildi. FeedbackId={feedbackId}",
                    feedbackId,
                    null,
                    cancellationToken);
                await _feedbackRepo.SaveChangesAsync(cancellationToken);
                return;

            case AdminActionType.Warning:
                await ApplyPointsToTargetAsync(
                    feedback,
                    adminUserId,
                    WarningActionPoints,
                    PenaltyType.Warning,
                    cancellationToken);
                break;

            case AdminActionType.AddPenaltyPoints:
                var pts = request.Points is >= 1 and <= 500
                    ? request.Points!.Value
                    : DefaultAddPenaltyPoints;
                await ApplyPointsToTargetAsync(
                    feedback,
                    adminUserId,
                    pts,
                    PenaltyType.PointIncrease,
                    cancellationToken);
                break;

            case AdminActionType.SuspendUser:
                var penalizedSuspend = await ResolvePenalizedUserIdAsync(feedback, cancellationToken);
                var userS = await _db.Users.FirstOrDefaultAsync(
                    u => u.UserId == penalizedSuspend,
                    cancellationToken)
                    ?? throw new InvalidOperationException("Ceza uygulanacak kullanıcı bulunamadı.");

                string durationLabel;
                DateTime suspensionEndUtc;
                if (request.SuspendUntilUtc is { } manualEndRaw)
                {
                    if (request.SuspendDays.HasValue)
                    {
                        throw new InvalidOperationException("suspendDays ve suspendUntilUtc birlikte kullanılamaz.");
                    }

                    var manualEnd = manualEndRaw.Kind == DateTimeKind.Unspecified
                        ? DateTime.SpecifyKind(manualEndRaw, DateTimeKind.Utc)
                        : manualEndRaw.ToUniversalTime();
                    if (manualEnd <= DateTime.UtcNow)
                    {
                        throw new InvalidOperationException("suspendUntilUtc gelecekte bir zaman olmalıdır.");
                    }

                    if (manualEnd > DateTime.UtcNow.AddDays(366))
                    {
                        throw new InvalidOperationException("Askı süresi en fazla 365 gün olabilir.");
                    }

                    _suspension.ExtendSuspensionUntil(userS, manualEnd);
                    suspensionEndUtc = userS.SuspendedUntilUtc
                        ?? throw new InvalidOperationException("Askı bitiş tarihi hesaplanamadı.");
                    var approxDays = (int)Math.Ceiling((suspensionEndUtc - DateTime.UtcNow).TotalDays);
                    durationLabel = $"Manuel (~{approxDays} gün)";
                }
                else if (request.SuspendDays is 3 or 7)
                {
                    suspensionEndUtc = DateTime.UtcNow.AddDays(request.SuspendDays!.Value);
                    _suspension.ExtendSuspensionUntil(userS, suspensionEndUtc);
                    suspensionEndUtc = userS.SuspendedUntilUtc
                        ?? throw new InvalidOperationException("Askı bitiş tarihi hesaplanamadı.");
                    durationLabel = $"{request.SuspendDays} gün";
                }
                else
                {
                    throw new InvalidOperationException(
                        "Askı için suspendDays (3 veya 7) ya da gelecekte bir suspendUntilUtc gönderin.");
                }

                MarkFeedbackResolvedAfterAdminAction(feedback);

                await _feedbackRepo.AddPenaltyAsync(
                    new Penalty
                    {
                        UserId = penalizedSuspend,
                        Points = 0,
                        Type = PenaltyType.Suspension,
                        CreatedAtUtc = DateTime.UtcNow,
                        SuspendedUntil = userS.SuspendedUntilUtc,
                    },
                    cancellationToken);
                await LogAdminAsync(
                    adminUserId,
                    AdminActionType.SuspendUser,
                    $"Askı. PenalizedUserId={penalizedSuspend}, BitişUtc={userS.SuspendedUntilUtc:O}",
                    feedbackId,
                    penalizedSuspend,
                    cancellationToken);

                var reasonPreview = feedback.Message.Trim();
                if (reasonPreview.Length > 200)
                {
                    reasonPreview = reasonPreview[..200] + "…";
                }

                await _notifications.NotifyAccountSuspendedAsync(
                    penalizedSuspend,
                    durationLabel,
                    suspensionEndUtc,
                    reasonPreview,
                    cancellationToken);
                break;

            case AdminActionType.PermanentBan:
                var penalizedBan = await ResolvePenalizedUserIdAsync(feedback, cancellationToken);
                var userB = await _db.Users.FirstOrDefaultAsync(
                    u => u.UserId == penalizedBan,
                    cancellationToken)
                    ?? throw new InvalidOperationException("Ceza uygulanacak kullanıcı bulunamadı.");
                userB.IsPermanentlyBanned = true;
                MarkFeedbackResolvedAfterAdminAction(feedback);

                await _feedbackRepo.AddPenaltyAsync(
                    new Penalty
                    {
                        UserId = penalizedBan,
                        Points = 0,
                        Type = PenaltyType.PermanentBan,
                        CreatedAtUtc = DateTime.UtcNow,
                        SuspendedUntil = null,
                    },
                    cancellationToken);
                await LogAdminAsync(
                    adminUserId,
                    AdminActionType.PermanentBan,
                    $"Kalıcı ban. PenalizedUserId={penalizedBan}",
                    feedbackId,
                    penalizedBan,
                    cancellationToken);
                break;

            default:
                throw new InvalidOperationException("Geçersiz aksiyon.");
        }

        await _feedbackRepo.SaveChangesAsync(cancellationToken);
    }

    /// <summary>Admin ceza/işlem uyguladığında şikayet kapanır; admin nihai mercidir.</summary>
    private static void MarkFeedbackResolvedAfterAdminAction(Feedback feedback)
    {
        if (feedback.Status != FeedbackStatus.Rejected)
        {
            feedback.Status = FeedbackStatus.Resolved;
        }
    }

    private async Task ApplyPointsToTargetAsync(
        Feedback feedback,
        Guid adminUserId,
        int points,
        PenaltyType penaltyType,
        CancellationToken cancellationToken)
    {
        var penalizedUserId = await ResolvePenalizedUserIdAsync(feedback, cancellationToken);
        var user = await _db.Users.FirstOrDefaultAsync(u => u.UserId == penalizedUserId, cancellationToken)
            ?? throw new InvalidOperationException("Ceza uygulanacak kullanıcı bulunamadı.");

        user.TotalPenaltyPoints += points;
        MarkFeedbackResolvedAfterAdminAction(feedback);

        await _feedbackRepo.AddPenaltyAsync(
            new Penalty
            {
                UserId = penalizedUserId,
                Points = points,
                Type = penaltyType,
                CreatedAtUtc = DateTime.UtcNow,
                SuspendedUntil = null,
            },
            cancellationToken);

        await ApplyDynamicCumulativeRulesAsync(user, cancellationToken);

        await LogAdminAsync(
            adminUserId,
            penaltyType == PenaltyType.Warning ? AdminActionType.Warning : AdminActionType.AddPenaltyPoints,
            $"Puan={points}, PenaltyType={penaltyType}, PenalizedUserId={penalizedUserId}, YeniToplam={user.TotalPenaltyPoints}",
            feedback.Id,
            penalizedUserId,
            cancellationToken);
    }

    /// <summary>
    /// Kümülatif puan kuralları: 50→3 gün, 70→7 gün, 100→kalıcı ban (otomatik).
    /// </summary>
    private Task ApplyDynamicCumulativeRulesAsync(User user, CancellationToken cancellationToken)
    {
        var t = user.TotalPenaltyPoints;
        if (t >= ThresholdPermanentBanPoints)
        {
            user.IsPermanentlyBanned = true;
        }
        else if (t >= ThresholdSuspend7DaysPoints)
        {
            _suspension.ExtendSuspensionUntil(user, DateTime.UtcNow.AddDays(7));
        }
        else if (t >= ThresholdSuspend3DaysPoints)
        {
            _suspension.ExtendSuspensionUntil(user, DateTime.UtcNow.AddDays(3));
        }

        _ = cancellationToken;
        return Task.CompletedTask;
    }

    private async Task<Guid> ResolvePenalizedUserIdAsync(Feedback feedback, CancellationToken cancellationToken)
    {
        switch (feedback.TargetType)
        {
            case FeedbackTargetType.BakeryProduct:
                var item = await _db.MenuItems.AsNoTracking()
                    .FirstOrDefaultAsync(m => m.MenuItemId == feedback.TargetEntityId, cancellationToken)
                    ?? throw new InvalidOperationException("Ürün bulunamadı.");
                var rest = await _db.Restaurants.AsNoTracking()
                    .FirstOrDefaultAsync(r => r.RestaurantId == item.RestaurantId, cancellationToken)
                    ?? throw new InvalidOperationException("Pastane bulunamadı.");
                return rest.OwnerUserId;

            case FeedbackTargetType.BakeryOrder:
                var order = await _db.CustomerOrders.AsNoTracking()
                    .FirstOrDefaultAsync(o => o.OrderId == feedback.TargetEntityId, cancellationToken)
                    ?? throw new InvalidOperationException("Sipariş bulunamadı.");
                var restaurant = await _db.Restaurants.AsNoTracking()
                    .FirstOrDefaultAsync(r => r.RestaurantId == order.RestaurantId, cancellationToken)
                    ?? throw new InvalidOperationException("Pastane bulunamadı.");
                return restaurant.OwnerUserId;

            case FeedbackTargetType.Courier:
                return feedback.TargetEntityId;

            default:
                throw new InvalidOperationException("Geçersiz hedef.");
        }
    }

    private async Task<string> BuildTargetDisplayAsync(Feedback f, CancellationToken cancellationToken)
    {
        switch (f.TargetType)
        {
            case FeedbackTargetType.BakeryProduct:
                var m = await _db.MenuItems.AsNoTracking()
                    .FirstOrDefaultAsync(x => x.MenuItemId == f.TargetEntityId, cancellationToken);
                if (m is null) return "—";
                var r = await _db.Restaurants.AsNoTracking()
                    .FirstOrDefaultAsync(x => x.RestaurantId == m.RestaurantId, cancellationToken);
                var bakeryName = r?.Name.Trim() ?? "—";
                return $"{bakeryName} - {m.Name.Trim()}";

            case FeedbackTargetType.BakeryOrder:
                var o = await _db.CustomerOrders.AsNoTracking()
                    .FirstOrDefaultAsync(x => x.OrderId == f.TargetEntityId, cancellationToken);
                if (o is null) return "—";
                var rr = await _db.Restaurants.AsNoTracking()
                    .FirstOrDefaultAsync(x => x.RestaurantId == o.RestaurantId, cancellationToken);
                var bn = rr?.Name.Trim() ?? "—";
                return $"{bn} - {FormatOrderNumberLabel(o.OrderId)} Siparişi";

            case FeedbackTargetType.Courier:
                var c = await _db.Users.AsNoTracking()
                    .FirstOrDefaultAsync(x => x.UserId == f.TargetEntityId, cancellationToken);
                return c?.FullName.Trim() ?? "—";

            default:
                return "—";
        }
    }

    private static string BuildOrderProductTitle(string items)
    {
        var first = items.Split(',')[0].Trim();
        var match = Regex.Match(first, @"^\d+\s*[xX×]\s*(.+)$");
        var title = match.Success ? match.Groups[1].Value.Trim() : first;
        return string.IsNullOrEmpty(title) ? "Sipariş" : title;
    }

    public static string FormatOrderNumberLabel(Guid orderId)
    {
        var bytes = orderId.ToByteArray();
        var n = BitConverter.ToUInt32(bytes, 0) % 90000u + 10000u;
        return "#" + n.ToString(CultureInfo.InvariantCulture);
    }

    private static string MapStatusLabel(FeedbackStatus status) => status switch
    {
        FeedbackStatus.New => "Yeni",
        // Eski kayıtlar (InReview); artık admin işlemi sonrası doğrudan Resolved yazılır.
        FeedbackStatus.InReview => "Sonuçlandı",
        FeedbackStatus.Resolved => "Sonuçlandı",
        FeedbackStatus.Rejected => "Reddedildi",
        _ => status.ToString(),
    };

    private async Task<bool> CustomerHasPurchasedMenuItemAsync(
        Guid customerUserId,
        Guid menuItemId,
        CancellationToken cancellationToken)
    {
        var product = await _db.MenuItems.AsNoTracking()
            .FirstOrDefaultAsync(m => m.MenuItemId == menuItemId, cancellationToken);
        if (product is null)
        {
            return false;
        }

        var deliveredOrders = await _db.CustomerOrders.AsNoTracking()
            .Where(o =>
                o.CustomerUserId == customerUserId &&
                o.Status == CustomerOrderStatus.Delivered &&
                o.RestaurantId == product.RestaurantId)
            .Select(o => o.Items)
            .ToListAsync(cancellationToken);

        if (deliveredOrders.Count == 0)
        {
            return false;
        }

        var menuItems = await _db.MenuItems.AsNoTracking()
            .Where(m => m.RestaurantId == product.RestaurantId)
            .ToListAsync(cancellationToken);
        var normalized = menuItems
            .GroupBy(mi => OrderItemsLineParser.NormalizeName(mi.Name))
            .ToDictionary(g => g.Key, g => g.First());

        foreach (var itemsText in deliveredOrders)
        {
            foreach (var (_, productName) in OrderItemsLineParser.ParseItems(itemsText))
            {
                var matched = OrderItemsLineParser.MatchMenuItem(
                    productName,
                    normalized,
                    menuItems);
                if (matched?.MenuItemId == menuItemId)
                {
                    return true;
                }
            }
        }

        return false;
    }

    private async Task LogAdminAsync(
        Guid adminUserId,
        AdminActionType actionType,
        string details,
        int? feedbackId,
        Guid? relatedUserId,
        CancellationToken cancellationToken)
    {
        await _feedbackRepo.AddAdminLogAsync(
            new AdminActionLog
            {
                AdminUserId = adminUserId,
                ActionType = actionType,
                Details = details,
                RelatedFeedbackId = feedbackId,
                RelatedUserId = relatedUserId,
                CreatedAtUtc = DateTime.UtcNow,
            },
            cancellationToken);
    }
}
