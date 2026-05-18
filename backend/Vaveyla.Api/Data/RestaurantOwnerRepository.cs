using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Data;

public interface IRestaurantOwnerRepository
{
    Task<Restaurant> GetOrCreateRestaurantAsync(Guid ownerUserId, CancellationToken cancellationToken);
    Task<Restaurant?> GetRestaurantAsync(Guid ownerUserId, CancellationToken cancellationToken);
    Task<Restaurant?> GetRestaurantByIdAsync(Guid restaurantId, CancellationToken cancellationToken);
    Task UpdateRestaurantAsync(Restaurant restaurant, CancellationToken cancellationToken);
    Task<List<MenuItem>> GetMenuItemsAsync(Guid restaurantId, CancellationToken cancellationToken);
    Task<MenuItem?> GetMenuItemAsync(Guid restaurantId, Guid menuItemId, CancellationToken cancellationToken);
    Task<MenuItem> AddMenuItemAsync(MenuItem item, CancellationToken cancellationToken);
    Task UpdateMenuItemAsync(MenuItem item, CancellationToken cancellationToken);
    Task<bool> DeleteMenuItemAsync(Guid restaurantId, Guid menuItemId, CancellationToken cancellationToken);
    Task<List<RestaurantOrder>> GetOrdersAsync(Guid restaurantId, CancellationToken cancellationToken);
    Task<RestaurantOrder> AddOrderAsync(RestaurantOrder order, CancellationToken cancellationToken);
    Task<RestaurantOrder?> GetOrderAsync(Guid restaurantId, Guid orderId, CancellationToken cancellationToken);
    Task UpdateOrderAsync(RestaurantOrder order, CancellationToken cancellationToken);
    Task<List<RestaurantReview>> GetReviewsAsync(Guid restaurantId, CancellationToken cancellationToken);
    Task UpdateReviewReplyAsync(Guid restaurantId, Guid reviewId, string reply, CancellationToken cancellationToken);
    Task<List<(MenuItem Item, string RestaurantName, string? RestaurantPhotoPath, string RestaurantType, string? RestaurantAddress, string RestaurantPhone, double? RestaurantLat, double? RestaurantLng, int? EstimatedDeliveryMinutes, bool RestaurantIsOpen)>> GetAllProductsAsync(CancellationToken cancellationToken);
}

public sealed class RestaurantOwnerRepository : IRestaurantOwnerRepository
{
    private readonly VaveylaDbContext _dbContext;
    private readonly string _connectionString;

    public RestaurantOwnerRepository(IConfiguration configuration, VaveylaDbContext dbContext)
    {
        _connectionString = configuration.GetConnectionString("Default")
            ?? throw new InvalidOperationException("Connection string 'Default' is missing.");
        _dbContext = dbContext;
    }

    public async Task<Restaurant> GetOrCreateRestaurantAsync(
        Guid ownerUserId,
        CancellationToken cancellationToken)
    {
        var existing = await GetRestaurantAsync(ownerUserId, cancellationToken);
        if (existing is not null)
        {
            return existing;
        }

        var restaurant = new Restaurant
        {
            RestaurantId = Guid.NewGuid(),
            OwnerUserId = ownerUserId,
            Name = "Yeni Pastane",
            Type = "Pastane",
            Address = "Adres bilgisi girilmedi",
            Phone = "+90",
            WorkingHours = "09:00 - 22:00",
            OrderNotifications = true,
            CreatedAtUtc = DateTime.UtcNow,
        };

        _dbContext.Restaurants.Add(restaurant);
        try
        {
            await _dbContext.SaveChangesAsync(cancellationToken);
            return restaurant;
        }
        catch (DbUpdateException ex) when (IsUniqueViolation(ex))
        {
            // Another concurrent request created the restaurant first.
            var created = await GetRestaurantAsync(ownerUserId, cancellationToken);
            if (created is not null)
            {
                return created;
            }

            throw;
        }
    }

