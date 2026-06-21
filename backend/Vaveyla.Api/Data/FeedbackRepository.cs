using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Data;

public sealed class FeedbackRepository : IFeedbackRepository
{
    private readonly VaveylaDbContext _db;

    public FeedbackRepository(VaveylaDbContext db)
    {
        _db = db;
    }

    public Task<Feedback?> GetFeedbackByIdAsync(int feedbackId, CancellationToken cancellationToken) =>
        _db.Feedbacks.FirstOrDefaultAsync(f => f.Id == feedbackId, cancellationToken);

    public Task<List<Feedback>> GetAllFeedbacksOrderedAsync(CancellationToken cancellationToken) =>
        _db.Feedbacks
            .AsNoTracking()
            .OrderByDescending(f => f.CreatedAtUtc)
            .ToListAsync(cancellationToken);

    public async Task AddFeedbackAsync(Feedback feedback, CancellationToken cancellationToken)
    {
        await _db.Feedbacks.AddAsync(feedback, cancellationToken);
    }

    public async Task AddPenaltyAsync(Penalty penalty, CancellationToken cancellationToken)
    {
        await _db.Penalties.AddAsync(penalty, cancellationToken);
    }

    public async Task AddAdminLogAsync(AdminActionLog log, CancellationToken cancellationToken)
    {
        await _db.AdminActionLogs.AddAsync(log, cancellationToken);
    }

    public Task SaveChangesAsync(CancellationToken cancellationToken) =>
        _db.SaveChangesAsync(cancellationToken);
}
