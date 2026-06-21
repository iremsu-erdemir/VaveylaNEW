using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Data;

public interface ICustomerReviewsRepository
{
    Task<(List<RestaurantReview> Items, int TotalCount)> GetReviewsAsync(
        string targetType,
        Guid targetId,
        Guid? restaurantId,
        int page,
        int pageSize,
        CancellationToken cancellationToken);
    Task<RestaurantReview?> GetReviewAsync(Guid reviewId, CancellationToken cancellationToken);
    Task<RestaurantReview> AddReviewAsync(RestaurantReview review, CancellationToken cancellationToken);
    Task<RestaurantReview> UpdateReviewAsync(RestaurantReview review, CancellationToken cancellationToken);
    Task<bool> DeleteReviewAsync(RestaurantReview review, CancellationToken cancellationToken);
    Task<bool> HasReportedAsync(Guid reviewId, Guid reporterUserId, CancellationToken cancellationToken);
    Task<ReviewReport> AddReportAsync(ReviewReport report, CancellationToken cancellationToken);
}

public sealed class CustomerReviewsRepository : ICustomerReviewsRepository
{
    private readonly VaveylaDbContext _dbContext;

    public CustomerReviewsRepository(VaveylaDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task<(List<RestaurantReview> Items, int TotalCount)> GetReviewsAsync(
        string targetType,
        Guid targetId,
        Guid? restaurantId,
        int page,
        int pageSize,
        CancellationToken cancellationToken)
    {
        var query = _dbContext.RestaurantReviews.AsQueryable();
        if (targetType == "menu")
        {
            query = query.Where(x =>
                (x.TargetType == "menu" && x.TargetId == targetId) ||
                (x.TargetType == "order" && x.ProductId.HasValue && x.ProductId.Value == targetId));
        }
        else
        {
            query = query.Where(x => x.TargetType == targetType && x.TargetId == targetId);
        }
        if (restaurantId.HasValue && restaurantId.Value != Guid.Empty)
        {
            query = query.Where(x => x.RestaurantId == restaurantId.Value);
        }

        var totalCount = await query.CountAsync(cancellationToken);
        var items = await query
            .OrderByDescending(x => x.CreatedAtUtc)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);
        return (items, totalCount);
    }

    public async Task<RestaurantReview?> GetReviewAsync(Guid reviewId, CancellationToken cancellationToken)
    {
        return await _dbContext.RestaurantReviews
            .FirstOrDefaultAsync(x => x.ReviewId == reviewId, cancellationToken);
    }

    public async Task<RestaurantReview> AddReviewAsync(
        RestaurantReview review,
        CancellationToken cancellationToken)
    {
        _dbContext.RestaurantReviews.Add(review);
        await _dbContext.SaveChangesAsync(cancellationToken);
        return review;
    }

    public async Task<RestaurantReview> UpdateReviewAsync(
        RestaurantReview review,
        CancellationToken cancellationToken)
    {
        _dbContext.RestaurantReviews.Update(review);
        await _dbContext.SaveChangesAsync(cancellationToken);
        return review;
    }

    public async Task<bool> DeleteReviewAsync(
        RestaurantReview review,
        CancellationToken cancellationToken)
    {
        _dbContext.RestaurantReviews.Remove(review);
        await _dbContext.SaveChangesAsync(cancellationToken);
        return true;
    }

    public async Task<bool> HasReportedAsync(
        Guid reviewId,
        Guid reporterUserId,
        CancellationToken cancellationToken)
    {
        return await _dbContext.ReviewReports.AnyAsync(
            x => x.ReviewId == reviewId && x.ReporterUserId == reporterUserId,
            cancellationToken);
    }

    public async Task<ReviewReport> AddReportAsync(
        ReviewReport report,
        CancellationToken cancellationToken)
    {
        _dbContext.ReviewReports.Add(report);
        await _dbContext.SaveChangesAsync(cancellationToken);
        return report;
    }
}
