using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Data;
using Vaveyla.Api.Models;
using Vaveyla.Api.Services;

namespace Vaveyla.Api.Controllers;

[ApiController]
[Route("api/customer/reviews")]
public sealed class CustomerReviewsController : ControllerBase
{
    private readonly ICustomerReviewsRepository _repository;
    private readonly VaveylaDbContext _dbContext;

    public CustomerReviewsController(
        ICustomerReviewsRepository repository,
        VaveylaDbContext dbContext)
    {
        _repository = repository;
        _dbContext = dbContext;
    }

    [HttpGet]
    public async Task<ActionResult<List<object>>> GetReviews(
        [FromQuery] string targetType,
        [FromQuery] Guid targetId,
        [FromQuery] Guid? restaurantId,
        CancellationToken cancellationToken,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 10)
    {
        if (!TryNormalizeTargetType(targetType, out var normalizedType))
        {
            return BadRequest(new { message = "Invalid target type." });
        }
        if (targetId == Guid.Empty)
        {
            return BadRequest(new { message = "Target id is required." });
        }

        if (page < 1) page = 1;
        if (pageSize < 1) pageSize = 10;
        if (pageSize > 50) pageSize = 50;

        var (items, totalCount) = await _repository.GetReviewsAsync(
            normalizedType,
            targetId,
            restaurantId,
            page,
            pageSize,
            cancellationToken);
        var result = items.Select(MapReview).ToList();
        return Ok(new
        {
            items = result,
            totalCount,
            page,
            pageSize,
        });
    }

    [HttpPost]
    public async Task<ActionResult<object>> CreateReview(
        [FromQuery] Guid customerUserId,
        [FromBody] CreateCustomerReviewRequest request,
        CancellationToken cancellationToken)
    {
        if (customerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Customer user id is required." });
        }
        if (request.RestaurantId == Guid.Empty)
        {
            return BadRequest(new { message = "Restaurant id is required." });
        }
        if (!TryNormalizeTargetType(request.TargetType, out var normalizedType))
        {
            return BadRequest(new { message = "Invalid target type." });
        }
        if (request.TargetId == Guid.Empty)
        {
            return BadRequest(new { message = "Target id is required." });
        }
        if (request.Rating is < 1 or > 5)
        {
            return BadRequest(new { message = "Rating must be between 1 and 5." });
        }
        if (string.IsNullOrWhiteSpace(request.Comment))
        {
            return BadRequest(new { message = "Comment is required." });
        }

        try
        {
            ProfanityValidator.EnsureClean(request.Comment, "Yorum");
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }

        var resolvedRestaurantId = await ResolveRestaurantIdAsync(
            normalizedType,
            request.TargetId,
            request.RestaurantId,
            cancellationToken);
        if (!resolvedRestaurantId.HasValue || resolvedRestaurantId.Value == Guid.Empty)
        {
            return BadRequest(new { message = "Restaurant could not be resolved for target." });
        }

        var review = new RestaurantReview
        {
            ReviewId = Guid.NewGuid(),
            RestaurantId = resolvedRestaurantId.Value,
            TargetType = normalizedType,
            TargetId = request.TargetId,
            ProductId = await ResolveProductIdAsync(
                normalizedType,
                request.TargetId,
                resolvedRestaurantId.Value,
                cancellationToken),
            CustomerUserId = customerUserId,
            CustomerName = string.IsNullOrWhiteSpace(request.CustomerName) ? "Müşteri" : request.CustomerName.Trim(),
            Rating = request.Rating,
            Comment = request.Comment.Trim(),
            CreatedAtUtc = DateTime.UtcNow,
        };
        await _repository.AddReviewAsync(review, cancellationToken);
        return Ok(MapReview(review));
    }

    [HttpPut("{reviewId:guid}")]
    public async Task<ActionResult<object>> UpdateReview(
        [FromQuery] Guid customerUserId,
        [FromRoute] Guid reviewId,
        [FromBody] UpdateCustomerReviewRequest request,
        CancellationToken cancellationToken)
    {
        if (customerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Customer user id is required." });
        }

        var review = await _repository.GetReviewAsync(reviewId, cancellationToken);
        if (review is null)
        {
            return NotFound(new { message = "Review not found." });
        }
        if (review.CustomerUserId != customerUserId)
        {
            return Forbid();
        }
        if (request.Rating is < 1 or > 5)
        {
            return BadRequest(new { message = "Rating must be between 1 and 5." });
        }
        if (string.IsNullOrWhiteSpace(request.Comment))
        {
            return BadRequest(new { message = "Comment is required." });
        }

        try
        {
            ProfanityValidator.EnsureClean(request.Comment, "Yorum");
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }

        review.Rating = request.Rating;
        review.Comment = request.Comment.Trim();
        review.OwnerReply = null;
        await _repository.UpdateReviewAsync(review, cancellationToken);
        return Ok(MapReview(review));
    }

    [HttpDelete("{reviewId:guid}")]
    public async Task<ActionResult> DeleteReview(
        [FromQuery] Guid customerUserId,
        [FromRoute] Guid reviewId,
        CancellationToken cancellationToken)
    {
        if (customerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Customer user id is required." });
        }

        var review = await _repository.GetReviewAsync(reviewId, cancellationToken);
        if (review is null)
        {
            return NotFound(new { message = "Review not found." });
        }
        if (review.CustomerUserId != customerUserId)
        {
            return Forbid();
        }

        await _repository.DeleteReviewAsync(review, cancellationToken);
        return NoContent();
    }