    public async Task<Restaurant?> GetRestaurantAsync(
        Guid ownerUserId,
        CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT RestaurantId, OwnerUserId, Name, Type, Address, Phone, WorkingHours,
                   Latitude, Longitude, OrderNotifications, PhotoPath, IsOpen,
                   CommissionRate, RestaurantDiscountPercent, RestaurantDiscountApproved,
                   RestaurantDiscountIsActive, IsEnabled, CreatedAtUtc
            FROM dbo.Restaurants
            WHERE OwnerUserId = @OwnerUserId
            """;

        await using var connection = new SqlConnection(_connectionString);
        return await connection.QuerySingleOrDefaultAsync<Restaurant>(
            new CommandDefinition(sql, new { OwnerUserId = ownerUserId }, cancellationToken: cancellationToken));
    }

    public async Task<Restaurant?> GetRestaurantByIdAsync(
        Guid restaurantId,
        CancellationToken cancellationToken)
    {
        return await _dbContext.Restaurants
            .FirstOrDefaultAsync(r => r.RestaurantId == restaurantId, cancellationToken);
    }

    public async Task UpdateRestaurantAsync(Restaurant restaurant, CancellationToken cancellationToken)
    {
        var existing = await _dbContext.Restaurants
            .FirstOrDefaultAsync(r => r.RestaurantId == restaurant.RestaurantId, cancellationToken);
        if (existing is null)
        {
            return;
        }
        existing.Name = restaurant.Name;
        existing.Type = restaurant.Type;
        existing.Address = restaurant.Address;
        existing.Phone = restaurant.Phone;
        existing.WorkingHours = restaurant.WorkingHours;
        existing.Latitude = restaurant.Latitude;
        existing.Longitude = restaurant.Longitude;
        existing.OrderNotifications = restaurant.OrderNotifications;
        existing.PhotoPath = restaurant.PhotoPath;
        existing.IsOpen = restaurant.IsOpen;
        existing.CommissionRate = restaurant.CommissionRate;
        existing.RestaurantDiscountPercent = restaurant.RestaurantDiscountPercent;
        existing.RestaurantDiscountApproved = restaurant.RestaurantDiscountApproved;
        existing.RestaurantDiscountIsActive = restaurant.RestaurantDiscountIsActive;
        existing.IsEnabled = restaurant.IsEnabled;
        await _dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task<List<MenuItem>> GetMenuItemsAsync(Guid restaurantId, CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT MenuItemId, RestaurantId, CategoryName, Name, Price, SaleUnit, ImagePath, IsAvailable, IsFeatured, CreatedAtUtc
            FROM dbo.MenuItems
            WHERE RestaurantId = @RestaurantId
            ORDER BY CreatedAtUtc DESC
            """;

        await using var connection = new SqlConnection(_connectionString);
        var items = await connection.QueryAsync<MenuItem>(
            new CommandDefinition(sql, new { RestaurantId = restaurantId }, cancellationToken: cancellationToken));
        return items.ToList();
    }

    public async Task<MenuItem?> GetMenuItemAsync(
        Guid restaurantId,
        Guid menuItemId,
        CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT MenuItemId, RestaurantId, CategoryName, Name, Price, SaleUnit, ImagePath, IsAvailable, IsFeatured, CreatedAtUtc
            FROM dbo.MenuItems
            WHERE RestaurantId = @RestaurantId AND MenuItemId = @MenuItemId
            """;

        await using var connection = new SqlConnection(_connectionString);
        return await connection.QuerySingleOrDefaultAsync<MenuItem>(
            new CommandDefinition(sql, new { RestaurantId = restaurantId, MenuItemId = menuItemId },
                cancellationToken: cancellationToken));
    }

    public async Task<MenuItem> AddMenuItemAsync(MenuItem item, CancellationToken cancellationToken)
    {
        _dbContext.MenuItems.Add(item);
        await _dbContext.SaveChangesAsync(cancellationToken);
        return item;
    }

    public async Task UpdateMenuItemAsync(MenuItem item, CancellationToken cancellationToken)
    {
        _dbContext.MenuItems.Update(item);
        await _dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task<bool> DeleteMenuItemAsync(
        Guid restaurantId,
        Guid menuItemId,
        CancellationToken cancellationToken)
    {
        var existing = await _dbContext.MenuItems
            .FirstOrDefaultAsync(x => x.RestaurantId == restaurantId && x.MenuItemId == menuItemId,
                cancellationToken);
        if (existing is null)
        {
            return false;
        }

        _dbContext.MenuItems.Remove(existing);
        await _dbContext.SaveChangesAsync(cancellationToken);
        return true;
    }

    public async Task<List<RestaurantOrder>> GetOrdersAsync(Guid restaurantId, CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT OrderId, RestaurantId, Items, ImagePath, PreparationMinutes, Total, Status, CreatedAtUtc
            FROM dbo.RestaurantOrders
            WHERE RestaurantId = @RestaurantId
            ORDER BY CreatedAtUtc DESC
            """;

        await using var connection = new SqlConnection(_connectionString);
        var orders = await connection.QueryAsync<RestaurantOrder>(
            new CommandDefinition(sql, new { RestaurantId = restaurantId }, cancellationToken: cancellationToken));
        return orders.ToList();
    }

