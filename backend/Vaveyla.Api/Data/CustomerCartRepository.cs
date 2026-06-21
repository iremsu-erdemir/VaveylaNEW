using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Data;

public interface ICustomerCartRepository
{
    Task<List<CustomerCartItem>> GetCartAsync(Guid customerUserId, CancellationToken cancellationToken);
    Task<CustomerCartItem?> GetCartItemAsync(Guid customerUserId, Guid cartItemId, CancellationToken cancellationToken);
    Task<CustomerCartItem> AddOrUpdateAsync(
        Guid customerUserId,
        Guid productId,
        decimal weightKg,
        int quantity,
        CancellationToken cancellationToken);
    Task<CustomerCartItem?> UpdateQuantityAsync(
        Guid customerUserId,
        Guid cartItemId,
        int quantity,
        CancellationToken cancellationToken);
    Task<bool> RemoveItemAsync(Guid customerUserId, Guid cartItemId, CancellationToken cancellationToken);
    Task ClearCartAsync(Guid customerUserId, CancellationToken cancellationToken);
}

public sealed class CustomerCartRepository : ICustomerCartRepository
{
    private readonly VaveylaDbContext _dbContext;

    public CustomerCartRepository(VaveylaDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task<List<CustomerCartItem>> GetCartAsync(
        Guid customerUserId,
        CancellationToken cancellationToken)
    {
        return await _dbContext.CustomerCartItems
            .Where(x => x.CustomerUserId == customerUserId)
            .OrderByDescending(x => x.UpdatedAtUtc)
            .ToListAsync(cancellationToken);
    }

    public async Task<CustomerCartItem?> GetCartItemAsync(
        Guid customerUserId,
        Guid cartItemId,
        CancellationToken cancellationToken)
    {
        return await _dbContext.CustomerCartItems
            .FirstOrDefaultAsync(
                x => x.CustomerUserId == customerUserId && x.CartItemId == cartItemId,
                cancellationToken);
    }

    public async Task<CustomerCartItem> AddOrUpdateAsync(
        Guid customerUserId,
        Guid productId,
        decimal weightKg,
        int quantity,
        CancellationToken cancellationToken)
    {
        var product = await _dbContext.MenuItems
            .FirstOrDefaultAsync(x => x.MenuItemId == productId, cancellationToken);
        if (product is null)
        {
            throw new InvalidOperationException("Product not found.");
        }

        var hasDifferentRestaurantItems = await _dbContext.CustomerCartItems
            .AnyAsync(
                x => x.CustomerUserId == customerUserId &&
                     x.RestaurantId != product.RestaurantId,
                cancellationToken);
        if (hasDifferentRestaurantItems)
        {
            throw new InvalidOperationException(
                "Aynı anda farklı pastanelerden ürün ekleyemezsiniz. Lütfen önce sepetinizi temizleyin.");
        }

        var now = DateTime.UtcNow;
        var existing = await _dbContext.CustomerCartItems
            .FirstOrDefaultAsync(
                x => x.CustomerUserId == customerUserId &&
                     x.ProductId == productId &&
                     x.WeightKg == weightKg,
                cancellationToken);

        if (existing is not null)
        {
            existing.Quantity += quantity;
            existing.UnitPrice = product.Price;
            existing.ProductName = product.Name;
            existing.ImagePath = product.ImagePath;
            existing.SaleUnit = product.SaleUnit;
            existing.UpdatedAtUtc = now;
            await _dbContext.SaveChangesAsync(cancellationToken);
            return existing;
        }

        var item = new CustomerCartItem
        {
            CartItemId = Guid.NewGuid(),
            CustomerUserId = customerUserId,
            ProductId = product.MenuItemId,
            RestaurantId = product.RestaurantId,
            ProductName = product.Name,
            ImagePath = product.ImagePath,
            UnitPrice = product.Price,
            WeightKg = weightKg,
            Quantity = quantity,
            SaleUnit = product.SaleUnit,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        };
        _dbContext.CustomerCartItems.Add(item);
        await _dbContext.SaveChangesAsync(cancellationToken);
        return item;
    }

    public async Task<CustomerCartItem?> UpdateQuantityAsync(
        Guid customerUserId,
        Guid cartItemId,
        int quantity,
        CancellationToken cancellationToken)
    {
        var item = await GetCartItemAsync(customerUserId, cartItemId, cancellationToken);
        if (item is null)
        {
            return null;
        }

        item.Quantity = quantity;
        item.UpdatedAtUtc = DateTime.UtcNow;
        await _dbContext.SaveChangesAsync(cancellationToken);
        return item;
    }

    public async Task<bool> RemoveItemAsync(
        Guid customerUserId,
        Guid cartItemId,
        CancellationToken cancellationToken)
    {
        var item = await GetCartItemAsync(customerUserId, cartItemId, cancellationToken);
        if (item is null)
        {
            return false;
        }

        _dbContext.CustomerCartItems.Remove(item);
        await _dbContext.SaveChangesAsync(cancellationToken);
        return true;
    }

    public async Task ClearCartAsync(Guid customerUserId, CancellationToken cancellationToken)
    {
        var items = await _dbContext.CustomerCartItems
            .Where(x => x.CustomerUserId == customerUserId)
            .ToListAsync(cancellationToken);
        if (items.Count == 0)
        {
            return;
        }

        _dbContext.CustomerCartItems.RemoveRange(items);
        await _dbContext.SaveChangesAsync(cancellationToken);
    }
}