    [HttpPost("{reviewId:guid}/report")]
    public async Task<ActionResult<object>> ReportReview(
        [FromQuery] Guid customerUserId,
        [FromRoute] Guid reviewId,
        [FromBody] CreateReviewReportRequest request,
        CancellationToken cancellationToken)
    {
        if (customerUserId == Guid.Empty)
        {
            return BadRequest(new { message = "Customer user id is required." });
        }
        var review = await _repository.GetReviewAsync(reviewId, cancellationToken);
        if (review is null)
        {
            return NotFound(new { message = "Review not found." });
        }
        if (review.CustomerUserId == customerUserId)
        {
            return BadRequest(new { message = "You cannot report your own review." });
        }

        var alreadyReported = await _repository.HasReportedAsync(
            reviewId,
            customerUserId,
            cancellationToken);
        if (alreadyReported)
        {
            return Conflict(new { message = "You already reported this review." });
        }

        var report = new ReviewReport
        {
            ReportId = Guid.NewGuid(),
            ReviewId = reviewId,
            ReporterUserId = customerUserId,
            Reason = string.IsNullOrWhiteSpace(request.Reason)
                ? "Uygunsuz içerik"
                : request.Reason.Trim(),
            Status = "pending",
            CreatedAtUtc = DateTime.UtcNow,
        };
        await _repository.AddReportAsync(report, cancellationToken);
        return Ok(new
        {
            id = report.ReportId,
            status = report.Status,
        });
    }

    private static object MapReview(RestaurantReview review)
    {
        return new
        {
            id = review.ReviewId,
            restaurantId = review.RestaurantId,
            targetType = review.TargetType,
            targetId = review.TargetId,
            productId = review.ProductId,
            customerUserId = review.CustomerUserId,
            customerName = review.CustomerName,
            rating = review.Rating,
            comment = review.Comment,
            ownerReply = review.OwnerReply,
            date = review.CreatedAtUtc.ToLocalTime().ToString("dd.MM.yyyy"),
            createdAtUtc = review.CreatedAtUtc,
        };
    }

    private async Task<Guid?> ResolveRestaurantIdAsync(
        string targetType,
        Guid targetId,
        Guid requestedRestaurantId,
        CancellationToken cancellationToken)
    {
        if (targetType == "restaurant")
        {
            return targetId;
        }
        if (targetType == "menu")
        {
            var menu = await _dbContext.MenuItems
                .Where(x => x.MenuItemId == targetId)
                .Select(x => x.RestaurantId)
                .FirstOrDefaultAsync(cancellationToken);
            return menu == Guid.Empty ? requestedRestaurantId : menu;
        }
        if (targetType == "order")
        {
            var order = await _dbContext.CustomerOrders
                .Where(x => x.OrderId == targetId)
                .Select(x => x.RestaurantId)
                .FirstOrDefaultAsync(cancellationToken);
            return order == Guid.Empty ? requestedRestaurantId : order;
        }
        return requestedRestaurantId;
    }

    private async Task<Guid?> ResolveProductIdAsync(
        string targetType,
        Guid targetId,
        Guid restaurantId,
        CancellationToken cancellationToken)
    {
        if (targetType == "menu")
        {
            return targetId;
        }

        if (targetType != "order")
        {
            return null;
        }

        var order = await _dbContext.CustomerOrders
            .Where(x => x.OrderId == targetId)
            .Select(x => new { x.RestaurantId, x.Items })
            .FirstOrDefaultAsync(cancellationToken);
        if (order is null)
        {
            return null;
        }

        var effectiveRestaurantId = order.RestaurantId == Guid.Empty
            ? restaurantId
            : order.RestaurantId;
        if (effectiveRestaurantId == Guid.Empty || string.IsNullOrWhiteSpace(order.Items))
        {
            return null;
        }

        var menuItems = await _dbContext.MenuItems
            .Where(x => x.RestaurantId == effectiveRestaurantId)
            .Select(x => new { x.MenuItemId, x.Name })
            .ToListAsync(cancellationToken);
        if (menuItems.Count == 0)
        {
            return null;
        }

        var normalizedItems = order.Items.ToLowerInvariant();
        foreach (var menuItem in menuItems)
        {
            var name = menuItem.Name?.Trim();
            if (string.IsNullOrWhiteSpace(name))
            {
                continue;
            }

            if (normalizedItems.Contains(name.ToLowerInvariant()))
            {
                return menuItem.MenuItemId;
            }
        }

        return null;
    }

    private static bool TryNormalizeTargetType(string? value, out string normalized)
    {
        normalized = string.Empty;
        var text = value?.Trim().ToLowerInvariant();
        if (string.IsNullOrWhiteSpace(text))
        {
            return false;
        }

        switch (text)
        {
            case "restaurant":
            case "pastane":
                normalized = "restaurant";
                return true;
            case "menu":
                normalized = "menu";
                return true;
            case "order":
            case "siparis":
                normalized = "order";
                return true;
            default:
                return false;
        }
    }
}

public sealed record CreateCustomerReviewRequest(
    Guid RestaurantId,
    string TargetType,
    Guid TargetId,
    byte Rating,
    string Comment,
    string? CustomerName);

public sealed record UpdateCustomerReviewRequest(byte Rating, string Comment);
public sealed record CreateReviewReportRequest(string? Reason);
