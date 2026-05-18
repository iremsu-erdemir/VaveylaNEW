using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Data;

/// <summary>
/// Seed verisi: Pastane hesapları ve müşteri panelinde görünen ürünler.
/// Pastane paneli giriş bilgileri (SATICI_GIRIS_BILGILERI.md):
/// - mevlana@vaveyla.com / Test123! (Mevlana Pastaneleri - Edirne)
/// - sar@vaveyla.com / Test123! (Şar Pastanesi - Edirne)
/// - safran@vaveyla.com / Test123! (Safran Pastanesi - Edirne)
/// </summary>
public static class DbSeeder
{
    private const string MevlanaEmail = "mevlana@vaveyla.com";
    private const string SarEmail = "sar@vaveyla.com";
    private const string SafranEmail = "safran@vaveyla.com";
    private const string SeedPassword = "Test123!";

    private const string AdminEmail = "admin@vaveyla.com";
    private const string CustomerEmail = "musteri@vaveyla.com";

    public static async Task SeedAsync(VaveylaDbContext db, CancellationToken ct = default)
    {
        await EnsureAdminUserAsync(db, ct);
        await EnsureCustomerUserAsync(db, ct);
        await EnsureRestaurantWithProductsAsync(db, ct);
        await EnsureCouponsAsync(db, ct);
    }

    private static async Task EnsureCustomerUserAsync(VaveylaDbContext db, CancellationToken ct)
    {
        var customer = await db.Users.FirstOrDefaultAsync(u => u.Email == CustomerEmail, ct);
        if (customer is null)
        {
            customer = new User
            {
                UserId = Guid.NewGuid(),
                FullName = "Test Müşteri",
                Email = CustomerEmail,
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(SeedPassword),
                Role = UserRole.Customer,
                IsPrivacyPolicyAccepted = true,
                IsTermsOfServiceAccepted = true,
                CreatedAtUtc = DateTime.UtcNow,
            };
            db.Users.Add(customer);
            await db.SaveChangesAsync(ct);
        }

        var hasAddress = await db.UserAddresses.AnyAsync(a => a.UserId == customer.UserId, ct);
        if (!hasAddress)
        {
            db.UserAddresses.Add(new UserAddress
            {
                AddressId = Guid.NewGuid(),
                UserId = customer.UserId,
                Label = "Ev",
                AddressLine = "Saraçlar Cd. Merkez, Edirne",
                AddressDetail = "Daire 12",
                IsSelected = true,
                CreatedAtUtc = DateTime.UtcNow,
            });
            await db.SaveChangesAsync(ct);
        }
    }

    private static async Task EnsureCouponsAsync(VaveylaDbContext db, CancellationToken ct)
    {
        var exists = await db.Coupons.AnyAsync(c => c.Code == "SAVE20", ct);
        if (exists) return;

        db.Coupons.Add(new Coupon
        {
            CouponId = Guid.NewGuid(),
            Code = "SAVE20",
            Description = "%20 indirim, max 30 TL, min 100 TL sepet",
            DiscountType = CouponDiscountType.Percentage,
            DiscountValue = 20,
            MinCartAmount = 100,
            MaxDiscountAmount = 30,
            ExpiresAtUtc = DateTime.UtcNow.AddMonths(3),
            RestaurantId = null,
            CreatedAtUtc = DateTime.UtcNow,
        });
        db.Coupons.Add(new Coupon
        {
            CouponId = Guid.NewGuid(),
            Code = "FIXED50",
            Description = "50 TL sabit indirim, min 150 TL sepet",
            DiscountType = CouponDiscountType.Fixed,
            DiscountValue = 50,
            MinCartAmount = 150,
            MaxDiscountAmount = null,
            ExpiresAtUtc = DateTime.UtcNow.AddMonths(3),
            RestaurantId = null,
            CreatedAtUtc = DateTime.UtcNow,
        });
        await db.SaveChangesAsync(ct);
    }

    private static async Task EnsureAdminUserAsync(VaveylaDbContext db, CancellationToken ct)
    {
        var exists = await db.Users.AnyAsync(u => u.Role == UserRole.Admin, ct);
        if (exists) return;
        var admin = new User
        {
            UserId = Guid.NewGuid(),
            FullName = "Sistem Yöneticisi",
            Email = AdminEmail,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(SeedPassword),
            Role = UserRole.Admin,
            IsPrivacyPolicyAccepted = true,
            IsTermsOfServiceAccepted = true,
            CreatedAtUtc = DateTime.UtcNow,
        };
        db.Users.Add(admin);
        await db.SaveChangesAsync(ct);
    }

