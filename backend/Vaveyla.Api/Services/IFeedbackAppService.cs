using Vaveyla.Api.DTOs;

namespace Vaveyla.Api.Services;

public interface IFeedbackAppService
{
    Task<int> CreateCustomerFeedbackAsync(
        Guid customerUserId,
        CreateCustomerFeedbackRequest request,
        CancellationToken cancellationToken);

    Task<List<FeedbackAdminListItemDto>> GetAdminFeedbacksAsync(CancellationToken cancellationToken);

    Task ApplyAdminActionAsync(
        int feedbackId,
        Guid adminUserId,
        AdminFeedbackActionRequest request,
        CancellationToken cancellationToken);
}
