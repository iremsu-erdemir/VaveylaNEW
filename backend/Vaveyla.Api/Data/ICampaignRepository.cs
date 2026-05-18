using Vaveyla.Api.Models;

namespace Vaveyla.Api.Data;

public interface ICampaignRepository
{
    Task<Campaign> CreateAsync(Campaign campaign, CancellationToken ct = default);
    Task<Campaign?> GetByIdAsync(Guid campaignId, CancellationToken ct = default);
    Task<List<Campaign>> GetAllAsync(CancellationToken ct = default);
    Task<List<Campaign>> GetByRestaurantAsync(Guid restaurantId, CancellationToken ct = default);
    Task UpdateAsync(Campaign campaign, CancellationToken ct = default);
    Task DeleteAsync(Campaign campaign, CancellationToken ct = default);
}