    private static async Task EnsureRestaurantWithProductsAsync(
        VaveylaDbContext db,
        CancellationToken ct)
    {
        var mevlana = await EnsureRestaurantOwnerAsync(db,
            MevlanaEmail,
            "Mevlana Pastaneleri",
            "Mevlana Pastaneleri - 1983'ten beri Edirne'de",
            "Pastalar",
            "Murat Mah. Prf. Dr. Süheyl Ünver Cad. No:5B/19 Merkez/Edirne",
            "0284 235 35 55",
            "05:00 - 00:00",
            41.665744,
            26.572097,
            ct);

        var sar = await EnsureRestaurantOwnerAsync(db,
            SarEmail,
            "Şar Pastanesi",
            "Şar Pastanesi - Çilingir Çarşısı'nda lezzet durağı",
            "Hamur işi",
            "Çilingir Çarşısı D:22, Edirne Merkez",
            "0284 213 41 86",
            "08:00 - 22:00",
            41.675173,
            26.553352,
            ct);

        var safran = await EnsureRestaurantOwnerAsync(db,
            SafranEmail,
            "Safran Pastanesi",
            "Safran Pastanesi - 1. Murat'ta özel tatlar",
            "Donut",
            "Ali Rıza Ataktürk Cad. No:9, 1. Murat, Edirne",
            "0284 212 00 00",
            "10:00 - 22:00",
            41.664016,
            26.569624,
            ct);

        await AddMenuItemsIfMissingAsync(db, sar.RestaurantId, new[]
        {
            ("Çilekli pasta", "Kapkek", 72, "assets/images/cupcake category 1.png", true),
            ("Böğürtlenli pasta", "Kapkek", 90, "assets/images/cupcake category 2.png", true),
            ("Çikolatalı pasta", "Kapkek", 108, "assets/images/cupcake category 3.png", true),
            ("Limonlu kapkek", "Kapkek", 65, "assets/images/cupcake category 1.png", true),
            ("Vanilyalı kapkek", "Kapkek", 70, "assets/images/cupcake category 2.png", true),
            ("Frambuazlı kapkek", "Kapkek", 85, "assets/images/cupcake category 3.png", true),
            ("Muzlu kapkek", "Kapkek", 75, "assets/images/cupcake category 1.png", true),
            ("Hindistan cevizli kapkek", "Kapkek", 68, "assets/images/cupcake category 2.png", true),
            ("Karamelli kapkek", "Kapkek", 82, "assets/images/cupcake category 3.png", true),
            ("Portakallı kapkek", "Kapkek", 78, "assets/images/cupcake category 1.png", true),
            ("Doğum günü pastası", "Doğum günü pastası", 126, "assets/images/birthday cake category 1.png", true),
            ("Kırmızı Kadife Pasta", "Pastalar", 95, "assets/images/red velvet cake with fruit.png", true),
            ("Çikolatalı Pasta", "Pastalar", 85, "assets/images/strawberry chocolate cake.png", true),
            ("Poğaça", "Hamur işi", 25, "assets/images/donut category 1.png", true),
            ("Açma", "Hamur işi", 28, "assets/images/donut category 2.png", true),
            ("Simit", "Hamur işi", 18, "assets/images/donut category 3.png", true),
            ("Kruvasan", "Hamur işi", 35, "assets/images/cupcake category 1.png", true),
            ("Börek", "Hamur işi", 42, "assets/images/cupcake category 2.png", true),
        }, ct);

        await AddMenuItemsIfMissingAsync(db, safran.RestaurantId, new[]
        {
            ("Sünger donut", "Donut", 18, "assets/images/donut category 1.png", true),
            ("Çikolatalı donut", "Donut", 36, "assets/images/donut category 2.png", true),
            ("Donutlar", "Donut", 54, "assets/images/donut category 3.png", true),
            ("Glazürlü donut", "Donut", 22, "assets/images/donut category 1.png", true),
            ("Çilekli donut", "Donut", 28, "assets/images/donut category 2.png", true),
            ("Karamelli donut", "Donut", 32, "assets/images/donut category 3.png", true),
            ("Fındıklı donut", "Donut", 38, "assets/images/donut category 1.png", true),
            ("Beyaz çikolatalı donut", "Donut", 42, "assets/images/donut category 2.png", true),
            ("Sade donut", "Donut", 15, "assets/images/donut category 3.png", true),
            ("Dolgu donut", "Donut", 45, "assets/images/donut category 1.png", true),
            ("Mini donut 6'lı", "Donut", 35, "assets/images/donut category 2.png", true),
            ("Özel donut", "Donut", 55, "assets/images/donut category 3.png", true),
        }, ct);

        await AddMenuItemsIfMissingAsync(db, mevlana.RestaurantId, new[]
        {
            ("Doğum günü pastası", "Doğum günü pastası", 126, "assets/images/birthday cake category 1.png", true),
            ("Doğum günü pastası", "Doğum günü pastası", 140, "assets/images/birthday cake category 2.png", true),
            ("Doğum günü pastası", "Doğum günü pastası", 155, "assets/images/birthday cake category 3.png", true),
            ("Çikolatalı doğum günü pastası", "Doğum günü pastası", 165, "assets/images/birthday cake category 1.png", true),
            ("Meyveli doğum günü pastası", "Doğum günü pastası", 145, "assets/images/birthday cake category 2.png", true),
            ("Kremalı doğum günü pastası", "Doğum günü pastası", 135, "assets/images/birthday cake category 3.png", true),
            ("Özel tasarım doğum günü pastası", "Doğum günü pastası", 185, "assets/images/birthday cake category 1.png", true),
            ("Kırmızı Kadife Pasta", "Pastalar", 95, "assets/images/red velvet cake with fruit.png", true),
            ("Çikolatalı Pasta", "Pastalar", 85, "assets/images/strawberry chocolate cake.png", true),
            ("Meyveli pasta", "Pastalar", 105, "assets/images/cupcake category 1.png", true),
            ("Karamelli pasta", "Pastalar", 115, "assets/images/cupcake category 2.png", true),
            ("Çilekli pasta dilimi", "Pastalar", 75, "assets/images/cupcake category 3.png", true),
            ("Tiramisu pasta", "Pastalar", 125, "assets/images/birthday cake category 1.png", true),
        }, ct);
    }

