using Vaveyla.Api.Models;

namespace Vaveyla.Api.Services;

public interface ICartCalculationService
{
    Task<CalculateCartResponse> CalculateCartAsync(CalculateCartRequest request, CancellationToken cancellationToken = default);
}
