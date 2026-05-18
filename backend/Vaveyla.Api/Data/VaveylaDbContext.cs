using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Data;

public sealed class VaveylaDbContext : DbContext
{
    public VaveylaDbContext(DbContextOptions<VaveylaDbContext> options)
        : base(options)
    {
    }

    public DbSet<Campaign> Campaigns => Set<Campaign>();
    public DbSet<User> Users => Set<User>();
    public DbSet<UserAddress> UserAddresses => Set<UserAddress>();
    public DbSet<PaymentCard> PaymentCards => Set<PaymentCard>();
    public DbSet<UserFeedback> UserFeedbacks => Set<UserFeedback>();
    public DbSet<Feedback> Feedbacks => Set<Feedback>();
    public DbSet<Penalty> Penalties => Set<Penalty>();
    public DbSet<AdminActionLog> AdminActionLogs => Set<AdminActionLog>();
    public DbSet<Restaurant> Restaurants => Set<Restaurant>();
    public DbSet<MenuItem> MenuItems => Set<MenuItem>();
    public DbSet<RestaurantOrder> RestaurantOrders => Set<RestaurantOrder>();
    public DbSet<RestaurantReview> RestaurantReviews => Set<RestaurantReview>();
    public DbSet<ReviewReport> ReviewReports => Set<ReviewReport>();
    public DbSet<RestaurantChatMessage> RestaurantChatMessages => Set<RestaurantChatMessage>();
    public DbSet<CustomerFavorite> CustomerFavorites => Set<CustomerFavorite>();
    public DbSet<CustomerOrder> CustomerOrders => Set<CustomerOrder>();
    public DbSet<CustomerCartItem> CustomerCartItems => Set<CustomerCartItem>();
    public DbSet<Coupon> Coupons => Set<Coupon>();
    public DbSet<UserCoupon> UserCoupons => Set<UserCoupon>();
    public DbSet<CourierLocationLog> CourierLocationLogs => Set<CourierLocationLog>();
    public DbSet<DeliveryChatMessage> DeliveryChatMessages => Set<DeliveryChatMessage>();
    public DbSet<CustomerChatInboxHide> CustomerChatInboxHides => Set<CustomerChatInboxHide>();
    public DbSet<CourierOrderRefusal> CourierOrderRefusals => Set<CourierOrderRefusal>();
    public DbSet<Notification> Notifications => Set<Notification>();
    public DbSet<UserDeviceToken> UserDeviceTokens => Set<UserDeviceToken>();
    public DbSet<HomeMarketingBanner> HomeMarketingBanners => Set<HomeMarketingBanner>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        var user = modelBuilder.Entity<User>();
        user.ToTable("Users");
        user.HasKey(x => x.UserId);
        user.Property(x => x.FullName).HasMaxLength(120).IsRequired();
        user.Property(x => x.Email).HasMaxLength(256).IsRequired();
        user.Property(x => x.Phone).HasMaxLength(40);
        user.Property(x => x.Address).HasMaxLength(320);
        user.Property(x => x.PasswordHash).HasMaxLength(200).IsRequired();
        user.Property(x => x.ProfilePhotoPath).HasMaxLength(512);
        user.Property(x => x.Role)
            .HasConversion<byte>()
            .IsRequired();
        user.Property(x => x.IsPrivacyPolicyAccepted)
            .HasDefaultValue(false)
            .IsRequired();
        user.Property(x => x.IsTermsOfServiceAccepted)
            .HasDefaultValue(false)
            .IsRequired();
        user.Property(x => x.CreatedAtUtc)
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();
        user.Property(x => x.PasswordResetCodeHash).HasMaxLength(200);
        user.Property(x => x.PasswordResetCodeExpiresAtUtc);
        user.Property(x => x.PasswordResetVerifiedAtUtc);
        user.Property(x => x.TotalPenaltyPoints).HasDefaultValue(0).IsRequired();
        user.Property(x => x.SuspendedUntilUtc);
        user.Property(x => x.IsPermanentlyBanned).HasDefaultValue(false).IsRequired();
        user.Property(x => x.NotificationEnabled).HasDefaultValue(true).IsRequired();
        user.HasIndex(x => x.Email).IsUnique();
        user.HasMany(x => x.Addresses)
            .WithOne(x => x.User)
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Cascade);
        user.HasMany(x => x.PaymentCards)
            .WithOne(x => x.User)
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Cascade);
        user.HasMany(x => x.Feedbacks)
            .WithOne(x => x.User)
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        var userAddress = modelBuilder.Entity<UserAddress>();
        userAddress.ToTable("UserAddresses");
        userAddress.HasKey(x => x.AddressId);
        userAddress.Property(x => x.UserId).IsRequired();
        userAddress.Property(x => x.Label).HasMaxLength(64).IsRequired();
        userAddress.Property(x => x.AddressLine).HasMaxLength(320).IsRequired();
        userAddress.Property(x => x.AddressDetail).HasMaxLength(320);
        userAddress.Property(x => x.IsSelected).HasDefaultValue(false).IsRequired();
        userAddress.Property(x => x.CreatedAtUtc)
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();
        userAddress.HasIndex(x => x.UserId);

        var paymentCard = modelBuilder.Entity<PaymentCard>();
        paymentCard.ToTable("PaymentCards");
        paymentCard.HasKey(x => x.PaymentCardId);
        paymentCard.Property(x => x.UserId).IsRequired();
        paymentCard.Property(x => x.CardholderName).HasMaxLength(120).IsRequired();
        paymentCard.Property(x => x.CardNumber).HasMaxLength(32).IsRequired();
        paymentCard.Property(x => x.Expiration).HasMaxLength(10).IsRequired();
        paymentCard.Property(x => x.CVC).HasColumnName("CVV").HasMaxLength(4).IsRequired();
        paymentCard.Property(x => x.BankName).HasMaxLength(120).IsRequired();
        paymentCard.Property(x => x.CardAlias).HasMaxLength(80).IsRequired();
        paymentCard.Property(x => x.CreatedAtUtc)
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();
        paymentCard.HasIndex(x => x.UserId);

        var feedback = modelBuilder.Entity<UserFeedback>();
        feedback.ToTable("UserFeedbacks");
        feedback.HasKey(x => x.FeedbackId);
        feedback.Property(x => x.UserId).IsRequired();
        feedback.Property(x => x.RestaurantName).HasMaxLength(160).IsRequired();
        feedback.Property(x => x.Message).HasMaxLength(1200).IsRequired();
        feedback.Property(x => x.CreatedAtUtc)
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();
        feedback.HasIndex(x => x.UserId);

        var customerFeedback = modelBuilder.Entity<Feedback>();
        customerFeedback.ToTable("Feedbacks");
        customerFeedback.HasKey(x => x.Id);
        customerFeedback.Property(x => x.Id).UseIdentityColumn();
        customerFeedback.Property(x => x.CustomerId).IsRequired();
        customerFeedback.Property(x => x.TargetType).HasConversion<byte>().IsRequired();
        customerFeedback.Property(x => x.TargetEntityId).IsRequired();
        customerFeedback.Property(x => x.Message).HasMaxLength(1200).IsRequired();
        customerFeedback.Property(x => x.Status).HasConversion<byte>().IsRequired();
        customerFeedback.Property(x => x.CreatedAtUtc)
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();
        customerFeedback.HasIndex(x => x.CustomerId);
        customerFeedback.HasIndex(x => x.CreatedAtUtc);
        customerFeedback.HasIndex(x => new { x.TargetType, x.TargetEntityId });

        var penalty = modelBuilder.Entity<Penalty>();
        penalty.ToTable("Penalties");
        penalty.HasKey(x => x.Id);
        penalty.Property(x => x.Id).UseIdentityColumn();
        penalty.Property(x => x.UserId).IsRequired();
        penalty.Property(x => x.Points).IsRequired();
        penalty.Property(x => x.Type).HasConversion<byte>().IsRequired();
        penalty.Property(x => x.CreatedAtUtc)
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();
        penalty.Property(x => x.SuspendedUntil);
        penalty.HasIndex(x => x.UserId);
        penalty.HasIndex(x => x.CreatedAtUtc);

        var adminLog = modelBuilder.Entity<AdminActionLog>();
        adminLog.ToTable("AdminActionLogs");
        adminLog.HasKey(x => x.Id);
        adminLog.Property(x => x.Id).UseIdentityColumn();
        adminLog.Property(x => x.AdminUserId).IsRequired();
        adminLog.Property(x => x.ActionType).HasConversion<byte>().IsRequired();
        adminLog.Property(x => x.Details).HasMaxLength(2000).IsRequired();
        adminLog.Property(x => x.RelatedFeedbackId);
        adminLog.Property(x => x.RelatedUserId);
        adminLog.Property(x => x.CreatedAtUtc)
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();
        adminLog.HasIndex(x => x.AdminUserId);
        adminLog.HasIndex(x => x.CreatedAtUtc);

        var restaurant = modelBuilder.Entity<Restaurant>();
        restaurant.ToTable("Restaurants");
        restaurant.HasKey(x => x.RestaurantId);
        restaurant.Property(x => x.OwnerUserId).IsRequired();
        restaurant.Property(x => x.Name).HasMaxLength(160).IsRequired();
        restaurant.Property(x => x.Type).HasMaxLength(120).IsRequired();
        restaurant.Property(x => x.Address).HasMaxLength(320).IsRequired();
        restaurant.Property(x => x.Phone).HasMaxLength(40).IsRequired();
        restaurant.Property(x => x.WorkingHours).HasMaxLength(60).IsRequired();
        restaurant.Property(x => x.Latitude);
        restaurant.Property(x => x.Longitude);
        restaurant.Property(x => x.PhotoPath).HasMaxLength(512);
        restaurant.Property(x => x.OrderNotifications).HasDefaultValue(true).IsRequired();
        restaurant.Property(x => x.IsOpen).HasDefaultValue(true).IsRequired();
        restaurant.Property(x => x.CommissionRate).HasPrecision(5, 4).HasDefaultValue(0.10m).IsRequired();
        restaurant.Property(x => x.RestaurantDiscountPercent).HasPrecision(5, 2);
        restaurant.Property(x => x.RestaurantDiscountApproved).HasDefaultValue(false).IsRequired();
        restaurant.Property(x => x.RestaurantDiscountIsActive).HasDefaultValue(true).IsRequired();
        restaurant.Property(x => x.IsEnabled).HasDefaultValue(true).IsRequired();
        restaurant.Property(x => x.CreatedAtUtc)
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();
        restaurant.HasIndex(x => x.OwnerUserId).IsUnique();

        var menuItem = modelBuilder.Entity<MenuItem>();
        menuItem.ToTable("MenuItems");
        menuItem.HasKey(x => x.MenuItemId);
        menuItem.Property(x => x.RestaurantId).IsRequired();
        menuItem.Property(x => x.CategoryName).HasMaxLength(80);
        menuItem.Property(x => x.Name).HasMaxLength(160).IsRequired();
        menuItem.Property(x => x.Price).IsRequired();
        menuItem.Property(x => x.SaleUnit).HasDefaultValue((byte)0).IsRequired();
        menuItem.Property(x => x.ImagePath).HasMaxLength(512).IsRequired();
        menuItem.Property(x => x.IsAvailable).HasDefaultValue(true).IsRequired();
        menuItem.Property(x => x.IsFeatured).HasDefaultValue(false).IsRequired();
        menuItem.Property(x => x.CreatedAtUtc)
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();
        menuItem.HasIndex(x => x.RestaurantId);

        var order = modelBuilder.Entity<RestaurantOrder>();
        order.ToTable("RestaurantOrders");
        order.HasKey(x => x.OrderId);
        order.Property(x => x.RestaurantId).IsRequired();
        order.Property(x => x.Items).HasMaxLength(600).IsRequired();
        order.Property(x => x.ImagePath).HasMaxLength(512);
        order.Property(x => x.PreparationMinutes);
        order.Property(x => x.Total).IsRequired();
        order.Property(x => x.Status)
            .HasConversion<byte>()
            .IsRequired();
        order.Property(x => x.CreatedAtUtc)
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();
        order.HasIndex(x => x.RestaurantId);

        var review = modelBuilder.Entity<RestaurantReview>();
        review.ToTable("RestaurantReviews");
        review.HasKey(x => x.ReviewId);
        review.Property(x => x.RestaurantId).IsRequired();
        review.Property(x => x.CustomerUserId).IsRequired();
        review.Property(x => x.TargetType).HasMaxLength(30).IsRequired();
        review.Property(x => x.TargetId).IsRequired();
        review.Property(x => x.ProductId);
        review.Property(x => x.CustomerName).HasMaxLength(120).IsRequired();
        review.Property(x => x.Rating).IsRequired();
        review.Property(x => x.Comment).HasMaxLength(800).IsRequired();
        review.Property(x => x.OwnerReply).HasMaxLength(800);
        review.Property(x => x.CreatedAtUtc)
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();
        review.HasIndex(x => x.RestaurantId);
        review.HasIndex(x => x.CustomerUserId);
        review.HasIndex(x => x.ProductId);
        review.HasIndex(x => new { x.TargetType, x.TargetId });

        var reviewReport = modelBuilder.Entity<ReviewReport>();
        reviewReport.ToTable("ReviewReports");
        reviewReport.HasKey(x => x.ReportId);
        reviewReport.Property(x => x.ReviewId).IsRequired();
        reviewReport.Property(x => x.ReporterUserId).IsRequired();
        reviewReport.Property(x => x.Reason).HasMaxLength(500).IsRequired();
        reviewReport.Property(x => x.Status).HasMaxLength(30).IsRequired();
        reviewReport.Property(x => x.CreatedAtUtc)
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();
        reviewReport.HasIndex(x => x.ReviewId);
        reviewReport.HasIndex(x => x.ReporterUserId);
        reviewReport.HasIndex(x => new { x.ReviewId, x.ReporterUserId }).IsUnique();

        var chatMessage = modelBuilder.Entity<RestaurantChatMessage>();
        chatMessage.ToTable("RestaurantChatMessages");
        chatMessage.HasKey(x => x.ChatMessageId);
        chatMessage.Property(x => x.RestaurantId).IsRequired();
        chatMessage.Property(x => x.CustomerUserId).IsRequired();
        chatMessage.Property(x => x.SenderUserId).IsRequired();
        chatMessage.Property(x => x.SenderType).HasMaxLength(20).IsRequired();
        chatMessage.Property(x => x.Message).HasMaxLength(1500).IsRequired();
        chatMessage.Property(x => x.CreatedAtUtc)
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();
        chatMessage.HasIndex(x => x.RestaurantId);
        chatMessage.HasIndex(x => x.CustomerUserId);
        chatMessage.HasIndex(x => x.CreatedAtUtc);

        var customerFavorite = modelBuilder.Entity<CustomerFavorite>();
        customerFavorite.ToTable("CustomerFavorites");
        customerFavorite.HasKey(x => x.FavoriteId);
        customerFavorite.Property(x => x.CustomerUserId).IsRequired();
        customerFavorite.Property(x => x.FavoriteType).HasMaxLength(20).IsRequired();
        customerFavorite.Property(x => x.TargetId).IsRequired();
        customerFavorite.Property(x => x.CreatedAtUtc)
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();
        customerFavorite.HasIndex(x => x.CustomerUserId);
        customerFavorite.HasIndex(x => new { x.CustomerUserId, x.FavoriteType, x.TargetId })
            .IsUnique();

        var customerOrder = modelBuilder.Entity<CustomerOrder>();
        customerOrder.ToTable("CustomerOrders");
        customerOrder.HasKey(x => x.OrderId);
        customerOrder.Property(x => x.CustomerUserId).IsRequired();
        customerOrder.Property(x => x.RestaurantId).IsRequired();
        customerOrder.Property(x => x.Items).HasMaxLength(800).IsRequired();
        customerOrder.Property(x => x.Total).IsRequired();
        customerOrder.Property(x => x.TotalDiscount).HasPrecision(18, 2).HasDefaultValue(0).IsRequired();
        customerOrder.Property(x => x.AppliedUserCouponId);
        customerOrder.Property(x => x.CouponDiscountAmount).HasPrecision(18, 2);
        customerOrder.Property(x => x.RestaurantEarning).HasPrecision(18, 2).HasDefaultValue(0).IsRequired();
        customerOrder.Property(x => x.PlatformEarning).HasPrecision(18, 2).HasDefaultValue(0).IsRequired();
        customerOrder.Property(x => x.DeliveryAddress).HasMaxLength(400).IsRequired();
        customerOrder.Property(x => x.DeliveryAddressDetail).HasMaxLength(200);
        customerOrder.Property(x => x.CustomerName).HasMaxLength(120);
        customerOrder.Property(x => x.CustomerPhone).HasMaxLength(40);
        customerOrder.Property(x => x.RestaurantAddress).HasMaxLength(400);
        customerOrder.Property(x => x.AssignedCourierUserId);
        customerOrder.Property(x => x.CourierLat);
        customerOrder.Property(x => x.CourierLng);
        customerOrder.Property(x => x.CourierLocationUpdatedAtUtc);
        customerOrder.Property(x => x.Status)
            .HasConversion<byte>()
            .IsRequired();
        customerOrder.Property(x => x.RejectionReason).HasMaxLength(500);
        customerOrder.Property(x => x.CreatedAtUtc)
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();
        customerOrder.HasIndex(x => x.CustomerUserId);
        customerOrder.HasIndex(x => x.RestaurantId);
        customerOrder.HasIndex(x => x.Status);
        customerOrder.HasIndex(x => x.AssignedCourierUserId);

        var courierLocation = modelBuilder.Entity<CourierLocationLog>();
        courierLocation.ToTable("CourierLocationLogs");
        courierLocation.HasKey(x => x.CourierLocationLogId);
        courierLocation.Property(x => x.OrderId).IsRequired();
        courierLocation.Property(x => x.CourierUserId).IsRequired();
        courierLocation.Property(x => x.Latitude).IsRequired();
        courierLocation.Property(x => x.Longitude).IsRequired();
        courierLocation.Property(x => x.TimestampUtc).IsRequired();
        courierLocation.Property(x => x.CreatedAtUtc)
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();
        courierLocation.HasIndex(x => x.OrderId);
        courierLocation.HasIndex(x => x.CourierUserId);
        courierLocation.HasIndex(x => x.TimestampUtc);

        var cartItem = modelBuilder.Entity<CustomerCartItem>();
        cartItem.ToTable("CustomerCartItems");
        cartItem.HasKey(x => x.CartItemId);
        cartItem.Property(x => x.CustomerUserId).IsRequired();
        cartItem.Property(x => x.ProductId).IsRequired();
        cartItem.Property(x => x.RestaurantId).IsRequired();
        cartItem.Property(x => x.ProductName).HasMaxLength(160).IsRequired();
        cartItem.Property(x => x.ImagePath).HasMaxLength(512).IsRequired();
        cartItem.Property(x => x.UnitPrice).IsRequired();
        cartItem.Property(x => x.WeightKg).HasColumnType("decimal(5,2)").IsRequired();
        cartItem.Property(x => x.Quantity).IsRequired();
        cartItem.Property(x => x.SaleUnit).HasDefaultValue((byte)0).IsRequired();
        cartItem.Property(x => x.CreatedAtUtc)
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();
        cartItem.Property(x => x.UpdatedAtUtc)
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();
        cartItem.HasIndex(x => x.CustomerUserId);
        cartItem.HasIndex(x => new { x.CustomerUserId, x.ProductId, x.WeightKg }).IsUnique();

        var notification = modelBuilder.Entity<Notification>();
        notification.ToTable("Notifications");
        notification.HasKey(x => x.NotificationId);
        notification.Property(x => x.UserId).IsRequired();
        notification.Property(x => x.UserRole)
            .HasConversion<byte>()
            .IsRequired();
        notification.Property(x => x.Type)
            .HasConversion<byte>()
            .IsRequired();
        notification.Property(x => x.Title).HasMaxLength(160).IsRequired();
        notification.Property(x => x.Message).HasMaxLength(1200).IsRequired();
        notification.Property(x => x.DataJson).HasMaxLength(4000);
        notification.Property(x => x.RelatedOrderId);
        notification.Property(x => x.IsRead).HasDefaultValue(false).IsRequired();
        notification.Property(x => x.ReadAtUtc);
        notification.Property(x => x.CreatedAtUtc)
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();
        notification.HasIndex(x => x.UserId);
        notification.HasIndex(x => new { x.UserId, x.IsRead, x.CreatedAtUtc });
        notification.HasIndex(x => x.RelatedOrderId);

        var campaign = modelBuilder.Entity<Campaign>();
        campaign.ToTable("Campaigns");
        campaign.HasKey(x => x.CampaignId);
        campaign.Property(x => x.Name).HasMaxLength(200).IsRequired();
        campaign.Property(x => x.Description).HasMaxLength(800);
        campaign.Property(x => x.DiscountType).HasConversion<int>().IsRequired();
        campaign.Property(x => x.DiscountValue).HasPrecision(18, 2).IsRequired();
        campaign.Property(x => x.TargetType).HasConversion<int>().IsRequired();
        campaign.Property(x => x.TargetId);
        campaign.Property(x => x.TargetCategoryName).HasMaxLength(120);
        campaign.Property(x => x.MinCartAmount).HasPrecision(18, 2);
        campaign.Property(x => x.IsActive).HasDefaultValue(true).IsRequired();
        campaign.Property(x => x.Status).HasMaxLength(30).IsRequired();
        campaign.Property(x => x.DiscountOwner).HasConversion<int>().IsRequired();
        campaign.Property(x => x.RestaurantId);
        campaign.Property(x => x.StartDate).IsRequired();
        campaign.Property(x => x.EndDate).IsRequired();
        campaign.Property(x => x.CreatedAtUtc)
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();
        campaign.HasIndex(x => x.RestaurantId);
        campaign.HasIndex(x => new { x.IsActive, x.Status, x.StartDate, x.EndDate });

        var coupon = modelBuilder.Entity<Coupon>();
        coupon.ToTable("Coupons");
        coupon.HasKey(x => x.CouponId);
        coupon.Property(x => x.Code).HasMaxLength(32).IsRequired();
        coupon.Property(x => x.Description).HasMaxLength(400);
        coupon.Property(x => x.DiscountType).HasConversion<int>().IsRequired();
        coupon.Property(x => x.DiscountValue).HasPrecision(18, 2).IsRequired();
        coupon.Property(x => x.MinCartAmount).HasPrecision(18, 2);
        coupon.Property(x => x.MaxDiscountAmount).HasPrecision(18, 2);
        coupon.Property(x => x.ExpiresAtUtc).IsRequired();
        coupon.Property(x => x.RestaurantId);
        coupon.Property(x => x.CreatedAtUtc)
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();
        coupon.HasIndex(x => x.Code).IsUnique();
        coupon.HasIndex(x => x.RestaurantId);

        var userCoupon = modelBuilder.Entity<UserCoupon>();
        userCoupon.ToTable("UserCoupons");
        userCoupon.HasKey(x => x.UserCouponId);
        userCoupon.Property(x => x.UserId).IsRequired();
        userCoupon.Property(x => x.CouponId).IsRequired();
        userCoupon.Property(x => x.Status).HasConversion<int>().IsRequired();
        userCoupon.Property(x => x.UsedAtUtc);
        userCoupon.Property(x => x.OrderId);
        userCoupon.Property(x => x.CreatedAtUtc)
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();
        userCoupon.HasIndex(x => x.UserId);
        userCoupon.HasIndex(x => x.CouponId);
        // Non-unique: Admin can assign same coupon to same user multiple times (each = new UserCoupon instance)
        userCoupon.HasIndex(x => new { x.UserId, x.CouponId });

        var userDeviceToken = modelBuilder.Entity<UserDeviceToken>();
        userDeviceToken.ToTable("UserDeviceTokens");
        userDeviceToken.HasKey(x => x.DeviceTokenId);
        userDeviceToken.Property(x => x.UserId).IsRequired();
        userDeviceToken.Property(x => x.Platform).HasMaxLength(20).IsRequired();
        userDeviceToken.Property(x => x.Token).HasMaxLength(500).IsRequired();
        userDeviceToken.Property(x => x.LastSeenAtUtc).IsRequired();
        userDeviceToken.Property(x => x.CreatedAtUtc)
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();
        userDeviceToken.HasIndex(x => x.UserId);
        userDeviceToken.HasIndex(x => new { x.UserId, x.Token }).IsUnique();

        var deliveryChat = modelBuilder.Entity<DeliveryChatMessage>();
        deliveryChat.ToTable("DeliveryChatMessages");
        deliveryChat.HasKey(x => x.MessageId);
        deliveryChat.Property(x => x.OrderId).IsRequired();
        deliveryChat.Property(x => x.SenderUserId).IsRequired();
        deliveryChat.Property(x => x.Message).HasMaxLength(1500).IsRequired();
        deliveryChat.Property(x => x.CreatedAtUtc)
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();
        deliveryChat.HasIndex(x => x.OrderId);
        deliveryChat.HasIndex(x => new { x.OrderId, x.CreatedAtUtc });

        var inboxHide = modelBuilder.Entity<CustomerChatInboxHide>();
        inboxHide.ToTable("CustomerChatInboxHides");
        inboxHide.HasKey(x => x.HideId);
        inboxHide.Property(x => x.CustomerUserId).IsRequired();
        inboxHide.Property(x => x.HiddenAtUtc)
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();
        inboxHide.HasIndex(x => x.CustomerUserId);
        inboxHide.HasIndex(x => new { x.CustomerUserId, x.RestaurantId })
            .IsUnique()
            .HasFilter("[RestaurantId] IS NOT NULL");
        inboxHide.HasIndex(x => new { x.CustomerUserId, x.OrderId })
            .IsUnique()
            .HasFilter("[OrderId] IS NOT NULL");

        var courierRefusal = modelBuilder.Entity<CourierOrderRefusal>();
        courierRefusal.ToTable("CourierOrderRefusals");
        courierRefusal.HasKey(x => x.RefusalId);
        courierRefusal.Property(x => x.OrderId).IsRequired();
        courierRefusal.Property(x => x.CourierUserId).IsRequired();
        courierRefusal.Property(x => x.Reason).HasMaxLength(600).IsRequired();
        courierRefusal.Property(x => x.CreatedAtUtc)
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();
        courierRefusal.HasIndex(x => new { x.OrderId, x.CourierUserId }).IsUnique();
        courierRefusal.HasIndex(x => x.CourierUserId);

        var marketingBanner = modelBuilder.Entity<HomeMarketingBanner>();
        marketingBanner.ToTable("HomeMarketingBanners");
        marketingBanner.HasKey(x => x.BannerId);
        marketingBanner.Property(x => x.ImageUrl).HasMaxLength(2048).IsRequired();
        marketingBanner.Property(x => x.Title).HasMaxLength(200);
        marketingBanner.Property(x => x.Subtitle).HasMaxLength(300);
        marketingBanner.Property(x => x.BadgeText).HasMaxLength(80);
        marketingBanner.Property(x => x.BodyText).HasMaxLength(2000);
        marketingBanner.Property(x => x.SortOrder).HasDefaultValue(0).IsRequired();
        marketingBanner.Property(x => x.IsActive).HasDefaultValue(true).IsRequired();
        marketingBanner.Property(x => x.ActionType)
            .HasConversion<byte>()
            .IsRequired();
        marketingBanner.Property(x => x.ActionTarget).HasMaxLength(2048);
        marketingBanner.Property(x => x.CreatedAtUtc)
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();
        marketingBanner.Property(x => x.UpdatedAtUtc)
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();
        marketingBanner.HasIndex(x => new { x.IsActive, x.SortOrder });
    }
}
