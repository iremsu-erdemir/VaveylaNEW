using Vaveyla.Api.Models;

namespace Vaveyla.Api.Data;

public interface IFeedbackRepository
{
    Task<Feedback?> GetFeedbackByIdAsync(int feedbackId, CancellationToken cancellationToken);

    Task<List<Feedback>> GetAllFeedbacksOrderedAsync(CancellationToken cancellationToken);

    Task AddFeedbackAsync(Feedback feedback, CancellationToken cancellationToken);

    Task AddPenaltyAsync(Penalty penalty, CancellationToken cancellationToken);

    Task AddAdminLogAsync(AdminActionLog log, CancellationToken cancellationToken);

    Task SaveChangesAsync(CancellationToken cancellationToken);
}