    private static async Task<(Guid OwnerUserId, Guid RestaurantId)> EnsureRestaurantOwnerAsync(
        VaveylaDbContext db,
        string email,
        string fullName,
        string restaurantName,
        string restaurantType,
        string address,
        string phone,
        string workingHours,
        double latitude,
        double longitude,
        CancellationToken ct)
    {
        var normalizedEmail = email.Trim().ToLowerInvariant();
        var user = await db.Users
            .FirstOrDefaultAsync(u => u.Email == normalizedEmail, ct);

        if (user is null)
        {
            user = new User
            {
                UserId = Guid.NewGuid(),
                FullName = fullName,
                Email = normalizedEmail,
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(SeedPassword),
                Role = UserRole.RestaurantOwner,
                IsPrivacyPolicyAccepted = true,
                IsTermsOfServiceAccepted = true,
                CreatedAtUtc = DateTime.UtcNow,
            };
            db.Users.Add(user);
            await db.SaveChangesAsync(ct);
        }

        var restaurant = await db.Restaurants
            .FirstOrDefaultAsync(r => r.OwnerUserId == user.UserId, ct);

        if (restaurant is null)
        {
            restaurant = new Restaurant
            {
                RestaurantId = Guid.NewGuid(),
                OwnerUserId = user.UserId,
                Name = restaurantName,
                Type = restaurantType,
                Address = address,
                Phone = phone,
                WorkingHours = workingHours,
                Latitude = latitude,
                Longitude = longitude,
                OrderNotifications = true,
                IsOpen = true,
                CreatedAtUtc = DateTime.UtcNow,
            };
            db.Restaurants.Add(restaurant);
            await db.SaveChangesAsync(ct);
        }
        else
        {
            restaurant.Name = restaurantName;
            restaurant.Type = restaurantType;
            restaurant.Address = address;
            restaurant.Phone = phone;
            restaurant.WorkingHours = workingHours;
            restaurant.Latitude = latitude;
            restaurant.Longitude = longitude;
            await db.SaveChangesAsync(ct);
        }

        return (user.UserId, restaurant.RestaurantId);
    }

    private static async Task AddMenuItemsIfMissingAsync(
        VaveylaDbContext db,
        Guid restaurantId,
        (string Name, string Category, int Price, string ImagePath, bool IsFeatured)[] items,
        CancellationToken ct)
    {
        var existing = await db.MenuItems
            .Where(m => m.RestaurantId == restaurantId)
            .Select(m => new { m.Name, m.Price })
            .ToListAsync(ct);
        var existingKeys = existing.Select(x => (x.Name, x.Price)).ToHashSet();

        foreach (var (name, category, price, imagePath, isFeatured) in items)
        {
            if (existingKeys.Contains((name, price)))
                continue;

            db.MenuItems.Add(new MenuItem
            {
                MenuItemId = Guid.NewGuid(),
                RestaurantId = restaurantId,
                CategoryName = category,
                Name = name,
                Price = price,
                ImagePath = imagePath,
                IsAvailable = true,
                IsFeatured = isFeatured,
                CreatedAtUtc = DateTime.UtcNow,
            });
            existingKeys.Add((name, price));
        }

        await db.SaveChangesAsync(ct);
    }
}
