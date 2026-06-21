using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Data;
using Vaveyla.Api.Exceptions;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Services;

public sealed class UserSuspensionService : IUserSuspensionService
{
    private readonly VaveylaDbContext _db;
    private readonly ILogger<UserSuspensionService> _logger;

    public UserSuspensionService(VaveylaDbContext db, ILogger<UserSuspensionService> logger)
    {
        _db = db;
        _logger = logger;
    }

    public bool IsOperationallyBlocked(User? user)
    {
        if (user is null)
        {
            return false;
        }

        if (user.IsPermanentlyBanned)
        {
            return true;
        }

        return user.IsSuspended;
    }

    public void ThrowIfOperationallyBlocked(User? user, string message)
    {
        if (IsOperationallyBlocked(user))
        {
            throw new ForbiddenOperationException(message);
        }
    }

    public void ExtendSuspensionUntil(User user, DateTime candidateEndUtc)
    {
        user.SuspendedUntilUtc = user.SuspendedUntilUtc is { } ex && ex > candidateEndUtc
            ? ex
            : candidateEndUtc;
    }

    public async Task<int> ClearExpiredSuspensionsAsync(CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var affected = await _db.Users
            .Where(u => u.SuspendedUntilUtc != null && u.SuspendedUntilUtc <= now)
            .ToListAsync(cancellationToken);

        if (affected.Count == 0)
        {
            return 0;
        }

        foreach (var u in affected)
        {
            u.SuspendedUntilUtc = null;
        }

        await _db.SaveChangesAsync(cancellationToken);
        _logger.LogInformation(
            "Askı süresi dolan {Count} kullanıcı için SuspendedUntilUtc temizlendi.",
            affected.Count);
        return affected.Count;
    }
}
