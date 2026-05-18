using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Data;

public sealed class CampaignRepository : ICampaignRepository
{
    private readonly VaveylaDbContext _db;

    public CampaignRepository(VaveylaDbContext db)
    {
        _db = db;
    }

    public async Task<Campaign> CreateAsync(Campaign campaign, CancellationToken ct = default)
    {
        _db.Campaigns.Add(campaign);
        await _db.SaveChangesAsync(ct);
        return campaign;
    }

    public async Task<Campaign?> GetByIdAsync(Guid campaignId, CancellationToken ct = default)
    {
        return await _db.Campaigns.FirstOrDefaultAsync(c => c.CampaignId == campaignId, ct);
    }

    public async Task<List<Campaign>> GetAllAsync(CancellationToken ct = default)
    {
        return await _db.Campaigns.OrderByDescending(c => c.CreatedAtUtc).ToListAsync(ct);
    }

    public async Task<List<Campaign>> GetByRestaurantAsync(Guid restaurantId, CancellationToken ct = default)
    {
        return await _db.Campaigns
            .Where(c => c.RestaurantId == restaurantId)
            .OrderByDescending(c => c.CreatedAtUtc)
            .ToListAsync(ct);
    }

    public async Task UpdateAsync(Campaign campaign, CancellationToken ct = default)
    {
        _db.Campaigns.Update(campaign);
        await _db.SaveChangesAsync(ct);
    }

    public async Task DeleteAsync(Campaign campaign, CancellationToken ct = default)
    {
        _db.Campaigns.Remove(campaign);
        await _db.SaveChangesAsync(ct);
    }
}