    public async Task<RestaurantOrder> AddOrderAsync(
        RestaurantOrder order,
        CancellationToken cancellationToken)
    {
        _dbContext.RestaurantOrders.Add(order);
        await _dbContext.SaveChangesAsync(cancellationToken);
        return order;
    }

    public async Task<RestaurantOrder?> GetOrderAsync(
        Guid restaurantId,
        Guid orderId,
        CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT OrderId, RestaurantId, Items, ImagePath, PreparationMinutes, Total, Status, CreatedAtUtc
            FROM dbo.RestaurantOrders
            WHERE RestaurantId = @RestaurantId AND OrderId = @OrderId
            """;

        await using var connection = new SqlConnection(_connectionString);
        return await connection.QuerySingleOrDefaultAsync<RestaurantOrder>(
            new CommandDefinition(sql, new { RestaurantId = restaurantId, OrderId = orderId },
                cancellationToken: cancellationToken));
    }

    public async Task UpdateOrderAsync(RestaurantOrder order, CancellationToken cancellationToken)
    {
        _dbContext.RestaurantOrders.Update(order);
        await _dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task<List<RestaurantReview>> GetReviewsAsync(
        Guid restaurantId,
        CancellationToken cancellationToken)
    {
        const string sql = """
            IF COL_LENGTH('dbo.RestaurantReviews', 'TargetType') IS NOT NULL
               AND COL_LENGTH('dbo.RestaurantReviews', 'TargetId') IS NOT NULL
            BEGIN
                SELECT ReviewId, RestaurantId, CustomerUserId, TargetType, TargetId, ProductId, CustomerName, Rating, Comment, OwnerReply, CreatedAtUtc
                FROM dbo.RestaurantReviews
                WHERE RestaurantId = @RestaurantId
                ORDER BY CreatedAtUtc DESC
            END
            ELSE
            BEGIN
                SELECT
                    ReviewId,
                    RestaurantId,
                    CustomerUserId,
                    CAST('restaurant' AS nvarchar(30)) AS TargetType,
                    RestaurantId AS TargetId,
                    ProductId,
                    CustomerName,
                    Rating,
                    Comment,
                    OwnerReply,
                    CreatedAtUtc
                FROM dbo.RestaurantReviews
                WHERE RestaurantId = @RestaurantId
                ORDER BY CreatedAtUtc DESC
            END
            """;

        await using var connection = new SqlConnection(_connectionString);
        var reviews = await connection.QueryAsync<RestaurantReview>(
            new CommandDefinition(sql, new { RestaurantId = restaurantId }, cancellationToken: cancellationToken));
        return reviews.ToList();
    }

    private static bool IsUniqueViolation(DbUpdateException ex)
    {
        if (ex.InnerException is not SqlException sqlException)
        {
            return false;
        }

        // 2601: duplicate key row, 2627: violation of UNIQUE KEY constraint
        return sqlException.Number == 2601 || sqlException.Number == 2627;
    }

    public async Task UpdateReviewReplyAsync(
        Guid restaurantId,
        Guid reviewId,
        string reply,
        CancellationToken cancellationToken)
    {
        const string sql = """
            UPDATE dbo.RestaurantReviews
            SET OwnerReply = @OwnerReply
            WHERE RestaurantId = @RestaurantId AND ReviewId = @ReviewId
            """;

        await using var connection = new SqlConnection(_connectionString);
        await connection.ExecuteAsync(
            new CommandDefinition(
                sql,
                new { RestaurantId = restaurantId, ReviewId = reviewId, OwnerReply = reply },
                cancellationToken: cancellationToken));
    }

    public async Task<List<(MenuItem Item, string RestaurantName, string? RestaurantPhotoPath, string RestaurantType, string? RestaurantAddress, string RestaurantPhone, double? RestaurantLat, double? RestaurantLng, int? EstimatedDeliveryMinutes, bool RestaurantIsOpen)>> GetAllProductsAsync(
        CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT m.MenuItemId, m.RestaurantId, m.CategoryName, m.Name, m.Price, m.SaleUnit, m.ImagePath,
                   m.IsAvailable, m.IsFeatured, m.CreatedAtUtc, r.Name AS RestaurantName, r.Type AS RestaurantType,
                   r.PhotoPath AS RestaurantPhotoPath, r.Address AS RestaurantAddress, r.Phone AS RestaurantPhone,
                   r.Latitude AS RestaurantLat, r.Longitude AS RestaurantLng,
                   (
                       SELECT TOP 1 ro.PreparationMinutes
                       FROM dbo.RestaurantOrders ro
                       WHERE ro.RestaurantId = r.RestaurantId
                         AND ro.PreparationMinutes IS NOT NULL
                         AND ro.PreparationMinutes > 0
                       ORDER BY ro.CreatedAtUtc DESC
                   ) AS EstimatedDeliveryMinutes,
                   r.IsOpen AS RestaurantIsOpen
            FROM dbo.MenuItems m
            INNER JOIN dbo.Restaurants r ON m.RestaurantId = r.RestaurantId
            INNER JOIN dbo.Users o ON o.UserId = r.OwnerUserId
                AND o.IsPermanentlyBanned = 0
                AND (o.SuspendedUntilUtc IS NULL OR o.SuspendedUntilUtc <= SYSUTCDATETIME())
            WHERE m.IsAvailable = 1
            ORDER BY m.CreatedAtUtc DESC
            """;

        await using var connection = new SqlConnection(_connectionString);
        var rows = await connection.QueryAsync<dynamic>(
            new CommandDefinition(sql, cancellationToken: cancellationToken));
        var result = new List<(MenuItem, string, string?, string, string?, string, double?, double?, int?, bool)>();
        foreach (var row in rows)
        {
            var dict = (IDictionary<string, object>)row;
            var item = new MenuItem
            {
                MenuItemId = (Guid)dict["MenuItemId"],
                RestaurantId = (Guid)dict["RestaurantId"],
                CategoryName = dict["CategoryName"]?.ToString(),
                Name = dict["Name"]?.ToString() ?? "",
                Price = Convert.ToInt32(dict["Price"]),
                SaleUnit = dict["SaleUnit"] is null || dict["SaleUnit"] is DBNull
                    ? ProductSaleUnit.PerKilogram
                    : Convert.ToByte(dict["SaleUnit"]),
                ImagePath = dict["ImagePath"]?.ToString() ?? "",
                IsAvailable = true,
                IsFeatured = dict["IsFeatured"] != null && Convert.ToBoolean(dict["IsFeatured"]),
                CreatedAtUtc = dict["CreatedAtUtc"] != null ? (DateTime)dict["CreatedAtUtc"] : DateTime.UtcNow,
            };
            var restaurantName = dict["RestaurantName"]?.ToString() ?? "";
            var restaurantPhotoPath = dict["RestaurantPhotoPath"]?.ToString();
            var restaurantType = dict["RestaurantType"]?.ToString() ?? "";
            var restaurantAddress = dict["RestaurantAddress"]?.ToString();
            var restaurantPhone = dict["RestaurantPhone"]?.ToString() ?? "";
            double? restaurantLat = dict["RestaurantLat"] == null || dict["RestaurantLat"] is DBNull
                ? null
                : Convert.ToDouble(dict["RestaurantLat"]);
            double? restaurantLng = dict["RestaurantLng"] == null || dict["RestaurantLng"] is DBNull
                ? null
                : Convert.ToDouble(dict["RestaurantLng"]);
            int? estimatedDeliveryMinutes = dict["EstimatedDeliveryMinutes"] == null || dict["EstimatedDeliveryMinutes"] is DBNull
                ? null
                : Convert.ToInt32(dict["EstimatedDeliveryMinutes"]);
            var restaurantIsOpen = dict["RestaurantIsOpen"] != null
                && dict["RestaurantIsOpen"] is not DBNull
                && Convert.ToBoolean(dict["RestaurantIsOpen"]);
            result.Add((item, restaurantName, restaurantPhotoPath, restaurantType, restaurantAddress, restaurantPhone, restaurantLat, restaurantLng, estimatedDeliveryMinutes, restaurantIsOpen));
        }
        return result;
    }
}
